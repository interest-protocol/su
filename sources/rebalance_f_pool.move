/*
* @dev All timestamps are in seconds.
*/
module su::rebalance_f_pool {
  // === Imports ===

  use std::vector;
  use std::type_name::{Self, TypeName};

  use sui::bag::{Self, Bag};
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::vec_set::{Self, VecSet};
  use sui::vec_map::{Self, VecMap};
  use sui::balance::{Self, Balance};
  use sui::table_vec::{Self, TableVec};

  use su::f_sui::F_SUI;
  use su::i_sui::I_SUI;
  use su::treasury::{Self, Treasury};

  use suitears::math64;

  // === Friends ===

  // === Errors ===

  const EZeroDeposit: u64 = 0;

  // === Constants ===

  const PRECISION: u64 = 1_000_000_000;

  // === Structs ===

  struct RebalancePool has key {
    id: UID,
    start: u64,
    last_update: u64,
    f_balance: Balance<F_SUI>,
    extra_rewards_balances: Bag,
    base_balance: Balance<I_SUI>,
    reward_balance: Balance<I_SUI>,
    accrued_rewards_per_share: u256,
    extra_rewards: VecSet<TypeName>,
    epochs: TableVec<EpochSnapshot>,
    extra_rewards_map: Table<TypeName, PoolReward>,
  }

  struct PoolReward has store, copy, drop {
    end: u64,
    balance: u64,
    rewards_per_second: u64,
    accrued_rewards_per_share: u256
  }

  struct EpochSnapshot has store, copy, drop {
    initial_f_balance: u64,
    final_f_balance: u64,
    base_balance: u64,
    based_accrued_rewards_per_share: u256,
    accrued_rewards_per_share_map: VecMap<TypeName, u256>,
  }

  struct Account has key, store {
    id: UID,
    id_address: address, 
    epoch: u64,
    initial_f_balance: u64,
    base_rewards: AccountReward,
    rewards_map: VecMap<TypeName, AccountReward>,
  }

  struct AccountReward has store {
    debt: u256,
    amount: u64
  }

  // === Public-Mutative Functions ===

  #[allow(unused_function)]
  fun init(ctx: &mut TxContext) {
    let rebalance_pool = RebalancePool {
      id: object::new(ctx),
      start: 0,
      last_update: 0,
      accrued_rewards_per_share: 0,
      f_balance: balance::zero(),
      base_balance: balance::zero(),
      reward_balance: balance::zero(),
      epochs: table_vec::empty(ctx),
      extra_rewards: vec_set::empty(),
      extra_rewards_map: table::new(ctx),
      extra_rewards_balances: bag::new(ctx)
    };

    share_object(rebalance_pool);
  }

  public fun new_account(ctx: &mut TxContext): Account {
    let id = object::new(ctx);
    let id_address = object::uid_to_address(&id);

    Account {
      id: id,
      id_address,
      epoch: 0,
      initial_f_balance: 0,
      base_rewards: AccountReward { debt: 0, amount: 0 },
      rewards_map: vec_map::empty()
    }
  }

  public fun deposit(
    self: &mut RebalancePool, 
    treasury: &mut Treasury,
    clock: &Clock,
    account: &mut Account, 
    f_coin_in: Coin<F_SUI>, 
    ctx: &mut TxContext
  ) {
    let f_coin_in_value = coin::value(&f_coin_in);
    assert!(f_coin_in_value != 0, EZeroDeposit);

    update_rewards(self, treasury, clock, account);
    settle_account(self, clock, account);

    // WIP
    abort 0
  }

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===
  
  fun settle_account(self: &mut RebalancePool, clock: &Clock, account: &mut Account) {
    let account_epoch = account.epoch;
    let last_snapshot_epoch = table_vec::length(&self.epochs);

    // Use the current values
    if (last_snapshot_epoch == account_epoch) return;

    account.epoch == last_snapshot_epoch;

    let index = account_epoch - 1;


    // Bring account up to the current value using the snapshots.
    while (last_snapshot_epoch > index) {
      
      let snapshot = table_vec::borrow(&self.epochs, index);



      index = index + 1;
    };

  }

  fun update_rewards(self: &mut RebalancePool, treasury: &mut Treasury, clock: &Clock, account: &mut Account) {
    let current_time = clock_timestamp_s(clock);

    let time_elapsed = current_time - self.last_update;

    if (time_elapsed == 0 || self.start == 0) return;

    let f_balance_value = balance::value(&self.f_balance);

    self.last_update = current_time;

    if (f_balance_value == 0) return;

    // update base reward
    let base_reward = treasury::remove_rebalance_fee(treasury);

    self.accrued_rewards_per_share = self.accrued_rewards_per_share + (math64::mul_div_down(balance::value(&base_reward), PRECISION, f_balance_value) as u256);

    balance::join(&mut self.reward_balance, base_reward);

    // update extra rewards

    let index = 0;
    let extra_rewards_length = vec_set::size(&self.extra_rewards);

    let reward_type_names = vec_set::keys(&self.extra_rewards);

    while (extra_rewards_length > index) {
      
      let key = *vector::borrow(reward_type_names, index);

      let reward = table::borrow_mut(&mut self.extra_rewards_map, key);

      if (reward.end > current_time) {
        reward.accrued_rewards_per_share = calculate_accrued_rewards_per_share(
          reward.rewards_per_second, 
          reward.accrued_rewards_per_share,
          f_balance_value,
          time_elapsed
        );
      };

      index = index + 1;
    };
  }

  fun calculate_accrued_rewards_per_share(
    rewards_per_second: u64,
    last_accrued_rewards_per_share: u256,
    total_staked_token: u64,
    timestamp_delta: u64
  ): u256 { 
    
    let (total_staked_token, rewards_per_second, stake_factor, timestamp_delta) =
     (
      (total_staked_token as u256),
      (rewards_per_second as u256),
      (PRECISION as u256),
      (timestamp_delta as u256)
     );

    last_accrued_rewards_per_share + ((rewards_per_second * timestamp_delta * stake_factor) / total_staked_token)
  }

  fun clock_timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }

  // === Test Functions ===
}