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

  use suitears::int::Int;
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
    last_price: u64,
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
    let (oracle_id, scaled_price, decimals, _) = oracle::destroy_price(genesis_price);

    let price = normalize_price(scaled_price, decimals);

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
    self: &mut Vault,
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

    treasury::add_fee(treasury, mint_f_coin_fee(
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
    self: &mut Vault,
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

    let (max_base_in_before_rebalance_mode, _) = treasury::max_mintable_x_coin(
      treasury, 
      base_price, 
      self.rebalance_collateral_ratio
    );

    treasury::add_fee(treasury, mint_x_coin_fee(
      self.x_fees, 
      &mut base_in, 
      max_base_in_before_stability_mode, 
      ctx
    ));

    let (f_coin, x_coin) = treasury::mint(treasury, base_in, c, base_price, MINT_X_COIN, ctx);

    coin::destroy_zero(f_coin);

    let bonus_coin = if (max_base_in_before_rebalance_mode != 0) {
      treasury::take_bonus(treasury, min(max_base_in_before_rebalance_mode, base_in_value), ctx)
    } else coin::zero(ctx);

    assert!(coin::value(&x_coin) >= min_x_coin_amount, EInvalidXCoinAmountOut);

    (x_coin, bonus_coin)
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

    if (max_base_out_before_rebalance_mode != 0) {
      let bonus_coin = treasury::take_bonus(
        treasury, 
        min(max_base_out_before_rebalance_mode, coin::value(&base_out)), 
        ctx
      );

       coin::join(&mut base_out, bonus_coin);
    };

    treasury::add_fee(treasury, redeem_f_coin_fee(
      self.f_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(coin::value(&base_out) >= min_base_amount, EInvalidBaseCoinAmountOut);

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

    assert!(max_base_out_before_rebalance_mode != 0, ECannotRedeemXCoinOnRebalanceMode);

    let base_out = treasury::redeem(
      treasury,
      coin::zero(ctx),
      x_coin_in,
      c,
      base_price,
      ctx
    );

    treasury::add_fee(treasury, redeem_x_coin_fee(
      self.x_fees, 
      &mut base_out, 
      max_base_out_before_stability_mode, 
      ctx
    ));

    assert!(coin::value(&base_out) >= min_base_amount, EInvalidBaseCoinAmountOut);

    base_out
  }

  // === Public-View Functions ===

  public fun oracle_id_address(self: &Vault): address {
    self.oracle_id_address
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
    treasury::reserve_fee(treasury)
  }

  public fun rebalance_fee(treasury: &mut Treasury): u64 {
    treasury::rebalance_fee(treasury)
  }  

  public fun genesis_price(treasury: &mut Treasury): u64 {
    treasury::genesis_price(treasury)
  }  

  public fun base_balance_cap(treasury: &mut Treasury): u64 {
    treasury::base_balance_cap(treasury)
  }    

  public fun base_balance(treasury: &mut Treasury): u64 {
    treasury::base_balance(treasury)
  }    

  public fun reserve_balance(treasury: &mut Treasury): u64 {
    treasury::reserve_balance(treasury)
  }   

  public fun rebalance_balance(treasury: &mut Treasury): u64 {
    treasury::rebalance_balance(treasury)
  }   

  public fun max_redeemable_f_coin_for_rebalance_mode(
    self: &Vault,
    treasury: &mut Treasury,
    base_price: u64    
  ): (u64, u64) {
    treasury::max_redeemable_f_coin(
      treasury, 
      base_price, 
      self.rebalance_collateral_ratio
    ) 
  }  

  public fun last_collateral_ratio(self: &Vault, treasury: &mut Treasury): u64 {
   treasury::collateral_ratio(treasury, self.last_price)
  }  

  public fun base_supply(treasury: &mut Treasury): u64 {
    treasury::base_supply(treasury)
  }  

  public fun last_base_nav(self: &Vault, treasury: &mut Treasury): u64 {
    treasury::base_nav(treasury, self.last_price)
  }  

  public fun last_f_multiple(self: &Vault, treasury: &mut Treasury): Int {
    treasury::f_multiple(treasury, self.last_price)
  }

  public fun f_supply(treasury: &mut Treasury): u64 {
    treasury::f_supply(treasury)
  }

  public fun last_f_nav(self: &Vault, treasury: &mut Treasury): u64 {
    treasury::f_nav(treasury, self.last_price)
  }

  public fun x_supply(treasury: &mut Treasury): u64 {
    treasury::x_supply(treasury)
  }

  public fun last_x_nav(self: &Vault, treasury: &mut Treasury): u64 {
    treasury::x_nav(treasury, self.last_price)
  }

  public fun leverage_ratio(treasury: &mut Treasury, c: &Clock): u64 {
    treasury::leverage_ratio(treasury, c)
  } 

  public fun price(oracle_price: &Price): u64 {
    let scaled_price = oracle::price(oracle_price);
    let decimals = oracle::decimals(oracle_price);

    normalize_price(scaled_price, decimals)
  }

  public fun last_price(self: &Vault): u64 {
    self.last_price
  }

  public fun quote_base_nav(treasury: &mut Treasury, price: u64): u64 {
    treasury::base_nav(treasury, price)    
  }

  public fun quote_f_multiple(treasury: &mut Treasury, price: u64): Int {
    treasury::f_multiple(treasury, price)
  }  

  public fun quote_f_nav(treasury: &mut Treasury, price: u64): u64 {
    treasury::f_nav(treasury, price)
  }

  public fun quote_x_nav(treasury: &mut Treasury, price: u64): u64 {
    treasury::x_nav(treasury, price)
  }

  // === Public-Friend Functions ===

  public(friend) fun set_oracle_id_address(self: &mut Vault, oracle_id_address: address) {
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
      (scaled_price / (factor as u256) as u64)
    } else {
      let factor = pow(10, PRECISION_DECIMALS - decimals);
      ((scaled_price * (factor as u256)) as u64)
    }    
  }

  fun mint_f_coin_fee(
    fees: Fees,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = coin::value(base_in);
    let fees_in = coin::zero<I_SUI>(ctx);

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

    coin::join(&mut fees_in, coin::split(base_in, fee_amount, ctx));

    fees_in
  }

  fun mint_x_coin_fee(
    fees: Fees,
    base_in: &mut Coin<I_SUI>, 
    max_base_in_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_in_value = coin::value(base_in);
    let fees_in = coin::zero<I_SUI>(ctx);

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

    coin::join(&mut fees_in, coin::split(base_in, fee_amount, ctx));

    fees_in
  }

  fun redeem_f_coin_fee(
    fees: Fees,
    base_out: &mut Coin<I_SUI>, 
    max_base_out_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_out_value = coin::value(base_out);
    let fees_in = coin::zero(ctx);

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

    coin::join(&mut fees_in, coin::split(base_out, fee_amount, ctx));

    fees_in
  }  

  fun redeem_x_coin_fee(
    fees: Fees,
    base_out: &mut Coin<I_SUI>, 
    max_base_out_before_stability_mode: u64, 
    ctx: &mut TxContext
  ): Coin<I_SUI> {
    let base_out_value = coin::value(base_out);
    let fees_in = coin::zero(ctx);

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

    coin::join(&mut fees_in, coin::split(base_out, fee_amount, ctx));

    fees_in
  }    

  fun compute_fee(value: u64, fee: u64): u64 {
    mul_div_up(value, fee, PRECISION)
  }

  // === Test Functions ===  
}