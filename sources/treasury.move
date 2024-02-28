module su::treasury {
  // === Imports ===
  
  use std::type_name;

  use sui::clock::Clock;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::balance::{Self, Balance};
  use sui::versioned::{Self, Versioned};
  use sui::object_bag::{Self, ObjectBag};
  use sui::coin::{Self, Coin, TreasuryCap};

  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::ema::{Self, EMA};
  use su::su_state::{Self, SuState};

  use suitears::int::{Self, Int};
  use suitears::math64::{min, mul_div_down};

  // === Friends ===
  
  friend su::vault;
  friend su::admin;

  // === Errors ===

  const EInvalidVersion: u64 = 0;
  const EMultipleIsTooSmall: u64 = 1;
  const EMultipleIsTooLarge: u64 = 2;
  const ENewCollateralRatioIsTooSmall: u64 = 3;
  const ESampleIntervalIsTooSmall: u64 = 4;
  const EInvalidMintOption: u64 = 5;
  const EBaseBalanceCapReached: u64 = 6;
  const EFeesMustBeSmallerThanPrecision: u64 = 7;

  // === Constants ===
  
  const STATE_VERSION_V1: u64 = 1;
  // 10%
  const F_BETA: u64 = 100_000_000;
  // 1 Unit or 100%
  const PRECISION: u64 = 1_000_000_000;
  const INITIAL_MINT_RATIO: u256 = 500_000_000;
  const THIRTY_MINUTES_IN_SECONDS: u64 = 1800;

  // Mint Options
  const MINT_F_COIN: u8 = 0;
  const MINT_X_COIN: u8 = 1;
  const MINT_BOTH: u8 = 2;

  // === Structs ===

  struct Fees has store {
    reserve: u64,
    rebalance: u64,
  }

  struct StateV1 has store {
    ema: EMA,
    fees: Fees,
    last_f_nav: u64,
    bonus_rate: u64,
    cap_map: ObjectBag,
    genesis_price: u64,
    base_balance_cap: u64,
    base_balance: Balance<I_SUI>,
    admin_balance: Balance<I_SUI>,
    reserve_balance: Balance<I_SUI>,
    rebalance_balance: Balance<I_SUI>,
  }

  struct Treasury has key {
    id: UID,
    inner: Versioned
  }

  // === Public-Friend Functions ===

  public(friend) fun share_genesis_state(
    f_treasury_cap: TreasuryCap<F_SUI>,
    x_treasury_cap: TreasuryCap<X_SUI>,
    c: &Clock,
    genesis_price: u64,
    base_balance_cap: u64,
    ctx: &mut TxContext
  ) {

    let cap_map = object_bag::new(ctx);

    object_bag::add(&mut cap_map, type_name::get<F_SUI>(),f_treasury_cap);
    object_bag::add(&mut cap_map, type_name::get<X_SUI>(),x_treasury_cap);

    let fees = Fees {
      reserve: 450000000,
      rebalance: 450000000
    };

    let state_v1 = StateV1 {
      fees,
      cap_map,
      bonus_rate: 0,
      genesis_price,
      base_balance_cap,
      last_f_nav: PRECISION,
      base_balance: balance::zero(),
      admin_balance: balance::zero(),
      reserve_balance: balance::zero(),
      rebalance_balance: balance::zero(),
      ema: ema::new(c, THIRTY_MINUTES_IN_SECONDS),
    };

    let treasury = Treasury {
      id: object::new(ctx),
      inner: versioned::create(STATE_VERSION_V1, state_v1, ctx)
    };

    share_object(treasury);
  } 

  public (friend) fun last_f_nav(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.last_f_nav
  }

  public (friend) fun genesis_price(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.genesis_price
  }  

  public (friend) fun base_balance_cap(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.base_balance_cap
  }  

  public (friend) fun base_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    balance::value(&state.base_balance)
  }    

  public (friend) fun reserve_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    balance::value(&state.reserve_balance)
  }   

  public (friend) fun rebalance_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    balance::value(&state.rebalance_balance)
  }    

  public (friend) fun admin_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    balance::value(&state.admin_balance)
  }      

  public(friend) fun collateral_ratio(self: &mut Treasury, base_price: u64): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state::collateral_ratio(su_state)
  }

  public (friend) fun leverage_ratio(self: &mut Treasury, c: &Clock): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    ema::ema_value(state.ema, c)
  }   

  public(friend) fun max_mintable_f_coin(self: &mut Treasury, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state::max_mintable_f_coin(su_state, new_collateral_ratio)
  }

  public(friend) fun max_mintable_x_coin(self: &mut Treasury, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state::max_mintable_x_coin(su_state, new_collateral_ratio)
  } 

  public(friend) fun max_mintable_x_coin_with_incentives(
    self: &mut Treasury, 
    base_price: u64, 
    new_collateral_ratio: u64,
    incentive_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state::max_mintable_x_coin_with_incentives(su_state, new_collateral_ratio, incentive_ratio)
  }

  public(friend) fun max_redeemable_f_coin(
    self: &mut Treasury, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state,base_price);

    su_state::max_redeemable_f_coin(su_state, new_collateral_ratio)
  }  

  public(friend) fun max_redeemable_x_coin(
    self: &mut Treasury, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state::max_redeemable_x_coin(su_state, new_collateral_ratio)
  }  

  public(friend) fun ema_update_sample_interval(
    self: &mut Treasury, 
    c: &Clock,
    base_price: u64, 
    new_sample_interval: u64
  ) {
    // 1 minute
    assert!(new_sample_interval >= 60000, ESampleIntervalIsTooSmall);

    let state = load_mut_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    update_ema_leverage_ratio(state, c, su_state);

    ema::set_sample_interval(&mut state.ema, new_sample_interval);
  }

  public(friend) fun treasury_cap<CoinType: drop>(self: &mut Treasury): &TreasuryCap<CoinType> {
    let state = load_treasury_state_and_maybe_upgrade(self);
    treasury_cap_impl(&state.cap_map)
  }

  public(friend) fun treasury_cap_mut<CoinType: drop>(self: &mut Treasury): &mut TreasuryCap<CoinType> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    treasury_cap_mut_impl(&mut state.cap_map)
  }  

  public(friend) fun update_base_balance_cap(self: &mut Treasury, new_base_balance_cap: u64) {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.base_balance_cap = new_base_balance_cap;
  } 

  public(friend) fun add_fee(self: &mut Treasury, base_in: Coin<I_SUI>) {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);

    let balance_in = coin::into_balance(base_in);
    
    deposit_fee(&mut state.reserve_balance, &mut balance_in, state.fees.reserve);
    deposit_fee(&mut state.rebalance_balance, &mut balance_in, state.fees.reserve);

    let remaining_value = balance::value(&balance_in);
    if (remaining_value != 0) {
      balance::join(&mut state.admin_balance, balance_in);
    } else {
      balance::destroy_zero(balance_in);
    };
  }

  public(friend) fun remove_rebalance_fee(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    coin::take(&mut state.rebalance_balance, amount, ctx)
  }

  public(friend) fun remove_reserve_fee(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    coin::take(&mut state.reserve_balance, amount, ctx)
  }

  public(friend) fun remove_admin_fee(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    coin::take(&mut state.admin_balance, amount, ctx)
  }

  public(friend) fun set_bonus_rate(self: &mut Treasury, bonus_rate: u64) {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.bonus_rate = bonus_rate;
  }

  public(friend) fun set_fees(self: &mut Treasury, rebalance_fee: u64, reserve_fee: u64) {
    assert!(PRECISION >= rebalance_fee + reserve_fee, EFeesMustBeSmallerThanPrecision);
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.fees.rebalance = rebalance_fee;
    state.fees.reserve = reserve_fee;
  }

  public(friend) fun mint(
    self: &mut Treasury,
    base_in: Coin<I_SUI>,
    c: &Clock,
    base_price: u64, 
    mint_option: u8,
    ctx: &mut TxContext
  ): (Coin<F_SUI>, Coin<X_SUI>) {
    assert!(MINT_BOTH >= mint_option, EInvalidMintOption);

    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    let su_state = compute_su_state(state, base_price);

    update_ema_leverage_ratio(state, c, su_state);

    let base_in_value = coin::value(&base_in);

    let base_supply = balance::value(&state.base_balance);

    assert!(state.base_balance_cap >= balance::join(&mut state.base_balance, coin::into_balance(base_in)), EBaseBalanceCapReached);

    let f_coin = coin::zero(ctx);
    let x_coin = coin::zero(ctx);

    if (mint_option == MINT_F_COIN) {
      let treasury_f_cap = treasury_cap_mut_impl<F_SUI>(&mut state.cap_map);
      coin::join(&mut f_coin, coin::mint(treasury_f_cap, su_state::mint_f_coin(su_state, base_in_value), ctx));
    } else if (mint_option == MINT_X_COIN) {
      let treasury_x_cap = treasury_cap_mut_impl<X_SUI>(&mut state.cap_map);
      coin::join(&mut x_coin, coin::mint(treasury_x_cap, su_state::mint_x_coin(su_state, base_in_value), ctx));
    } else {
      if (base_supply == 0) {
        let (base_in_value, base_nav, precision) = (
          (base_in_value as u256),
          (su_state::base_nav(su_state) as u256),
          (PRECISION as u256)
        );

        let total_val = base_in_value * base_nav;
        let f_amount = total_val * INITIAL_MINT_RATIO / precision / precision;
        let x_amount = (total_val / precision) - f_amount;

        let treasury_f_cap = treasury_cap_mut_impl<F_SUI>(&mut state.cap_map);
        coin::join(&mut f_coin, coin::mint(treasury_f_cap, (f_amount as u64), ctx));

        let treasury_x_cap = treasury_cap_mut_impl<X_SUI>(&mut state.cap_map);
        coin::join(&mut x_coin, coin::mint(treasury_x_cap, (x_amount as u64), ctx));
      } else {
        let (f_amount, x_amount) = su_state::mint(su_state, base_in_value);
        let treasury_f_cap = treasury_cap_mut_impl<F_SUI>(&mut state.cap_map);
        coin::join(&mut f_coin, coin::mint(treasury_f_cap, su_state::mint_f_coin(su_state, f_amount), ctx));

        let treasury_x_cap = treasury_cap_mut_impl<X_SUI>(&mut state.cap_map);
        coin::join(&mut x_coin, coin::mint(treasury_x_cap, su_state::mint_x_coin(su_state, x_amount), ctx));
      }
    };

    (f_coin, x_coin)
  }

  public(friend) fun redeem(
    self: &mut Treasury,
    f_coin_in: Coin<F_SUI>,
    x_coin_in: Coin<X_SUI>,
    c: &Clock,
    base_price: u64,
    ctx: &mut TxContext 
  ): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    let su_state = compute_su_state(state, base_price);

    update_ema_leverage_ratio(state, c, su_state);

    let base_out = su_state::redeem(su_state, coin::value(&f_coin_in), coin::value(&x_coin_in));    
    
    coin::burn(treasury_cap_mut_impl<F_SUI>(&mut state.cap_map), f_coin_in);

    coin::burn(treasury_cap_mut_impl<X_SUI>(&mut state.cap_map), x_coin_in);

    coin::take(&mut state.base_balance, base_out, ctx)
  }

  public(friend) fun take_bonus(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    let reserve_balance_amount = balance::value(&state.reserve_balance);

    if (reserve_balance_amount == 0) return coin::zero(ctx);

    let bonus_amount = mul_div_down(amount, state.bonus_rate, PRECISION);
    coin::take(&mut state.reserve_balance, min(bonus_amount, reserve_balance_amount), ctx)
  }

  // === Private Functions ===

  fun load_treasury_state_and_maybe_upgrade(self: &mut Treasury): &StateV1 {
    maybe_upgrade_treasury_state_to_latest(self);
    versioned::load_value(&self.inner)
  }

  fun load_mut_treasury_state_and_maybe_upgrade(self: &mut Treasury): &mut StateV1 {
    maybe_upgrade_treasury_state_to_latest(self);
    versioned::load_value_mut(&mut self.inner)
  }

  #[allow(unused_mut_parameter)]
  fun maybe_upgrade_treasury_state_to_latest(self: &mut Treasury) {
    // * IMPORTANT: When new versions are added, we need to explicitly upgrade here.
    assert!(versioned::version(&self.inner) == STATE_VERSION_V1, EInvalidVersion);
  }

  fun update_ema_leverage_ratio(state: &mut StateV1, c: &Clock, su_state: SuState) {
    let genesis_price = int::from_u64(state.genesis_price);
    let base_nav = int::from_u64(su_state::base_nav(su_state));
    let precision = int::from_u64(PRECISION);

    let earning_ratio = int::div_down(int::mul(int::sub(base_nav, genesis_price), precision), genesis_price);
    let ratio = su_state::leverage_ratio(su_state, F_BETA, earning_ratio);

    ema::upate(&mut state.ema, c, ratio);
  }

  fun treasury_cap_impl<CoinType: drop>(cap_map: &ObjectBag): &TreasuryCap<CoinType> {
    object_bag::borrow(cap_map, type_name::get<CoinType>())
  }

  fun treasury_cap_mut_impl<CoinType: drop>(cap_map: &mut ObjectBag): &mut TreasuryCap<CoinType> {
    object_bag::borrow_mut(cap_map, type_name::get<CoinType>())
  }

  fun compute_su_state(state: &StateV1, base_price: u64): SuState {
    let base_supply = balance::value(&state.base_balance);
    let base_nav = base_price;

    let su_state = if (base_supply == 0) {
      su_state::new(base_supply, base_nav, int::zero(), 0, PRECISION, 0, PRECISION)
    } else {
      let f_supply = coin::total_supply(treasury_cap_impl<F_SUI>(&state.cap_map));
      let f_multiple = compute_f_multiple(state, base_price); 
      let f_nav = compute_f_nav(state, f_multiple);

      let x_supply = coin::total_supply(treasury_cap_impl<X_SUI>(&state.cap_map));

      su_state::new(
        base_supply,
        base_nav,
        f_multiple,
        f_supply,
        f_nav,
        x_supply,
        if (x_supply == 0) PRECISION else compute_x_nav(base_supply, base_nav, f_supply, f_nav, x_supply)
      )
    };

    su_state
  }

  fun compute_f_multiple(state: &StateV1, base_price: u64): Int {
    let genesis_price = int::from_u64(state.genesis_price);
    let base_price = int::from_u64(base_price);
    let precision = int::from_u64(PRECISION);
    let beta = int::from_u64(F_BETA);

    let ratio = int::div_down(int::mul(int::sub(base_price, genesis_price), precision), genesis_price);

    int::div_down(int::mul(beta, ratio), precision)
  }

  fun compute_f_nav(state: &StateV1, multiple: Int): u64 {
    if (int::is_neg(multiple))
      assert!(PRECISION > int::to_u64(int::abs(multiple)), EMultipleIsTooSmall)
    else 
      assert!((PRECISION as u256) * (PRECISION as u256) > int::to_u256(multiple), EMultipleIsTooLarge);
    
    let x = int::to_u64(int::add(int::from_u64(PRECISION), multiple));

    mul_div_down(state.last_f_nav, x, PRECISION)
  } 

  fun compute_x_nav(
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

  fun deposit_fee(bal: &mut Balance<I_SUI>, balance_in: &mut Balance<I_SUI>, fee: u64) {
    let value = balance::value(balance_in);
    balance::join(bal, 
      balance::split(
        balance_in, 
        mul_div_down(value, fee, PRECISION)
      )
    );
  }
}