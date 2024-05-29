module su::vault {
  // === Imports ===

  use sui::math::pow;
  use sui::clock::Clock;
  use sui::transfer::share_object;
  use sui::coin::{Self, Coin, TreasuryCap};

  use suitears::int::Int;
  use suitears::oracle::{Self, Price};
  use suitears::math64::{min, mul_div_up};
  
  use su::cast;
  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::sui_dollar::SUI_DOLLAR;
  use su::treasury::{share_genesis_state as share_genesis_state_impl, Treasury};

  // Method Aliases

  use fun cast::to_u64 as u256.to_u64;
  use fun cast::to_u256 as u64.to_u256;  

  // === Errors ===

  const EInvalidOracle: u64 = 0;
  const EZeroBaseInIsNotAllowed: u64 = 1;
  const ETreasuryMustBeEmpty: u64 = 2;
  const EInvalidDCoinAmountOut: u64 = 3;
  const EInvalidFCoinAmountOut: u64 = 4;
  const EInvalidXCoinAmountOut: u64 = 5;
  const ECannotMintDCoinInLiquidationMode: u64 = 6;
  const ECannotMintFCoinInLiquidationMode: u64 = 7;
  const EStabilityCollateralRatioIsTooLow: u64 = 8;
  const ERebalanceCollateralRatioIsTooHigh: u64 = 9;
  const EZeroFCoinIsNotAllowed: u64 = 10;
  const EZeroXCoinIsNotAllowed: u64 = 11;
  const ECannotRedeemXCoinOnRebalanceMode: u64 = 12;
  const EInvalidBaseCoinAmountOut: u64 = 13;

  // === Constants ===

  const PRECISION: u64 = 1_000_000_000;
  const PRECISION_DECIMALS: u8 = 9;

  // Mint Options
  const MINT_D_COIN: u8 = 0;
  const MINT_F_COIN: u8 = 1;
  const MINT_X_COIN: u8 = 2;
  const MINT_ALL: u8 = 3;

  // === Structs ===

  public struct Vault has key {
    id: UID,
    oracle_id_address: address,
    d_fees: Fees,
    x_fees: Fees,
    f_fees: Fees,
    last_price: u64,
    stability_collateral_ratio: u64,
    rebalance_collateral_ratio: u64
  }

  public struct Fees has store, copy, drop {
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  }

  // === Public-Mutative Functions ===

  public fun share_genesis_state(
    d_treasury_cap: TreasuryCap<SUI_DOLLAR>,
    f_treasury_cap: TreasuryCap<F_SUI>,
    x_treasury_cap: TreasuryCap<X_SUI>,
    c: &Clock,
    genesis_price: Price,
    base_balance_cap: u64,
    ctx: &mut TxContext
  ) { 
    let (oracle_id, scaled_price, decimals, _) = oracle::destroy_price(genesis_price);

    let price = normalize_price(scaled_price, decimals);

    share_genesis_state_impl(
      d_treasury_cap,
      f_treasury_cap, 
      x_treasury_cap, 
      c, 
      price, 
      base_balance_cap, 
      ctx
    );

    let beta_fees = Fees {
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
      d_fees: beta_fees,
      f_fees: beta_fees,
      x_fees,
      last_price: price,
      oracle_id_address: object::id_to_address(&oracle_id),
      stability_collateral_ratio: 2 * PRECISION, // 200% CR
      rebalance_collateral_ratio: 18 * PRECISION / 10, // 180 CR %
    };

    share_object(vault);
  }

  public fun mint_both(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_d_coin_amount: u64,
    min_f_coin_amount: u64,
    min_x_coin_amount: u64,
    ctx: &mut TxContext
  ): (Coin<SUI_DOLLAR>, Coin<F_SUI>, Coin<X_SUI>) {
    assert!(base_in.value() != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);

    assert!(treasury.base_balance() == 0, ETreasuryMustBeEmpty);

    let (d_coin, f_coin, x_coin) = treasury.mint(base_in, c, base_price, MINT_ALL, ctx);

    assert!(d_coin.value() >= min_d_coin_amount, EInvalidDCoinAmountOut);
    assert!(f_coin.value() >= min_f_coin_amount, EInvalidFCoinAmountOut);
    assert!(x_coin.value() >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (d_coin, f_coin, x_coin)
  }

  public fun mint_d_coin(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    mut base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_f_coin_amount: u64,
    ctx: &mut TxContext    
  ): Coin<SUI_DOLLAR> {
    let base_in_value = base_in.value();
    assert!(base_in_value != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);

    let (max_base_in_before_stability_mode, _) = treasury.max_mintable_d_coin(
      base_price, 
      self.stability_collateral_ratio
    );

    let (max_base_in_before_rebalance_mode, _) = treasury.max_mintable_d_coin(
      base_price, 
      self.rebalance_collateral_ratio
    );

    assert!(max_base_in_before_rebalance_mode != 0 || max_base_in_before_rebalance_mode > base_in_value, ECannotMintDCoinInLiquidationMode);

    treasury.add_fee(mint_beta_coin_fee(
      self.d_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode,
      ctx
    ));

    let (d_coin, f_coin, x_coin) = treasury.mint(base_in, c, base_price, MINT_D_COIN, ctx);

    f_coin.destroy_zero();
    x_coin.destroy_zero();

    assert!(d_coin.value() >= min_f_coin_amount, EInvalidDCoinAmountOut);

    d_coin
  }

  public fun mint_f_coin(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    mut base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_f_coin_amount: u64,
    ctx: &mut TxContext    
  ): Coin<F_SUI> {
    let base_in_value = base_in.value();
    assert!(base_in_value != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);

    let (max_base_in_before_stability_mode, _) = treasury.max_mintable_f_coin(
      base_price, 
      self.stability_collateral_ratio
    );

    let (max_base_in_before_rebalance_mode, _) = treasury.max_mintable_f_coin(
      base_price, 
      self.rebalance_collateral_ratio
    );

    assert!(max_base_in_before_rebalance_mode != 0 || max_base_in_before_rebalance_mode > base_in_value, ECannotMintFCoinInLiquidationMode);

    treasury.add_fee(mint_beta_coin_fee(
      self.f_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode,
      ctx
    ));

    let (d_coin, f_coin, x_coin) = treasury.mint(base_in, c, base_price, MINT_F_COIN, ctx);

    d_coin.destroy_zero();
    x_coin.destroy_zero();

    assert!(f_coin.value() >= min_f_coin_amount, EInvalidFCoinAmountOut);

    f_coin
  }

  public fun mint_x_coin(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    mut base_in: Coin<I_SUI>,
    oracle_price: Price,
    min_x_coin_amount: u64,
    ctx: &mut TxContext     
  ): (Coin<X_SUI>, Coin<I_SUI>) {
    let base_in_value = coin::value(&base_in);
    assert!(base_in_value != 0, EZeroBaseInIsNotAllowed);

    let base_price = destroy_price(self, oracle_price);    

    let (max_base_in_before_stability_mode, _) = treasury.max_mintable_x_coin(
      base_price, 
      self.stability_collateral_ratio
    );

    let (max_base_in_before_rebalance_mode, _) = treasury.max_mintable_x_coin(
      base_price, 
      self.rebalance_collateral_ratio
    );

    treasury.add_fee(mint_x_coin_fee(
      self.x_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode, 
      ctx
    ));

    let (d_coin, f_coin, x_coin) = treasury.mint(base_in, c, base_price, MINT_X_COIN, ctx);

    d_coin.destroy_zero();
    f_coin.destroy_zero();

    let bonus_coin = if (max_base_in_before_rebalance_mode != 0) {
      treasury.take_bonus(min(max_base_in_before_rebalance_mode, base_in_value), ctx)
    } else coin::zero(ctx);

    assert!(x_coin.value() >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (x_coin, bonus_coin)
  }

  public fun redeem_d_coin(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    d_coin_in: Coin<SUI_DOLLAR>,
    oracle_price: Price,
    min_base_amount: u64,
    ctx: &mut TxContext        
  ): Coin<I_SUI> {
    assert!(d_coin_in.value() != 0, EZeroFCoinIsNotAllowed);   

    let base_price = destroy_price(self, oracle_price);

    let (_, max_base_out_before_stability_mode) = treasury.max_redeemable_d_coin(
      base_price, 
      self.stability_collateral_ratio
    ); 

    let (_, max_base_out_before_rebalance_mode) = treasury.max_redeemable_d_coin(
      base_price, 
      self.rebalance_collateral_ratio
    );     

    let mut base_out = treasury.redeem(
      d_coin_in,
      coin::zero(ctx),
      coin::zero(ctx),
      c,
      base_price,
      ctx
    );

    if (max_base_out_before_rebalance_mode != 0) {
      let bonus_coin = treasury.take_bonus(
        min(max_base_out_before_rebalance_mode, base_out.value()), 
        ctx
      );

       base_out.join(bonus_coin);
    };

    treasury.add_fee(redeem_beta_coin_fee(
      self.d_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(base_out.value() >= min_base_amount, EInvalidBaseCoinAmountOut);

    base_out
  }

  public fun redeem_f_coin(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    f_coin_in: Coin<F_SUI>,
    oracle_price: Price,
    min_base_amount: u64,
    ctx: &mut TxContext        
  ): Coin<I_SUI> {
    assert!(f_coin_in.value() != 0, EZeroFCoinIsNotAllowed);   

    let base_price = destroy_price(self, oracle_price);

    let (_, max_base_out_before_stability_mode) = treasury.max_redeemable_f_coin(
      base_price, 
      self.stability_collateral_ratio
    ); 

    let (_, max_base_out_before_rebalance_mode) = treasury.max_redeemable_f_coin(
      base_price, 
      self.rebalance_collateral_ratio
    );     

    let mut base_out = treasury.redeem(
      coin::zero(ctx),
      f_coin_in,
      coin::zero(ctx),
      c,
      base_price,
      ctx
    );

    if (max_base_out_before_rebalance_mode != 0) {
      let bonus_coin = treasury.take_bonus(
        min(max_base_out_before_rebalance_mode, base_out.value()), 
        ctx
      );

       base_out.join(bonus_coin);
    };

    treasury.add_fee(redeem_beta_coin_fee(
      self.f_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(base_out.value() >= min_base_amount, EInvalidBaseCoinAmountOut);

    base_out
  }

  public fun redeem_x_coin(
    self: &mut Vault,
    treasury: &mut Treasury,
    c: &Clock,
    x_coin_in: Coin<X_SUI>,
    oracle_price: Price,
    min_base_amount: u64,
    ctx: &mut TxContext        
  ): Coin<I_SUI> {
    assert!(x_coin_in.value() != 0, EZeroXCoinIsNotAllowed);   

    let base_price = destroy_price(self, oracle_price);

    let (_, max_base_out_before_stability_mode) = treasury.max_redeemable_x_coin(
      base_price, 
      self.stability_collateral_ratio
    );

    let (_, max_base_out_before_rebalance_mode) = treasury.max_redeemable_x_coin(
      base_price, 
      self.rebalance_collateral_ratio
    );

    assert!(max_base_out_before_rebalance_mode != 0, ECannotRedeemXCoinOnRebalanceMode);

    let mut base_out = treasury.redeem(
      coin::zero(ctx),
      coin::zero(ctx),
      x_coin_in,
      c,
      base_price,
      ctx
    );

    treasury.add_fee(redeem_x_coin_fee(
      self.x_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(base_out.value() >= min_base_amount, EInvalidBaseCoinAmountOut);

    base_out
  }

  // === Public-View Functions ===

  public fun oracle_id_address(self: &Vault): address {
    self.oracle_id_address
  }

  public fun d_standard_mint_fee(self: &Vault): u64 {
    self.d_fees.standard_mint
  }

  public fun d_stability_mint_fee(self: &Vault): u64 {
    self.d_fees.stability_mint
  }

  public fun d_standard_redeem_fee(self: &Vault): u64 {
    self.d_fees.standard_redeem
  }

  public fun d_stability_redeem_fee(self: &Vault): u64 {
    self.d_fees.stability_redeem
  }  

  public fun f_standard_mint_fee(self: &Vault): u64 {
    self.f_fees.standard_mint
  }

  public fun f_stability_mint_fee(self: &Vault): u64 {
    self.f_fees.stability_mint
  }

  public fun f_standard_redeem_fee(self: &Vault): u64 {
    self.f_fees.standard_redeem
  }

  public fun f_stability_redeem_fee(self: &Vault): u64 {
    self.f_fees.stability_redeem
  }  

  public fun x_standard_mint_fee(self: &Vault): u64 {
    self.x_fees.standard_mint
  }

  public fun x_stability_mint_fee(self: &Vault): u64 {
    self.x_fees.stability_mint
  }

  public fun x_standard_redeem_fee(self: &Vault): u64 {
    self.x_fees.standard_redeem
  }

  public fun x_stability_redeem_fee(self: &Vault): u64 {
    self.x_fees.stability_redeem
  }  

  public fun stability_collateral_ratio(self: &Vault): u64 {
    self.stability_collateral_ratio
  }  

  public fun rebalance_collateral_ratio(self: &Vault): u64 {
    self.rebalance_collateral_ratio
  }    

  public fun reserve_fee(treasury: &mut Treasury): u64 {
    treasury.reserve_fee()
  }

  public fun rebalance_fee(treasury: &mut Treasury): u64 {
    treasury.rebalance_fee()
  }  

  public fun genesis_price(treasury: &mut Treasury): u64 {
    treasury.genesis_price()
  }  

  public fun base_balance_cap(treasury: &mut Treasury): u64 {
    treasury.base_balance_cap()
  }    

  public fun base_balance(treasury: &mut Treasury): u64 {
    treasury.base_balance()
  }    

  public fun reserve_balance(treasury: &mut Treasury): u64 {
    treasury.reserve_balance()
  }   

  public fun rebalance_balance(treasury: &mut Treasury): u64 {
    treasury.rebalance_balance()
  }   

  public fun max_redeemable_d_coin_for_rebalance_mode(
    self: &Vault,
    treasury: &mut Treasury,
    base_price: u64    
  ): (u64, u64) {
    treasury.max_redeemable_d_coin(
      base_price, 
      self.rebalance_collateral_ratio
    ) 
  }  

  public fun max_redeemable_f_coin_for_rebalance_mode(
    self: &Vault,
    treasury: &mut Treasury,
    base_price: u64    
  ): (u64, u64) {
    treasury.max_redeemable_f_coin(
      base_price, 
      self.rebalance_collateral_ratio
    ) 
  }  

  public fun last_collateral_ratio(self: &Vault, treasury: &mut Treasury): u64 {
   treasury.collateral_ratio(self.last_price)
  }  

  public fun base_supply(treasury: &mut Treasury): u64 {
    treasury.base_supply()
  }  

  public fun last_base_nav(self: &Vault, treasury: &mut Treasury): u64 {
    treasury.base_nav(self.last_price)
  }  

  public fun last_f_multiple(self: &Vault, treasury: &mut Treasury): Int {
    treasury.f_multiple(self.last_price)
  }

  public fun d_supply(treasury: &mut Treasury): u64 {
    treasury.d_supply()
  }

  public fun f_supply(treasury: &mut Treasury): u64 {
    treasury.f_supply()
  }

  public fun last_f_nav(self: &Vault, treasury: &mut Treasury): u64 {
    treasury.f_nav(self.last_price)
  }

  public fun x_supply(treasury: &mut Treasury): u64 {
    treasury.x_supply()
  }

  public fun last_x_nav(self: &Vault, treasury: &mut Treasury): u64 {
    treasury.x_nav(self.last_price)
  }

  public fun leverage_ratio(treasury: &mut Treasury, c: &Clock): u64 {
    treasury.leverage_ratio(c)
  } 

  public fun price(oracle_price: &Price): u64 {
    let scaled_price = oracle::price(oracle_price);
    let decimals = oracle::decimals(oracle_price);

    normalize_price(scaled_price, decimals)
  }

  public fun last_price(self: &Vault): u64 {
    self.last_price
  }

  // === Public-Friend Functions ===

  public(package) fun set_oracle_id_address(self: &mut Vault, oracle_id_address: address) {
    self.oracle_id_address = oracle_id_address;
  }

  public(package) fun set_fees(
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

  public(package) fun set_stability_collateral_ratio(
    self: &mut Vault,
    stability_collateral_ratio: u64
  ) {
    assert!(stability_collateral_ratio > self.rebalance_collateral_ratio, EStabilityCollateralRatioIsTooLow);
    self.stability_collateral_ratio = stability_collateral_ratio;
  }  

  public(package) fun set_rebalance_collateral_ratio(
    self: &mut Vault,
    rebalance_collateral_ratio: u64
  ) {
    assert!(self.stability_collateral_ratio > rebalance_collateral_ratio, ERebalanceCollateralRatioIsTooHigh);
    self.rebalance_collateral_ratio = rebalance_collateral_ratio;
  }    

  // === Private Functions ===

  fun destroy_price(self: &mut Vault, oracle_price: Price): u64 {
    let (oracle_id, scaled_price, decimals, _) = oracle::destroy_price(oracle_price);
    assert!(self.oracle_id_address == object::id_to_address(&oracle_id), EInvalidOracle);

    let price = normalize_price(scaled_price, decimals);

    self.last_price = price;

    price
  }

  fun normalize_price(scaled_price: u256, decimals: u8): u64 {
    if (decimals >= PRECISION_DECIMALS) {
      let factor = pow(10, decimals - PRECISION_DECIMALS);
      (scaled_price / factor.to_u256()).to_u64()
    } else {
      let factor = pow(10, PRECISION_DECIMALS - decimals);
      (scaled_price * factor.to_u256()).to_u64()
    }    
  }

  fun mint_beta_coin_fee(
    fees: Fees,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = base_in.value();
    let mut fees_in = coin::zero<I_SUI>(ctx);

    // charge high fees - we r below the stability mode
    let fee_amount = if (max_base_in_before_stability_mode == 0)
      compute_fee(base_in_value,fees.stability_mint)
    else {
      let standard_fee_amount = compute_fee(min(max_base_in_before_stability_mode, base_in_value),fees.standard_mint);

      let stability_fee_amount = if (base_in_value >= max_base_in_before_stability_mode) 
        compute_fee(base_in_value - max_base_in_before_stability_mode,fees.stability_mint)
      else 
        0;

      stability_fee_amount + standard_fee_amount
    };

    fees_in.join(base_in.split(fee_amount, ctx));

    fees_in
  }

  fun mint_x_coin_fee(
    fees: Fees,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = base_in.value();
    let mut fees_in = coin::zero<I_SUI>(ctx);

    // charge normal fees
    let fee_amount = if (max_base_in_before_stability_mode == 0) {
      compute_fee(base_in_value, fees.standard_mint)
    } else if (max_base_in_before_stability_mode >= base_in_value) {
      compute_fee(base_in_value,fees.stability_mint)
    } else {
      let standard_fee_amount = compute_fee(base_in_value - max_base_in_before_stability_mode,fees.standard_mint);
      let stability_fee_amount = compute_fee(max_base_in_before_stability_mode,fees.stability_mint);   
      stability_fee_amount + standard_fee_amount
    };

    fees_in.join(base_in.split(fee_amount, ctx));

    fees_in
  }

  fun redeem_beta_coin_fee(
    fees: Fees,
    base_out: &mut Coin<I_SUI>, 
    max_base_out_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_out_value = base_out.value();
    let mut fees_in = coin::zero(ctx);

    // charge high fees
    let fee_amount = if (max_base_out_before_stability_mode == 0) {
      compute_fee(base_out_value, fees.standard_redeem)
    } else if (max_base_out_before_stability_mode >= base_out_value) {
      compute_fee(base_out_value, fees.stability_redeem)
    } else {
      let stability_fee_amount = compute_fee(max_base_out_before_stability_mode, fees.stability_redeem);
      let standard_fee_amount = compute_fee(base_out_value - max_base_out_before_stability_mode,fees.standard_redeem);

      stability_fee_amount + standard_fee_amount
    };

    fees_in.join(base_out.split(fee_amount, ctx));

    fees_in
  }  

  fun redeem_x_coin_fee(
    fees: Fees,
    base_out: &mut Coin<I_SUI>, 
    max_base_out_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_out_value = base_out.value();
    let mut fees_in = coin::zero(ctx);

    // charge high fees
    let fee_amount = if (max_base_out_before_stability_mode == 0) {
      compute_fee(base_out_value, fees.stability_redeem)
    } else if (max_base_out_before_stability_mode >= base_out_value) {
      compute_fee(base_out_value, fees.standard_redeem)
    } else {
      let standard_fee_amount = compute_fee(max_base_out_before_stability_mode, fees.standard_redeem);
      let stability_fee_amount = compute_fee(base_out_value - max_base_out_before_stability_mode,fees.stability_redeem);

      stability_fee_amount + standard_fee_amount
    };

    fees_in.join(base_out.split(fee_amount, ctx));

    fees_in
  }    

  fun compute_fee(value: u64, fee: u64): u64 {
    mul_div_up(value, fee, PRECISION)
  }

  // === Test Functions ===  
}