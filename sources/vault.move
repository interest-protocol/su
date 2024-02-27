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

  // === Errors ===

  const EInvalidOracle: u64 = 0;
  const EZeroBaseInIsNotAllowed: u64 = 1;
  const ETreasuryMustBeEmpty: u64 = 2;
  const EInvalidFCoinAmountOut: u64 = 3;
  const EInvalidXCoinAmountOut: u64 = 4;
  const ECannotMintFCoinInLiquidationMode: u64 = 5;

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
    standard_fees: Fees,
    stability_fees: Fees,
    stability_collateral_ratio: u64,
    liquidation_collateral_ratio: u64
  }

  struct Fees has store, copy, drop {
    f_coin_mint: u64,
    f_coin_redeem: u64,
    x_coin_mint: u64,
    x_coin_redeem: u64
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

    let standard_fees = Fees {
      f_coin_mint: 2500000, // 0.25%
      f_coin_redeem: 2500000, // 0.25%  
      x_coin_mint: 10000000,
      x_coin_redeem: 10000000
    };

    let stability_fees = Fees {
      f_coin_mint: PRECISION / 10, // 10%
      f_coin_redeem: 0,
      x_coin_mint: 0,
      x_coin_redeem: PRECISION / 10 // 10%
    };

    let vault = Vault {
      id: object::new(ctx),
      oracle_id,
      standard_fees,
      stability_fees,
      stability_collateral_ratio: 200 * PRECISION, // 200% CR
      liquidation_collateral_ratio: 180 * PRECISION, // 170 CR %
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

    let (max_base_in_before_liquidation_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      treasury_cap_map, 
      base_price, 
      self.liquidation_collateral_ratio
    );

    assert!(max_base_in_before_liquidation_mode != 0 || max_base_in_before_liquidation_mode >= base_in_value, ECannotMintFCoinInLiquidationMode);

    let fee_in = compute_mint_f_coin_fee(self, &mut base_in, max_base_in_before_stability_mode, max_base_in_before_liquidation_mode, ctx);

    treasury::add_fee(treasury, fee_in);

    let (f_coin, x_coin) = treasury::mint(treasury, treasury_cap_map, base_in, c, base_price, MINT_F_COIN, ctx);

    coin::destroy_zero(x_coin);

    assert!(coin::value(&f_coin) >= min_f_coin_amount, EInvalidFCoinAmountOut);

    f_coin
  }

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===

  fun destroy_price(self: &Vault, oracle_price: Price): u64 {
    let (oracle_id, scaled_price, _, _) = oracle::destroy_price(oracle_price);
    assert!(self.oracle_id == oracle_id, EInvalidOracle);

    (scaled_price / (PRECISION as u256) as u64)
  }

  fun compute_mint_f_coin_fee(
    self: &Vault,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    max_base_in_before_liquidation_mode: u64,
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = coin::value(base_in);
    let fees_in = coin::zero<I_SUI>(ctx);

    // charge normal fees
    if (max_base_in_before_stability_mode >= base_in_value) {
      let fee_amount = compute_fee(base_in_value,self.standard_fees.f_coin_mint);
      coin::join(&mut fees_in, coin::split(base_in, fee_amount, ctx));
    } else if (
      base_in_value > max_base_in_before_stability_mode 
      && max_base_in_before_liquidation_mode >= base_in_value
    ) {
      let standard_fee_amount = compute_fee(max_base_in_before_stability_mode,self.standard_fees.f_coin_mint);
      let liquidation_mode_fee_amount = compute_fee(base_in_value - max_base_in_before_stability_mode,self.stability_fees.f_coin_mint);
      coin::join(&mut fees_in, coin::split(base_in, standard_fee_amount + liquidation_mode_fee_amount, ctx)); 
    } else 
      abort ECannotMintFCoinInLiquidationMode;

    fees_in
  }

  fun compute_fee(value: u64, fee: u64): u64 {
    mul_div_up(value, fee, PRECISION)
  }

  // === Test Functions ===  
}