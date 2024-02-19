module su::treasury_cap_map {
  // === Imports ===

  use std::type_name;

  use std::option::Option;
  
  use sui::coin::TreasuryCap;
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::object::{Self, UID, ID};
  use sui::object_bag::{Self, ObjectBag};

  // === Friends ===

  friend su::metadata;
  friend su::treasury;

  // === Structs ===

  struct TreasuryCapMap has key {
    id: UID,
    inner: ObjectBag
  }

  // === Public-Mutative Functions ===

  fun init(ctx: &mut TxContext) {
    share_object(TreasuryCapMap {
      id: object::new(ctx),
      inner: object_bag::new(ctx)
    });
  }

  // === Public-View Functions ===

  public fun borrow<CoinType: drop>(self: &TreasuryCapMap): &TreasuryCap<CoinType> {
    object_bag::borrow(&self.inner, type_name::get<CoinType>())
  }

  public fun contains<CoinType: drop>(self: &TreasuryCapMap): bool {
    object_bag::contains(&self.inner, type_name::get<CoinType>())
  }

  public fun length(self: &TreasuryCapMap): u64 {
    object_bag::length(&self.inner)
  }

  public fun is_empty(self: &TreasuryCapMap): bool {
    object_bag::is_empty(&self.inner)
  }

  public fun value_id<CoinType: drop>(self: &TreasuryCapMap): Option<ID> {
    object_bag::value_id(&self.inner, type_name::get<CoinType>())
  }

  // === Public-Friend Functions ===

  public(friend) fun add<CoinType: drop>(self: &mut TreasuryCapMap, v: TreasuryCap<CoinType>) {
    object_bag::add(&mut self.inner, type_name::get<CoinType>(), v);
  }

  public(friend) fun remove<CoinType: drop>(self: &mut TreasuryCapMap): TreasuryCap<CoinType> {
    object_bag::remove(&mut self.inner, type_name::get<CoinType>())
  }  

  public(friend) fun borrow_mut<CoinType: drop>(self: &mut TreasuryCapMap): &mut TreasuryCap<CoinType> {
    object_bag::borrow_mut(&mut self.inner, type_name::get<CoinType>())
  }

  public(friend) fun destroy_empty(self: TreasuryCapMap) {
    let TreasuryCapMap { id, inner } = self;

    object::delete(id);
    object_bag::destroy_empty(inner);
  } 

  // === Test Functions ===

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}