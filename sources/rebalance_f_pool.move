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

  use suitears::math64;

  // === Friends ===

  friend su::admin;

  // === Errors ===

  const EZeroDeposit: u64 = 0;
  const EWaitUntilRewardsEnd: u64 = 1;

  // === Constants ===

  const PRECISION: u64 = 1_000_000_000;

  // === Structs ===

  struct RebalancePool has key {
    id: UID,
    start: u64,
    last_update: u64,
    f_balance: Balance<F_SUI>,
    base_balance: Balance<I_SUI>,
    epochs: TableVec<EpochSnapshot>,
    rewards: VecSet<TypeName>,
    rewards_balances: Bag,
    rewards_map: Table<TypeName, PoolReward>,
  }

  struct PoolReward has store, copy, drop {
    end: u64,
    rewards_per_second: u64,
    accrued_rewards_per_share: u256
  }

  struct EpochSnapshot has store, copy, drop {
    initial_f_balance: u64,
    final_f_balance: u64,
    base_balance: u64,
    accrued_rewards_per_share_map: VecMap<TypeName, u256>,
  }

  struct Account has key, store {
    id: UID,
    id_address: address, 
    epoch: u64,
    initial_f_balance: u64,
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
      f_balance: balance::zero(),
      base_balance: balance::zero(),
      epochs: table_vec::empty(ctx),
      rewards: vec_set::empty(),
      rewards_map: table::new(ctx),
      rewards_balances: bag::new(ctx)
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
      rewards_map: vec_map::empty()
    }
  }

  public fun deposit(
    self: &mut RebalancePool, 
    clock: &Clock,
    account: &mut Account, 
    f_coin_in: Coin<F_SUI>, 
    ctx: &mut TxContext
  ) {
    let f_coin_in_value = coin::value(&f_coin_in);
    assert!(f_coin_in_value != 0, EZeroDeposit);

    update_rewards(self, clock);
    settle_account(self, clock, account);

    // WIP
    abort 0
  }

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  public(friend) fun new_reward<CoinType: drop>(self: &mut RebalancePool) {
    let key = type_name::get<CoinType>();

    bag::add(&mut self.rewards_balances, key, balance::zero<CoinType>());
    table::add(&mut self.rewards_map, key, PoolReward{ end: 0, rewards_per_second: 0, accrued_rewards_per_share: 0 });
  }

  public(friend) fun add_rewards<CoinType: drop>(
    self: &mut RebalancePool, 
    clock: &Clock, 
    coin_in: Coin<CoinType>,
    end: u64,
  ) {
    let current_time = clock_timestamp_s(clock);

    update_rewards(self,clock);

    let key = type_name::get<CoinType>();

    let pool_rewards = table::borrow_mut(&mut self.rewards_map, key);

    assert!(end > pool_rewards.end, EWaitUntilRewardsEnd);

    pool_rewards.end = end;
    pool_rewards.rewards_per_second = math64::div_down(
      balance::join(bag::borrow_mut(&mut self.rewards_balances, key), 
      coin::into_balance(coin_in)
    ), end - current_time);
  }

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

  fun update_rewards(self: &mut RebalancePool, clock: &Clock) {
    let current_time = clock_timestamp_s(clock);

    let time_elapsed = current_time - self.last_update;

    if (time_elapsed == 0 || self.start == 0) return;

    let f_balance_value = balance::value(&self.f_balance);

    self.last_update = current_time;

    if (f_balance_value == 0) return;

    let index = 0;
    let extra_rewards_length = vec_set::size(&self.rewards);

    let reward_type_names = vec_set::keys(&self.rewards);

    while (extra_rewards_length > index) {
      
      let key = *vector::borrow(reward_type_names, index);

      let reward = table::borrow_mut(&mut self.rewards_map, key);

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