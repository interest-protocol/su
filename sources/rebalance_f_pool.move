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
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::vec_set::{Self, VecSet};
  use sui::vec_map::{Self, VecMap};
  use sui::balance::{Self, Balance};
  use sui::table_vec::{Self, TableVec};

  use suitears::math64;
  use suitears::oracle::Price;
  
  use su::f_sui::F_SUI;
  use su::i_sui::I_SUI;
  use su::vault::{Self, Vault};
  use su::treasury::{Self, Treasury};

  // === Friends ===

  friend su::admin;

  // === Errors ===

  const ENoZeroCoinValue: u64 = 0;
  const EWaitUntilRewardsEnd: u64 = 1;
  const ENotEnoughFBalance: u64 = 2;
  const ENotEnoughBaseBalance: u64 = 3;
  const ENotEnoughRewardBalance: u64 = 4;
  const ECanOnlyLiquidateOnRebalanceMode: u64 = 5;

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
    rewards_map: VecMap<TypeName, PoolReward>,
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
    f_balance: u64,
    base_balance: u64,
    rewards_map: VecMap<TypeName, AccountReward>,
    rewards_last_update: u64
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
      rewards_map: vec_map::empty(),
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
      f_balance: 0,
      base_balance: 0,
      rewards_map: vec_map::empty(),
      rewards_last_update: 0
    }
  }

  public fun add_f_sui(
    self: &mut RebalancePool, 
    clock: &Clock,
    account: &mut Account, 
    f_coin_in: Coin<F_SUI>
  ) {
    let f_coin_in_value = coin::value(&f_coin_in);
    assert!(f_coin_in_value != 0, ENoZeroCoinValue);

    update_pool_rewards(self, clock);
    settle_account(self, account);

    balance::join(&mut self.f_balance, coin::into_balance(f_coin_in));

    account.f_balance = account.f_balance + f_coin_in_value;

    update_all_account_rewards(self, account);
  }

  public fun remove_f_sui(
    self: &mut RebalancePool, 
    clock: &Clock,
    account: &mut Account, 
    amount: u64, 
    ctx: &mut TxContext    
  ): Coin<F_SUI> {
    update_pool_rewards(self, clock);
    settle_account(self, account);

    let f_balance_value = account.f_balance;

    assert!(f_balance_value >= amount, ENotEnoughFBalance);    

    account.f_balance = account.f_balance - amount;

    update_all_account_rewards(self, account);

    coin::take(&mut self.f_balance, amount, ctx)
  }

  public fun remove_base(
    self: &mut RebalancePool, 
    clock: &Clock,
    account: &mut Account, 
    amount: u64, 
    ctx: &mut TxContext        
  ): Coin<I_SUI> {
    update_pool_rewards(self, clock);
    settle_account(self, account);

    let base_balance_value = account.base_balance;

    assert!(base_balance_value >= amount, ENotEnoughBaseBalance);

    account.base_balance = account.base_balance - amount;

    update_all_account_rewards(self, account);

    coin::take(&mut self.base_balance, amount, ctx)
  }

  public fun remove_reward<CoinType: drop>(
    self: &mut RebalancePool, 
    clock: &Clock,
    account: &mut Account, 
    amount: u64, 
    ctx: &mut TxContext        
  ): Coin<CoinType> {
    update_pool_rewards(self, clock);
    settle_account(self, account);
    update_all_account_rewards(self, account);

    let reward_type_name = type_name::get<CoinType>();

    let reward_account = vec_map::get_mut(&mut account.rewards_map, &reward_type_name);

    assert!(reward_account.amount >= amount, ENotEnoughRewardBalance);

    reward_account.amount = reward_account.amount - amount;

    coin::take(bag::borrow_mut(&mut self.rewards_balances, reward_type_name), amount, ctx)
  }

  public fun liquidate(
    self: &mut RebalancePool,
    vault: &Vault,
    treasury: &mut Treasury,
    c: &Clock,
    f_coin_in: Coin<F_SUI>,
    oracle_price: Price,
    min_base_amount: u64,
    ctx: &mut TxContext        
  ) {

    let (_, max_base_out_before_rebalance_mode) = vault::max_redeemable_f_coin_for_rebalance_mode(vault, treasury, oracle_price);

    abort 0
  }

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  public(friend) fun new_reward<CoinType: drop>(self: &mut RebalancePool) {
    let key = type_name::get<CoinType>();

    bag::add(&mut self.rewards_balances, key, balance::zero<CoinType>());
    vec_map::insert(&mut self.rewards_map, key, PoolReward{ end: 0, rewards_per_second: 0, accrued_rewards_per_share: 0 });
  }

  public(friend) fun add_rewards<CoinType: drop>(
    self: &mut RebalancePool, 
    clock: &Clock, 
    coin_in: Coin<CoinType>,
    end: u64,
  ) {
    let current_time = clock_timestamp_s(clock);

    update_pool_rewards(self,clock);

    let key = type_name::get<CoinType>();

    let pool_rewards = vec_map::get_mut(&mut self.rewards_map, &key);

    assert!(end > pool_rewards.end, EWaitUntilRewardsEnd);

    pool_rewards.end = end;
    pool_rewards.rewards_per_second = math64::div_down(
      balance::join(bag::borrow_mut(&mut self.rewards_balances, key), 
      coin::into_balance(coin_in)
    ), end - current_time);
  }

  // === Private Functions ===
  
  fun settle_account(self: &RebalancePool, account: &mut Account) {
    let account_epoch = account.epoch;
    let last_snapshot_epoch = table_vec::length(&self.epochs);

    // Use the current values
    if (last_snapshot_epoch == account_epoch) return;

    account.epoch == last_snapshot_epoch;

    let index = account_epoch;

    let rewards_vector = vec_set::keys(&self.rewards);

    let num_of_rewards = vector::length(rewards_vector);

    // Bring account up to the current value using the snapshots.
    while (last_snapshot_epoch > index) {
      
      let snapshot = table_vec::borrow(&self.epochs, index);

      let j = 0;

      while (num_of_rewards > 0) {

        let reward_type_name = vector::borrow(rewards_vector, j);

        let accrued_rewards_per_share = *vec_map::get(&snapshot.accrued_rewards_per_share_map, reward_type_name);

        update_account_rewards(account, reward_type_name, accrued_rewards_per_share);

        j = j + 1;
      };

      let f_percent = math64::mul_div_down(account.f_balance, PRECISION, snapshot.initial_f_balance);

      account.f_balance = math64::mul_div_down(f_percent, snapshot.final_f_balance, PRECISION);
      account.base_balance = account.base_balance + math64::mul_div_down(f_percent, snapshot.base_balance, PRECISION);

      index = index + 1;
    };
  }

  fun update_all_account_rewards(self: &RebalancePool, account: &mut Account) {

    if (self.last_update == account.rewards_last_update) return;

    let rewards_vector = vec_set::keys(&self.rewards);
    let num_of_rewards = vector::length(rewards_vector);

    let index = 0;

    while (num_of_rewards > index) {
      let reward_type_name = vector::borrow(rewards_vector, index);

      let pool_rewards = *vec_map::get(&self.rewards_map, reward_type_name);

      update_account_rewards(account, reward_type_name, pool_rewards.accrued_rewards_per_share);

      index = index + 1;
    };

    account.rewards_last_update = self.last_update;
  }

  fun update_account_rewards(account: &mut Account, reward_type_name: &TypeName, accrued_rewards_per_share: u256) {
    let reward_account = vec_map::get_mut(&mut account.rewards_map, reward_type_name);

    let pending_rewards = compute_pending_rewards(account.f_balance, reward_account.debt, accrued_rewards_per_share);

    reward_account.amount = reward_account.amount + pending_rewards;
    reward_account.debt = compute_rewards_debt(account.f_balance, accrued_rewards_per_share);
  }

  fun update_pool_rewards(self: &mut RebalancePool, clock: &Clock) {
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

      let reward = vec_map::get_mut(&mut self.rewards_map, &key);

      if (reward.end > current_time) {
        reward.accrued_rewards_per_share = compute_accrued_rewards_per_share(
          reward.rewards_per_second, 
          reward.accrued_rewards_per_share,
          f_balance_value,
          time_elapsed
        );
      };

      index = index + 1;
    };
  }

  fun compute_accrued_rewards_per_share(
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

  fun compute_rewards_debt(f_balance: u64, accrued_rewards_per_share: u256): u256 {
    (((f_balance as u256) * accrued_rewards_per_share / (PRECISION as u256)))
  }

  fun compute_pending_rewards(f_balance: u64, debt: u256, accrued_rewards_per_share: u256): u64 {
    ((((f_balance as u256) * accrued_rewards_per_share / (PRECISION as u256)) - debt) as u64)
  }

  fun clock_timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }

  // === Test Functions ===
}