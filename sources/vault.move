module su::vault {
  // === Imports ===
  
  use sui::math::pow;
  use sui::clock::Clock;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::coin::{Self, Coin, TreasuryCap};

  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::treasury::{Self, Treasury};

  use suitears::oracle::{Self, Price};
  use suitears::math64::{min, mul_div_up};

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
  const ERebalanceCollateralRatioIsTooHigh: u64 = 7;
  const EZeroFCoinIsNotAllowed: u64 = 8;
  const EZeroXCoinIsNotAllowed: u64 = 9;
  const ECannotRedeemXCoinOnRebalanceMode: u64 = 10;
  const EInvalidBaseCoinAmountOut: u64 = 4;

  // === Constants ===

  const PRECISION: u64 = 1_000_000_000;
  const PRECISION_DECIMALS: u8 = 9;

  // Mint Options
  const MINT_F_COIN: u8 = 0;
  const MINT_X_COIN: u8 = 1;
  const MINT_BOTH: u8 = 2;

  // === Structs ===

  struct Vault has key {
    id: UID,
    oracle_id_address: address,
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
    f_treasury_cap: TreasuryCap<F_SUI>,
    x_treasury_cap: TreasuryCap<X_SUI>,
    c: &Clock,
    genesis_price: Price,
    base_balance_cap: u64,
    ctx: &mut TxContext
  ) { 
    let (oracle_id, scaled_price, _, _) = oracle::destroy_price(genesis_price);

    let price = (scaled_price / (PRECISION as u256) as u64);

    treasury::share_genesis_state(
      f_treasury_cap, 
      x_treasury_cap, 
      c, 
      price, 
      base_balance_cap, 
      ctx
    );

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
      oracle_id_address: object::id_to_address(&oracle_id),
      stability_collateral_ratio: 200 * PRECISION, // 200% CR
      rebalance_collateral_ratio: 180 * PRECISION, // 180 CR %
    };

    share_object(vault);
  }

  public fun mint_both(
    self: &Vault,
    treasury: &mut Treasury,
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

    let (f_coin, x_coin) = treasury::mint(treasury, base_in, c, base_price, MINT_BOTH, ctx);

    assert!(coin::value(&f_coin) >= min_f_coin_amount, EInvalidFCoinAmountOut);
    assert!(coin::value(&x_coin) >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (f_coin, x_coin)
  }

  public fun mint_f_coin(
    self: &Vault,
    treasury: &mut Treasury,
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
      base_price, 
      self.stability_collateral_ratio
    );

    let (max_base_in_before_rebalance_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      base_price, 
      self.rebalance_collateral_ratio
    );

    assert!(max_base_in_before_rebalance_mode != 0 || max_base_in_before_rebalance_mode > base_in_value, ECannotMintFCoinInLiquidationMode);

    treasury::add_fee(treasury, mint_fee(
      self.f_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode,
      ctx
    ));

    let (f_coin, x_coin) = treasury::mint(treasury, base_in, c, base_price, MINT_F_COIN, ctx);

    coin::destroy_zero(x_coin);

    assert!(coin::value(&f_coin) >= min_f_coin_amount, EInvalidFCoinAmountOut);

    f_coin
  }

  public fun mint_x_coin(
    self: &Vault,
    treasury: &mut Treasury,
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
      base_price, 
      self.stability_collateral_ratio
    );

    treasury::add_fee(treasury, mint_fee(
      self.x_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode, 
      ctx
    ));

    let (f_coin, x_coin) = treasury::mint(treasury, base_in, c, base_price, MINT_X_COIN, ctx);

    coin::destroy_zero(f_coin);

    let bonus_coin = if (base_in_value >= max_base_in_before_stability_mode) {
      treasury::take_bonus(treasury, base_in_value - max_base_in_before_stability_mode, ctx)
    } else coin::zero(ctx);

    assert!(coin::value(&x_coin) >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (x_coin, bonus_coin)
  }

  public fun redeem_f_coin(
    self: &Vault,
    treasury: &mut Treasury,
    c: &Clock,
    f_coin_in: Coin<F_SUI>,
    oracle_price: Price,
    min_base_amount: u64,
    ctx: &mut TxContext        
  ): Coin<I_SUI> {
    let f_coin_in_value = coin::value(&f_coin_in);
    assert!(f_coin_in_value != 0, EZeroFCoinIsNotAllowed);   

    let base_price = destroy_price(self, oracle_price);

    let (_, max_base_out_before_stability_mode) = treasury::max_redeemable_f_coin(
      treasury, 
      base_price, 
      self.stability_collateral_ratio
    ); 

    let (_, max_base_out_before_rebalance_mode) = treasury::max_redeemable_f_coin(
      treasury, 
      base_price, 
      self.rebalance_collateral_ratio
    );     

    let base_out = treasury::redeem(
      treasury,
      f_coin_in,
      coin::zero(ctx),
      c,
      base_price,
      ctx
    );

    if (max_base_out_before_rebalance_mode != 0) 
      coin::join(&mut base_out, treasury::take_bonus(
        treasury, 
        min(max_base_out_before_rebalance_mode, coin::value(&base_out)), 
        ctx
      ));

    treasury::add_fee(treasury, redeem_fee(
      self.f_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(coin::value(&base_out) >= min_base_amount, EInvalidBaseCoinAmountOut);

    base_out
  }

  public fun redeem_x_coin(
    self: &Vault,
    treasury: &mut Treasury,
    c: &Clock,
    x_coin_in: Coin<X_SUI>,
    oracle_price: Price,
    min_base_amount: u64,
    ctx: &mut TxContext        
  ): Coin<I_SUI> {
    let x_coin_in_value = coin::value(&x_coin_in);
    assert!(x_coin_in_value != 0, EZeroXCoinIsNotAllowed);   

    let base_price = destroy_price(self, oracle_price);

    let (_, max_base_out_before_stability_mode) = treasury::max_redeemable_x_coin(
      treasury, 
      base_price, 
      self.stability_collateral_ratio
    );

    let (_, max_base_out_before_rebalance_mode) = treasury::max_redeemable_x_coin(
      treasury, 
      base_price, 
      self.rebalance_collateral_ratio
    );

    assert!(max_base_out_before_rebalance_mode == 0, ECannotRedeemXCoinOnRebalanceMode);

    let base_out = treasury::redeem(
      treasury,
      coin::zero(ctx),
      x_coin_in,
      c,
      base_price,
      ctx
    );

    treasury::add_fee(treasury, redeem_fee(
      self.f_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(coin::value(&base_out) >= min_base_amount, EInvalidBaseCoinAmountOut);

    base_out
  }

  // === Public-View Functions ===

  public fun oracle_id() {
    
  }

  // === Public-Friend Functions ===

  public(friend) fun set_oracle_id(self: &mut Vault, oracle_id_address: address) {
    self.oracle_id_address = oracle_id_address;
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
    let (oracle_id, scaled_price, decimals, _) = oracle::destroy_price(oracle_price);
    assert!(self.oracle_id_address == object::id_to_address(&oracle_id), EInvalidOracle);

    if (decimals >= PRECISION_DECIMALS) {
      let factor = pow(10, decimals - PRECISION_DECIMALS);
      (scaled_price / (factor as u256) as u64)
    } else {
      let factor = pow(10, PRECISION_DECIMALS - decimals);
      ((scaled_price * (factor as u256)) as u64)
    }
  }

  fun mint_fee(
    fees: Fees,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = coin::value(base_in);
    let fees_in = coin::zero<I_SUI>(ctx);

    // charge normal fees
    if (max_base_in_before_stability_mode >= base_in_value) {
      let fee_amount = compute_fee(base_in_value, fees.standard_mint);
      coin::join(&mut fees_in, coin::split(base_in, fee_amount, ctx));
    } else {
      let standard_fee_amount = compute_fee(max_base_in_before_stability_mode, fees.standard_mint);
      let stability_fee_amount = compute_fee(base_in_value - max_base_in_before_stability_mode,fees.stability_mint);
      coin::join(&mut fees_in, coin::split(base_in, standard_fee_amount + stability_fee_amount, ctx)); 
    };

    fees_in
  }

  fun redeem_fee(
    fees: Fees,
    base_out: &mut Coin<I_SUI>, 
    max_base_out_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_out_value = coin::value(base_out);
    let fees_in = coin::zero(ctx);

    // charge high fees
    if (max_base_out_before_stability_mode >= base_out_value) {
      let fee_amount = compute_fee(base_out_value, fees.stability_redeem);
      coin::join(&mut fees_in, coin::split(base_out, fee_amount, ctx));
    } else {
      let stability_fee_amount = compute_fee(max_base_out_before_stability_mode, fees.stability_redeem);
      let standard_fee_amount = compute_fee(base_out_value - max_base_out_before_stability_mode,fees.standard_redeem);
      coin::join(&mut fees_in, coin::split(base_out, standard_fee_amount + stability_fee_amount, ctx)); 
    };

    fees_in
  }  

  fun compute_fee(value: u64, fee: u64): u64 {
    mul_div_up(value, fee, PRECISION)
  }

  // === Test Functions ===  
}