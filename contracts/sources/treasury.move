module su::treasury {
  // === Imports ===

  use std::type_name;

  use sui::clock::Clock;
  use sui::transfer::share_object;
  use sui::balance::{Self, Balance};
  use sui::versioned::{Self, Versioned};
  use sui::object_bag::{Self, ObjectBag};
  use sui::coin::{Self, Coin, TreasuryCap};

  use suitears::int::{Self, Int};
  use suitears::math64::{min, mul_div_down};

  use su::cast;
  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::ema::{Self, EMA};
  use su::sui_dollar::SUI_DOLLAR;
  use su::su_state::{Self, SuState};

  // Method Aliases

  use fun cast::to_u64 as u256.to_u64;
  use fun cast::to_u256 as u64.to_u256;  

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
  const INITIAL_MINT_RATIO: u256 = 300_000_000;
  const THIRTY_MINUTES_IN_SECONDS: u64 = 1800;

  // Mint Options
  const MINT_D_COIN: u8 = 0;
  const MINT_F_COIN: u8 = 1;
  const MINT_X_COIN: u8 = 2;
  const MINT_ALL: u8 = 3;

  // === Structs ===

  public struct Fees has store {
    reserve: u64,
    rebalance: u64,
  }

  public struct StateV1 has store {
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

  public struct Treasury has key {
    id: UID,
    inner: Versioned
  }

  // === Public-Friend Functions ===

  public(package) fun share_genesis_state(
    d_treasury_cap: TreasuryCap<SUI_DOLLAR>,
    f_treasury_cap: TreasuryCap<F_SUI>,
    x_treasury_cap: TreasuryCap<X_SUI>,
    c: &Clock,
    genesis_price: u64,
    base_balance_cap: u64,
    ctx: &mut TxContext
  ) {

    let mut cap_map = object_bag::new(ctx);

    cap_map.add(type_name::get<SUI_DOLLAR>(), d_treasury_cap);
    cap_map.add(type_name::get<F_SUI>(), f_treasury_cap);
    cap_map.add(type_name::get<X_SUI>(), x_treasury_cap);


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

  public(package) fun reserve_fee(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.fees.reserve
  }

  public(package) fun rebalance_fee(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.fees.rebalance
  }

  public(package) fun last_f_nav(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.last_f_nav
  }

  public(package) fun genesis_price(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.genesis_price
  }  

  public(package) fun base_balance_cap(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.base_balance_cap
  }  

  public(package) fun base_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.base_balance.value()
  }    

  public(package) fun reserve_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.reserve_balance.value()
  }   

  public(package) fun rebalance_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.rebalance_balance.value()
  }    

  public(package) fun admin_balance(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.admin_balance.value()
  }      

  public(package) fun collateral_ratio(self: &mut Treasury, base_price: u64): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.collateral_ratio()
  }

  public(package) fun base_supply(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    state.base_balance.value()
  }

  public(package) fun base_nav(self: &mut Treasury, base_price: u64): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.base_nav()
  }

  public(package) fun d_supply(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let treasury_cap = treasury_cap_impl<SUI_DOLLAR>(&state.cap_map);

    treasury_cap.total_supply()
  }

  public(package) fun f_multiple(self: &mut Treasury, base_price: u64): Int {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.f_multiple()
  }

  public(package) fun f_supply(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let treasury_cap = treasury_cap_impl<F_SUI>(&state.cap_map);

    treasury_cap.total_supply()
  }

  public(package) fun f_nav(self: &mut Treasury, base_price: u64): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.f_nav()
  }

  public(package) fun x_supply(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let treasury_cap = treasury_cap_impl<X_SUI>(&state.cap_map);

    treasury_cap.total_supply()
  }

  public(package) fun x_nav(self: &mut Treasury, base_price: u64): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.x_nav()
  }

  public(package) fun leverage_ratio(self: &mut Treasury, c: &Clock): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.ema.ema_value(c)
  }

  public(package) fun su_state(self: &mut Treasury, base_price: u64): SuState {
    let state = load_treasury_state_and_maybe_upgrade(self);
    compute_su_state(state, base_price)
  }   

  public(package) fun bonus_rate(self: &mut Treasury): u64 {
    let state = load_treasury_state_and_maybe_upgrade(self);
    state.bonus_rate
  }

  public(package) fun max_mintable_d_coin(self: &mut Treasury, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.max_mintable_d_coin(new_collateral_ratio)
  }

  public(package) fun max_mintable_f_coin(self: &mut Treasury, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.max_mintable_f_coin(new_collateral_ratio)
  }

  public(package) fun max_mintable_x_coin(self: &mut Treasury, base_price: u64, new_collateral_ratio: u64): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.max_mintable_x_coin(new_collateral_ratio)
  } 

  public(package) fun max_redeemable_d_coin(
    self: &mut Treasury, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state,base_price);

    su_state.max_redeemable_d_coin(new_collateral_ratio)
  }  

  public(package) fun max_redeemable_f_coin(
    self: &mut Treasury, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state,base_price);

    su_state.max_redeemable_f_coin(new_collateral_ratio)
  }  

  public(package) fun max_redeemable_x_coin(
    self: &mut Treasury, 
    base_price: u64, 
    new_collateral_ratio: u64
  ): (u64, u64) {
    assert!(new_collateral_ratio > PRECISION, ENewCollateralRatioIsTooSmall);

    let state = load_treasury_state_and_maybe_upgrade(self);

    let su_state = compute_su_state(state, base_price);

    su_state.max_redeemable_x_coin(new_collateral_ratio)
  }  

  public(package) fun ema_update_sample_interval(
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

    state.ema.set_sample_interval(new_sample_interval);
  }

  public(package) fun treasury_cap<CoinType: drop>(self: &mut Treasury): &TreasuryCap<CoinType> {
    let state = load_treasury_state_and_maybe_upgrade(self);
    treasury_cap_impl(&state.cap_map)
  }

  public(package) fun treasury_cap_mut<CoinType: drop>(self: &mut Treasury): &mut TreasuryCap<CoinType> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    treasury_cap_mut_impl(&mut state.cap_map)
  }  

  public(package) fun set_base_balance_cap(self: &mut Treasury, new_base_balance_cap: u64) {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.base_balance_cap = new_base_balance_cap;
  } 

  public(package) fun add_fee(self: &mut Treasury, base_in: Coin<I_SUI>) {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);

    let mut balance_in = base_in.into_balance();
    
    deposit_fee(&mut state.reserve_balance, &mut balance_in, state.fees.reserve);
    deposit_fee(&mut state.rebalance_balance, &mut balance_in, state.fees.reserve);

    let remaining_value = balance::value(&balance_in);
    if (remaining_value != 0) {
      state.admin_balance.join(balance_in);
    } else {
      balance_in.destroy_zero();
    };
  }

  public(package) fun remove_rebalance_fee(self: &mut Treasury): Balance<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);

    state.rebalance_balance.withdraw_all()
  }

  public(package) fun remove_reserve_fee(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.reserve_balance.split(amount).into_coin(ctx)
  }

  public(package) fun remove_admin_fee(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.admin_balance.split(amount).into_coin(ctx)
  }

  public(package) fun set_bonus_rate(self: &mut Treasury, bonus_rate: u64) {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.bonus_rate = bonus_rate;
  }

  public(package) fun set_fees(self: &mut Treasury, rebalance_fee: u64, reserve_fee: u64) {
    assert!(PRECISION >= rebalance_fee + reserve_fee, EFeesMustBeSmallerThanPrecision);
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    state.fees.rebalance = rebalance_fee;
    state.fees.reserve = reserve_fee;
  }

  public(package) fun mint(
    self: &mut Treasury,
    base_in: Coin<I_SUI>,
    c: &Clock,
    base_price: u64, 
    mint_option: u8,
    ctx: &mut TxContext
  ): (Coin<SUI_DOLLAR>, Coin<F_SUI>, Coin<X_SUI>) {
    assert!(MINT_ALL >= mint_option, EInvalidMintOption);

    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    let su_state = compute_su_state(state, base_price);

    update_ema_leverage_ratio(state, c, su_state);

    let base_in_value = base_in.value();

    let base_supply = state.base_balance.value();

    assert!(state.base_balance_cap >= state.base_balance.join(base_in.into_balance()), EBaseBalanceCapReached);

    let mut d_coin = coin::zero(ctx);
    let mut f_coin = coin::zero(ctx);
    let mut x_coin = coin::zero(ctx);

    if (mint_option == MINT_F_COIN) {
      let treasury_f_cap = treasury_cap_mut_impl<F_SUI>(&mut state.cap_map);
      f_coin.join(coin::mint(treasury_f_cap, su_state.mint_f_coin(base_in_value), ctx));
    } else if (mint_option == MINT_D_COIN) {
      let treasury_f_cap = treasury_cap_mut_impl<SUI_DOLLAR>(&mut state.cap_map);
      d_coin.join(coin::mint(treasury_f_cap, su_state.mint_d_coin(base_in_value), ctx));
    } else if (mint_option == MINT_X_COIN) {
      let treasury_x_cap = treasury_cap_mut_impl<X_SUI>(&mut state.cap_map);
      x_coin.join(coin::mint(treasury_x_cap, su_state.mint_x_coin(base_in_value), ctx));
    } else {
      if (base_supply == 0) {
        let (base_in_value, base_nav, precision) = (
          base_in_value.to_u256(),
          su_state.base_nav().to_u256(),
          PRECISION.to_u256()
        );

        let total_val = base_in_value * base_nav;
        let beta_coins_amout = total_val * (INITIAL_MINT_RATIO / 2) / precision / precision;
        let x_amount = (total_val / precision) - (beta_coins_amout * 2);

        let treasury_f_cap = treasury_cap_mut_impl<SUI_DOLLAR>(&mut state.cap_map);
        d_coin.join(treasury_f_cap.mint(beta_coins_amout.to_u64(), ctx));

        let treasury_f_cap = treasury_cap_mut_impl<F_SUI>(&mut state.cap_map);
        f_coin.join(treasury_f_cap.mint(beta_coins_amout.to_u64(), ctx));

        let treasury_x_cap = treasury_cap_mut_impl<X_SUI>(&mut state.cap_map);
        x_coin.join(coin::mint(treasury_x_cap, x_amount.to_u64(), ctx));
      } else {
        let (d_amount, f_amount, x_amount) = su_state.mint(base_in_value);

        let treasury_d_cap = treasury_cap_mut_impl<SUI_DOLLAR>(&mut state.cap_map);
        d_coin.join(treasury_d_cap.mint(su_state.mint_f_coin(d_amount), ctx));

        let treasury_f_cap = treasury_cap_mut_impl<F_SUI>(&mut state.cap_map);
        f_coin.join(treasury_f_cap.mint(su_state.mint_f_coin(f_amount), ctx));

        let treasury_x_cap = treasury_cap_mut_impl<X_SUI>(&mut state.cap_map);
        x_coin.join(treasury_x_cap.mint(su_state.mint_x_coin(x_amount), ctx));
      }
    };

    (d_coin, f_coin, x_coin)
  }

  public(package) fun redeem(
    self: &mut Treasury,
    d_coin_in: Coin<SUI_DOLLAR>,
    f_coin_in: Coin<F_SUI>,
    x_coin_in: Coin<X_SUI>,
    c: &Clock,
    base_price: u64,
    ctx: &mut TxContext 
  ): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    let su_state = compute_su_state(state, base_price);

    update_ema_leverage_ratio(state, c, su_state);

    let base_out = su_state.redeem(d_coin_in.value(), f_coin_in.value(), x_coin_in.value());    
    
    treasury_cap_mut_impl<SUI_DOLLAR>(&mut state.cap_map).burn(d_coin_in);
    treasury_cap_mut_impl<F_SUI>(&mut state.cap_map).burn(f_coin_in);
    treasury_cap_mut_impl<X_SUI>(&mut state.cap_map).burn(x_coin_in);

    state.base_balance.split(base_out).into_coin(ctx)
  }

  public(package) fun take_bonus(self: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    let state = load_mut_treasury_state_and_maybe_upgrade(self);
    let reserve_balance_amount = state.reserve_balance.value();

    if (reserve_balance_amount == 0) return coin::zero(ctx);

    let bonus_amount = mul_div_down(amount, state.bonus_rate, PRECISION);
    state.reserve_balance.split(min(bonus_amount, reserve_balance_amount)).into_coin(ctx)
  }

  // === Private Functions ===

  fun load_treasury_state_and_maybe_upgrade(self: &mut Treasury): &StateV1 {
    maybe_upgrade_treasury_state_to_latest(self);
    self.inner.load_value()
  }

  fun load_mut_treasury_state_and_maybe_upgrade(self: &mut Treasury): &mut StateV1 {
    maybe_upgrade_treasury_state_to_latest(self);
    self.inner.load_value_mut()
  }

  fun maybe_upgrade_treasury_state_to_latest(self: &mut Treasury) {
    // * IMPORTANT: When new versions are added, we need to explicitly upgrade here.
    assert!(self.inner.version() == STATE_VERSION_V1, EInvalidVersion);
  }

  fun update_ema_leverage_ratio(state: &mut StateV1, c: &Clock, su_state: SuState) {
    if (su_state.base_supply() == 0) return;
    
    let genesis_price = int::from_u64(state.genesis_price);
    let base_nav = int::from_u64(su_state.base_nav());
    let precision = int::from_u64(PRECISION);

    let earning_ratio = base_nav.sub(genesis_price).mul(precision).div_down(genesis_price);
    let ratio = su_state.leverage_ratio(F_BETA, earning_ratio);

    state.ema.upate(c, ratio);
  }

  fun treasury_cap_impl<CoinType: drop>(cap_map: &ObjectBag): &TreasuryCap<CoinType> {
    cap_map.borrow(type_name::get<CoinType>())
  }

  fun treasury_cap_mut_impl<CoinType: drop>(cap_map: &mut ObjectBag): &mut TreasuryCap<CoinType> {
    cap_map.borrow_mut(type_name::get<CoinType>())
  }

  fun compute_su_state(state: &StateV1, base_price: u64): SuState {
    let base_supply = state.base_balance.value();
    let base_nav = base_price;

    let su_state = if (base_supply == 0) {
      su_state::new(base_supply, base_nav, int::zero(), 0, 0, PRECISION, 0, PRECISION)
    } else {
      let d_supply = treasury_cap_impl<SUI_DOLLAR>(&state.cap_map).total_supply();
      let f_supply = treasury_cap_impl<F_SUI>(&state.cap_map).total_supply();
      let f_multiple = compute_f_multiple(state, base_price); 
      let f_nav = compute_f_nav(state, f_multiple);
      let x_supply = treasury_cap_impl<X_SUI>(&state.cap_map).total_supply();

      su_state::new(
        base_supply,
        base_nav,
        f_multiple,
        d_supply,
        f_supply,
        f_nav,
        x_supply,
        if (x_supply == 0) PRECISION else compute_x_nav(base_supply, base_nav, d_supply, f_supply, f_nav, x_supply)
      )
    };

    su_state
  }

  fun compute_f_multiple(state: &StateV1, base_price: u64): Int {
    let genesis_price = int::from_u64(state.genesis_price);
    let base_price = int::from_u64(base_price);
    let precision = int::from_u64(PRECISION);
    let beta = int::from_u64(F_BETA);

    let ratio = base_price.sub(genesis_price).mul(precision).div_down(genesis_price);

    beta.mul(ratio).div_down(precision)
  }

  fun compute_f_nav(state: &StateV1, multiple: Int): u64 {
    if (multiple.is_neg())
      assert!(PRECISION > int::to_u64(multiple.abs()), EMultipleIsTooSmall)
    else 
      assert!(PRECISION.to_u256() * PRECISION.to_u256() > multiple.to_u256(), EMultipleIsTooLarge);
    
    let x = int::from_u64(PRECISION).add(multiple).to_u64();

    mul_div_down(state.last_f_nav, x, PRECISION)
  } 

  fun compute_x_nav(
    base_supply: u64,
    base_nav: u64,
    d_supply: u64,
    f_supply: u64,
    f_nav: u64,
    x_supply: u64
  ): u64 {
    let (
      base_supply,
      base_nav,
      d_supply,
      f_supply,
      f_nav,
      x_supply
    ) = (
      base_supply.to_u256(),
      base_nav.to_u256(),
      d_supply.to_u256(),
      f_supply.to_u256(),
      f_nav.to_u256(),
      x_supply.to_u256()
    );

    (((base_supply * base_nav) - ((f_supply * f_nav) + (d_supply * PRECISION.to_u256()))) / x_supply).to_u64()
  }

  fun deposit_fee(bal: &mut Balance<I_SUI>, balance_in: &mut Balance<I_SUI>, fee: u64) {
    let value = balance_in.value();
    bal.join(balance_in.split(mul_div_down(value, fee, PRECISION)));
  }
}