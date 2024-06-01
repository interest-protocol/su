module su::admin {
  // === Imports ===

  use std::ascii;
  use std::string;

  use sui::coin::Coin;
  use sui::clock::Clock;
  use sui::transfer::transfer;
  use sui::coin::CoinMetadata;

  use su::i_sui::I_SUI;
  use su::vault::{Self, Vault};
  use su::treasury::{Self, Treasury};
  use su::rebalance_f_pool::{Self, RebalancePool};

  // === Constants ===

  // Fee Options
  const SUID: u8 = 0;
  const FSUI: u8 = 1;
  const XSUI: u8 = 2;

  // === Structs ===

  public struct Admin has key, store {
    id: UID
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use)]
  fun init(ctx: &mut TxContext) {
    transfer(Admin { id: object::new(ctx) }, ctx.sender());  
  }  

  public fun remove_fee(_self: &Admin, treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    treasury.remove_admin_fee(amount, ctx)
  }

  public fun set_bonus_rate(_self: &Admin, treasury: &mut Treasury, bonus_rate: u64) {
    treasury.set_bonus_rate(bonus_rate);
  }  

  public fun set_treasury_fees(_self: &Admin, treasury: &mut Treasury, rebalance_fee: u64, reserve_fee: u64) {
    treasury.set_fees(rebalance_fee, reserve_fee);
  }

  public fun set_oracle_id_address(_self: &Admin, vault: &mut Vault, oracle_id_address: address) {
    vault.set_oracle_id_address(oracle_id_address);
  }  

  public(package) fun set_base_balance_cap(_self: &Admin, treasury: &mut Treasury, new_base_balance_cap: u64) {
    treasury.set_base_balance_cap(new_base_balance_cap)
  }   

  public fun set_d_fees(
    _self: &Admin, 
    vault: &mut Vault,    
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  ) {
    vault.set_fees(SUID, standard_mint, standard_redeem, stability_mint, stability_redeem);
  }

  public fun set_f_fees(
    _self: &Admin, 
    vault: &mut Vault,    
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  ) {
    vault.set_fees(FSUI, standard_mint, standard_redeem, stability_mint, stability_redeem);
  }

  public fun set_x_fees(
    _self: &Admin, 
    vault: &mut Vault,    
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  ) {
    vault.set_fees(XSUI, standard_mint, standard_redeem, stability_mint, stability_redeem);
  }

  public fun set_stability_collateral_ratio(
    _self: &Admin, 
    vault: &mut Vault,    
    stability_collateral_ratio: u64
  ) {
    vault::set_stability_collateral_ratio(vault, stability_collateral_ratio);
  }  

  public fun set_rebalance_collateral_ratio(
    _self: &Admin, 
    vault: &mut Vault,    
    rebalance_collateral_ratio: u64
  ) {
    vault.set_rebalance_collateral_ratio(rebalance_collateral_ratio);
  }   

  public fun new_rebalance_f_pool_reward<CoinType: drop>(rebalance_pool: &mut RebalancePool) {
    rebalance_pool.new_reward<CoinType>();
  }

  public fun add_rebalance_f_pool_rewards<CoinType: drop>(
    _self: &Admin, 
    rebalance_pool: &mut RebalancePool,
    clock: &Clock,
    coin_in: Coin<CoinType>,
    end: u64
  ) {
    rebalance_f_pool::add_rewards(rebalance_pool, clock, coin_in, end);
  }  

  public fun update_name<T: drop>(
    _self: &Admin,
    treasury: &mut Treasury,
    metadata: &mut CoinMetadata<T>, 
    name: string::String
  ) {
    treasury::treasury_cap_mut<T>(treasury).update_name(metadata, name);
  }

  public fun update_symbol<T: drop>(
    _self: &Admin,
    treasury: &mut Treasury,
    metadata: &mut CoinMetadata<T>, 
    symbol: ascii::String
  ) {
    treasury::treasury_cap_mut<T>(treasury).update_symbol(metadata, symbol);
  }

  public fun update_description<T: drop>(
    _self: &Admin,
    treasury: &mut Treasury,
    metadata: &mut CoinMetadata<T>, 
    description: string::String
  ) {
    treasury::treasury_cap_mut<T>(treasury).update_description(metadata, description);
  }

  public fun update_icon_url<T: drop>(
    _self: &Admin,
    treasury: &mut Treasury,
    metadata: &mut CoinMetadata<T>, 
    url: ascii::String
  ) {
    treasury::treasury_cap_mut<T>(treasury).update_icon_url(metadata, url);
  }    

  // === Test Functions ===  

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}