module su::rebalance_f_pool {
  // === Imports ===

  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::vec_set::{Self, VecSet};
  use sui::vec_map::{Self, VecMap};
  use sui::table_vec::{Self, TableVec};

  use su::f_sui::F_SUI;
  use su::i_sui::I_SUI;

  // === Friends ===

  // === Errors ===

  // === Constants ===

  // 1 Day in Milliseconds

  const PRECISION: u64 = 1_000_000_000;

  // === Structs ===

  struct RebalancePool has key {
    id: UID,
    epochs: TableVec<EpochSnapshot>,
    reward_coins: VecSet<TypeName>,
  }

  struct EpochSnapshot has store, copy, drop {
    f_balance: u64,
    base_balance: u64,
    accrued_rewards_per_share_map: VecMap<TypeName, u256>,
  }

  struct Account has key, store {
    id: UID,
    id_address: address, 
    epoch_index: u64,
    initial_f_balance: u64,
    reward_debt: VecMap<TypeName, u256>,
  }

  // === Public-Mutative Functions ===

  #[allow(unused_function)]
  fun init(ctx: &mut TxContext) {
    let rebalance_pool = RebalancePool {
      id: object::new(ctx),
      epochs: table_vec::empty(ctx),
      reward_coins: vec_set::empty()
    };

    share_object(rebalance_pool);
  }

  public fun new_account(ctx: &mut TxContext): Account {
    let id = object::new(ctx);
    let id_address = object::uid_to_address(&id);

    Account {
      id: id,
      id_address,
      epoch_index: 0,
      initial_f_balance: 0,
      reward_debt: vec_map::empty()
    }
  }

  // === Public-View Functions ===


  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===


  // === Test Functions ===
}