module su::rebalance_f_pool {
  // === Imports ===

  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::vec_set::{Self, VecSet};
  use sui::vec_map::{Self, VecMap};

  // === Friends ===

  // === Errors ===

  // === Constants ===

  // === Structs ===

  struct RebalancePool has key {
    id: UID,
    epoch: Epoch,
    unlock_duration: u64,
    base_reward: TypeName,
    extra_rewards: VecSet<TypeName>,
    rewards: VecMap<TypeName, Rewards>
  }

  struct Epoch has store {
    epoch: u64,
    prod: u256,
  }

  struct Rewards has store {
    rate: u256,
    period: u64,
    queued: u256,
    last_update: u64,
    finished_at: u64,
  }

  struct Account has key, store {
    id: UID,
    epoch: Epoch,
    addr: address, 
    unlock_at: u64,
    unlock_amount: u64,
    initial_deposit: u64,
    extra_rewards: VecMap<TypeName, Snapshot>
  }

  struct Snapshot has store {
    pending: u64,
    accumulated_rewards_per_stake: u256
  }

  // === Public-Mutative Functions ===

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===

  // === Test Functions ===

  // Total deposit in the pool by a user
  public fun balance_of(account: address): u64 {
    0
  }

  // Total unlocked balance in the pool by a user
  public fun unlocked_balance_of(account: address): u64 {
    0
  }

  // Total unlocked balance in the pool by a user
  public fun unlocking_balance_of(account: address): (u64, u64) {
    (0, 0)
  }

  // Total deposit in the pool
  public fun total_supply(): u64 {
    0
  }

  // Current amount of claimable rewards
  public fun claimable(): u64 {
    0
  }
}