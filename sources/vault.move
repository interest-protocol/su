module su::vault {
  // === Imports ===
  
  use sui::clock::Clock;
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, TreasuryCap};

  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::treasury::{Self, Treasury};
  use su::treasury_cap_map::TreasuryCapMap;

  use suitears::math64::mul_div_up;
  use suitears::oracle::{Self, Price};

  // === Friends ===

  friend su::admin;

  // === Errors ===

  const EInvalidOracle: u64 = 0;
  const EZeroBaseInIsNotAllowed: u64 = 1;
  const ETreasuryMustBeEmpty: u64 = 2;
  const EInvalidFCoinAmountOut: u64 = 3;
  const EInvalidXCoinAmountOut: u64 = 4;
  const ECannotMintFCoinInLiquidationMode: u64 = 5;
  const EStabilityCollateralRatioIsTooLow: u64 = 6;
  const ERebalanceCollateralRatioIsTooHigh: u64 = 6;

  // === Constants ===

  const PRECISION: u64 = 1_000_000_000;

  // Mint Options
  const MINT_F_COIN: u8 = 0;
  const MINT_X_COIN: u8 = 1;
  const MINT_BOTH: u8 = 2;

  // === Structs ===

  struct Vault has key {
    id: UID,
    oracle_id: ID,
    x_fees: Fees,
    f_fees: Fees,
    stability_collateral_ratio: u64,
    rebalance_collateral_ratio: u64
  }

  struct Fees has store, copy, drop {
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  }

  // === Public-Mutative Functions ===

  public fun share_genesis_state(
    treasury_cap_map: &mut TreasuryCapMap,
    f_treasury_cap: TreasuryCap<F_SUI>,
    x_treasury_cap: TreasuryCap<X_SUI>,
    c: &Clock,
    genesis_price: Price,
    base_balance_cap: u64,
    ctx: &mut TxContext
  ) { 
    let (oracle_id, scaled_price, _, _) = oracle::destroy_price(genesis_price);

    let price = (scaled_price / (PRECISION as u256) as u64);

    treasury::share_genesis_state(treasury_cap_map, f_treasury_cap, x_treasury_cap, c, price, base_balance_cap, ctx);

    let f_fees = Fees {
      standard_mint: 2500000,
      standard_redeem: 2500000,
      stability_mint: PRECISION / 10,
      stability_redeem: 0
    };

    let x_fees = Fees {
      standard_mint: 10000000,
      standard_redeem: 10000000,
      stability_mint: 0,
      stability_redeem: PRECISION / 10
    };

    let vault = Vault {
      id: object::new(ctx),
      f_fees,
      x_fees,
      oracle_id,
      stability_collateral_ratio: 200 * PRECISION, // 200% CR
      rebalance_collateral_ratio: 180 * PRECISION, // 180 CR %
    };

    share_object(vault);
  }

  public fun mint_both(
    self: &Vault,
    treasury: &mut Treasury,
    treasury_cap_map: &mut TreasuryCapMap,
    c: &Clock,
    base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_f_coin_amount: u64,
    min_x_coin_amount: u64,
    ctx: &mut TxContext
  ): (Coin<F_SUI>, Coin<X_SUI>) {
    assert!(coin::value(&base_in) != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);

    assert!(treasury::base_balance(treasury) == 0, ETreasuryMustBeEmpty);

    let (f_coin, x_coin) = treasury::mint(treasury, treasury_cap_map, base_in, c, base_price, MINT_BOTH, ctx);

    assert!(coin::value(&f_coin) >= min_f_coin_amount, EInvalidFCoinAmountOut);
    assert!(coin::value(&x_coin) >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (f_coin, x_coin)
  }

  public fun mint_f_coin(
    self: &Vault,
    treasury: &mut Treasury,
    treasury_cap_map: &mut TreasuryCapMap,
    c: &Clock,
    base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_f_coin_amount: u64,
    ctx: &mut TxContext    
  ): Coin<F_SUI> {
    let base_in_value = coin::value(&base_in);
    assert!(base_in_value != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);

    let (max_base_in_before_stability_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      treasury_cap_map, 
      base_price, 
      self.stability_collateral_ratio
    );

    let (max_base_in_before_rebalance_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      treasury_cap_map, 
      base_price, 
      self.rebalance_collateral_ratio
    );

    assert!(max_base_in_before_rebalance_mode != 0 || max_base_in_before_rebalance_mode > base_in_value, ECannotMintFCoinInLiquidationMode);

    let fee_in = compute_mint_fees(
      self.f_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode, 
      max_base_in_before_rebalance_mode, 
      ctx
    );

    treasury::add_fee(treasury, fee_in);

    let (f_coin, x_coin) = treasury::mint(treasury, treasury_cap_map, base_in, c, base_price, MINT_F_COIN, ctx);

    coin::destroy_zero(x_coin);

    assert!(coin::value(&f_coin) >= min_f_coin_amount, EInvalidFCoinAmountOut);

    f_coin
  }

  public fun mint_x_coin(
    self: &Vault,
    treasury: &mut Treasury,
    treasury_cap_map: &mut TreasuryCapMap,
    c: &Clock,
    base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_x_coin_amount: u64,
    ctx: &mut TxContext     
  ): (Coin<X_SUI>, Coin<I_SUI>) {
    let base_in_value = coin::value(&base_in);
    assert!(base_in_value != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);    

    let (max_base_in_before_stability_mode, _) = treasury::max_mintable_x_coin(
      treasury, 
      treasury_cap_map, 
      base_price, 
      self.stability_collateral_ratio
    );

    let (max_base_in_before_rebalance_mode, _) = treasury::max_mintable_x_coin(
      treasury, 
      treasury_cap_map, 
      base_price, 
      self.rebalance_collateral_ratio
    );

    let fee_in = compute_mint_fees(
      self.x_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode, 
      max_base_in_before_rebalance_mode, 
      ctx
    );

    treasury::add_fee(treasury, fee_in);

    let (f_coin, x_coin) = treasury::mint(treasury, treasury_cap_map, base_in, c, base_price, MINT_X_COIN, ctx);

    coin::destroy_zero(f_coin);

    let bonus_coin = if (base_in_value >= max_base_in_before_rebalance_mode) {
      treasury::take_bonus(treasury, base_in_value - max_base_in_before_rebalance_mode, ctx)
    } else coin::zero(ctx);

    assert!(coin::value(&x_coin) >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (x_coin, bonus_coin)
  }

  // === Public-View Functions ===

  // === Public-Friend Functions ===

  public(friend) fun set_oracle_id(self: &mut Vault, oracle_id: ID) {
    self.oracle_id = oracle_id;
  }

  public(friend) fun set_fees(
    self: &mut Vault,
    is_x: bool,     
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  ) {
    let fees = Fees {
      standard_mint,
      standard_redeem,
      stability_mint,
      stability_redeem
    };   

    if (is_x) {
      self.x_fees = fees;
    } else {
      self.f_fees = fees;
    };
  }

  public(friend) fun set_stability_collateral_ratio(
    self: &mut Vault,
    stability_collateral_ratio: u64
  ) {
    assert!(stability_collateral_ratio > self.rebalance_collateral_ratio, EStabilityCollateralRatioIsTooLow);
    self.stability_collateral_ratio = stability_collateral_ratio;
  }  

  public(friend) fun set_rebalance_collateral_ratio(
    self: &mut Vault,
    rebalance_collateral_ratio: u64
  ) {
    assert!(self.stability_collateral_ratio > rebalance_collateral_ratio, ERebalanceCollateralRatioIsTooHigh);
    self.rebalance_collateral_ratio = rebalance_collateral_ratio;
  }    

  // === Private Functions ===

  fun destroy_price(self: &Vault, oracle_price: Price): u64 {
    let (oracle_id, scaled_price, _, _) = oracle::destroy_price(oracle_price);
    assert!(self.oracle_id == oracle_id, EInvalidOracle);

    (scaled_price / (PRECISION as u256) as u64)
  }

  fun compute_mint_fees(
    fees: Fees,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    max_base_in_before_liquidation_mode: u64,
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = coin::value(base_in);
    let fees_in = coin::zero<I_SUI>(ctx);

    // charge normal fees
    if (max_base_in_before_stability_mode >= base_in_value) {
      let fee_amount = compute_fee(base_in_value,fees.standard_mint);
      coin::join(&mut fees_in, coin::split(base_in, fee_amount, ctx));
    } else {
      let standard_fee_amount = compute_fee(max_base_in_before_stability_mode,fees.standard_mint);
      let liquidation_mode_fee_amount = compute_fee(base_in_value - max_base_in_before_stability_mode,fees.stability_mint);
      coin::join(&mut fees_in, coin::split(base_in, standard_fee_amount + liquidation_mode_fee_amount, ctx)); 
    };

    fees_in
  }

  fun compute_fee(value: u64, fee: u64): u64 {
    mul_div_up(value, fee, PRECISION)
  }

  // === Test Functions ===  
}