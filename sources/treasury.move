module su::treasury {
  // === Imports ===
  use std::type_name::{Self, TypeName};

  use sui::clock::Clock;
  use sui::tx_context::TxContext;
  use sui::object::{Self, UID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, TreasuryCap};
  use sui::versioned::{Self, Versioned};

  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::ema::{Self, EMA};
  use sui::transfer::share_object;
  use su::su_state::{Self, SuState};
  use su::repository::{Self, Repository};

  use suitears::int::{Self, Int};
  use suitears::math64::mul_div_down;

  // === Friends ===

  // === Errors ===

  const EInvalidVersion: u64 = 0;
  const EMultipleIsTooSmall: u64 = 1;
  const ENewCollateralRatioIsTooSmall: u64 = 2;

  // === Constants ===
  
  const STATE_VERSION_V1: u64 = 1;
  /// 10%
  const F_BETA: u64 = 100_000_000;
  // 1 Unit or 100%
  const PRECISION: u64 = 1_000_000_000;

  // === Structs ===

  struct StateV1 has store {
    base_balance: Balance<I_SUI>,
    last_f_nav: u64,
    genesis_price: u64,
    ema: EMA
  }

  struct Treasury has key {
    id: UID,
    inner: Versioned
  }

  // === Admin Functions ===

  // === Public-Friend Functions ===

  public(friend) fun new_genesis_state(
    repository: &mut Repository,
    f_treasury_cap: TreasuryCap<F_SUI>,
    x_treasury_cap: TreasuryCap<X_SUI>,
    c: &Clock,
    genesis_price: u64, 
    ctx: &mut TxContext
  ) {

    repository::add(repository, type_name::get<F_SUI>(), f_treasury_cap);
    repository::add(repository, type_name::get<X_SUI>(), x_treasury_cap);

    let state_v1 = StateV1 {
      base_balance: balance::zero(),
      last_f_nav: PRECISION,
      genesis_price,
      // 30 minutes in seconds
      ema: ema::new(c, 1800)
    };

    let treasury = Treasury {
      id: object::new(ctx),
      inner: versioned::create(STATE_VERSION_V1, state_v1, ctx)
    };

    share_object(treasury);
  }

  public(friend) fun collateral_ratio(self: &mut Treasury, repository: &Repository, base_price: u64): u64 {
    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::collateral_ratio(su_state)
  }

  public(friend) fun su_state(self: &mut Treasury, repository: &Repository, base_price: u64): SuState {
    let state = load_treasury_state_maybe_upgrade(self);

    compute_su_state(state, repository, base_price)
  }

  public(friend) fun max_mintable_f_coin(self: &mut Treasury, repository: &Repository, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::max_mintable_f_coin(su_state, new_collateral_ratio)
  }

  public(friend) fun max_mintable_x_coin(self: &mut Treasury, repository: &Repository, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::max_mintable_x_coin(su_state, new_collateral_ratio)
  } 

  public(friend) fun max_mintable_x_coin_with_incentives(
    self: &mut Treasury, 
    repository: &Repository, 
    base_price: u64, 
    new_collateral_ratio: u64,
    incentive_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::max_mintable_x_coin_with_incentives(su_state, new_collateral_ratio, incentive_ratio)
  }

  public(friend) fun max_redeemable_f_coin(
    self: &mut Treasury, 
    repository: &Repository, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::max_redeemable_f_coin(su_state, new_collateral_ratio)
  }  

  public(friend) fun max_redeemable_x_coin(
    self: &mut Treasury, 
    repository: &Repository, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::max_redeemable_x_coin(su_state, new_collateral_ratio)
  }  

  public(friend) fun max_liquitable(
    self: &mut Treasury, 
    repository: &Repository, 
    base_price: u64, 
    incentive_ratio: u64,
    new_collateral_ratio: u64      
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_maybe_upgrade(self);

    let su_state = compute_su_state(state, repository, base_price);

    su_state::max_liquitable(su_state, incentive_ratio, new_collateral_ratio)
  }  

  public(friend) fun leverage_ratio(self: &mut Treasury, c: &Clock): u64 {
    let state = load_treasury_state_maybe_upgrade(self);

    ema::ema_value(state.ema, c)
  }

  // === Private Functions ===

  fun load_treasury_state_maybe_upgrade(self: &mut Treasury): &mut StateV1 {
    upgrade_treasury_state_to_latest(self);
    versioned::load_value_mut(&mut self.inner)
  }

  fun upgrade_treasury_state_to_latest(self: &Treasury) {
    // * IMPORTANT: When new versions are added, we need to explicitly upgrade here.
    assert!(versioned::version(&self.inner) == STATE_VERSION_V1, EInvalidVersion);
  }

  fun compute_su_state(state: &mut StateV1, repository: &Repository, base_price: u64): SuState {
    let base_supply = balance::value(&state.base_balance);
    let base_nav = base_price;

    let su_state = if (base_supply == 0) {
      su_state::new(base_supply, base_nav, int::zero(), 0, PRECISION, 0, PRECISION)
    } else {
      let f_supply = coin::total_supply(repository::borrow<TypeName, TreasuryCap<F_SUI>>(repository, type_name::get<F_SUI>()));
      let f_multiple = compute_multiple(state, base_price); 

      let x_supply = coin::total_supply(repository::borrow<TypeName, TreasuryCap<F_SUI>>(repository, type_name::get<X_SUI>()));
      let f_nav = f_sui_nav(state, f_multiple);

      su_state::new(
        base_supply,
        base_nav,
        f_multiple,
        f_supply,
        f_nav,
        x_supply,
        if (x_supply == 0) PRECISION else x_sui_nav(base_supply, base_nav, f_supply, f_nav, x_supply)
      )
    };

    // cache the f_nav
    state.last_f_nav = su_state::f_nav(su_state);

    su_state
  }

  fun compute_multiple(state: &StateV1, base_price: u64): Int {
    let genesis_price = int::from_u64(state.genesis_price);
    let base_price = int::from_u64(base_price);
    let precision = int::from_u64(PRECISION);
    let beta = int::from_u64(F_BETA);

    let ratio = int::div_down(int::mul(int::sub(base_price, genesis_price), precision), genesis_price);

    int::div_down(int::mul(beta, ratio), precision)
  }

  fun f_sui_nav(state: &StateV1, multiple: Int): u64 {

    if (int::is_neg(multiple))
      assert!(PRECISION > int::to_u64(int::abs(multiple)), EMultipleIsTooSmall)
    else 
      assert!((PRECISION as u256) * (PRECISION as u256) > int::to_u256(multiple), 0);
    
    let x = int::to_u64(int::add(int::from_u64(PRECISION), multiple));

    mul_div_down(state.last_f_nav, x, PRECISION)
  } 

  fun x_sui_nav(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    x_supply: u64
  ): u64 {
    let (
      base_supply,
      base_nav,
      f_supply,
      f_nav,
      x_supply
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (f_supply as u256),
      (f_nav as u256),
      (x_supply as u256)
    );

    (((base_supply * base_nav) - (f_supply * f_nav)) / x_supply as u64)
  }

  // === Test Functions ===  
}