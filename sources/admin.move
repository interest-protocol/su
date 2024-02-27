module su::admin {
  // === Imports ===

  use sui::coin::Coin;
  use sui::object::ID;
  use sui::transfer::transfer;
  use sui::object::{Self, UID};
  use sui::tx_context::{sender, TxContext};

  use su::i_sui::I_SUI;
  use su::vault::{Self, Vault};
  use su::treasury::{Self, Treasury};

  // === Structs ===

  struct Admin has key, store {
    id: UID
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use)]
  fun init(ctx: &mut TxContext) {
    transfer(Admin { id: object::new(ctx) }, sender(ctx));  
  }  

  public fun remove_fee(_self: &Admin, treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<I_SUI> {
    treasury::remove_admin_fee(treasury, amount, ctx)
  }

  public fun set_bonus_rate(_self: &Admin, treasury: &mut Treasury, bonus_rate: u64) {
    treasury::set_bonus_rate(treasury,bonus_rate);
  }  

  public fun set_treasury_fees(_self: &Admin, treasury: &mut Treasury, rebalance_fee: u64, reserve_fee: u64) {
    treasury::set_fees(treasury, rebalance_fee, reserve_fee);
  }

  public fun set_oracle_id(_self: &Admin, vault: &mut Vault, oracle_id: ID) {
    vault::set_oracle_id(vault, oracle_id);
  }  

  public fun set_f_fees(
    _self: &Admin, 
    vault: &mut Vault,    
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  ) {
    vault::set_fees(vault, false, standard_mint, standard_redeem, stability_mint, stability_redeem);
  }

  public fun set_x_fees(
    _self: &Admin, 
    vault: &mut Vault,    
    standard_mint: u64,
    standard_redeem: u64,
    stability_mint: u64,
    stability_redeem: u64
  ) {
    vault::set_fees(vault, true, standard_mint, standard_redeem, stability_mint, stability_redeem);
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
    vault::set_rebalance_collateral_ratio(vault, rebalance_collateral_ratio);
  }   

  // === Test Functions ===  

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}