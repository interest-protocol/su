module su::vault {
  // === Imports ===
  
  use sui::clock::Clock;
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::object::{Self, UID, ID};
  use sui::coin::{Self, Coin, TreasuryCap};

  use su::f_sui::F_SUI;
  use su::x_sui::X_SUI;
  use su::i_sui::I_SUI;
  use su::treasury::{Self, Treasury};
  use su::treasury_cap_map::TreasuryCapMap;

  use suitears::oracle::{Self, Price};

  // === Errors ===

  const EInvalidOracle: u64 = 0;
  const EZeroBaseInIsNotAllowed: u64 = 1;
  const ETreasuryMustBeEmpty: u64 = 2;
  const EInvalidFCoinAmountOut: u64 = 3;
  const EInvalidXCoinAmountOut: u64 = 4;

  // === Constants ===

  const PRECISION: u64 = 1_000_000_000;

  // Mint Options
  const MINT_F_COIN: u8 = 0;
  const MINT_X_COIN: u8 = 1;
  const MINT_BOTH: u8 = 2;

  // === Structs ===

  struct Vault has key {
    id: UID,
    oracle_id: ID
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

    let vault = Vault {
      id: object::new(ctx),
      oracle_id
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

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===

  fun destroy_price(self: &Vault, oracle_price: Price): u64 {
    let (oracle_id, scaled_price, _, _) = oracle::destroy_price(oracle_price);
    assert!(self.oracle_id == oracle_id, EInvalidOracle);

    (scaled_price / (PRECISION as u256) as u64)
  }

  // === Test Functions ===  
}