module su::treasury {
  // === Imports ===

  use std::type_name;
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::coin::{Self, TreasuryCap};
  use sui::dynamic_object_field as dfo;

  // === Errors ===

  const EMustHaveZeroSupply: u64 = 0;

  // === Structs ===

  struct Treasury has key {
    id: UID
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use)]
  fun init(ctx: &mut TxContext) {
    share_object(Treasury { id: object::new(ctx) });
  }

  public fun add<CoinType: drop>(self: &mut Treasury, treasury_cap: TreasuryCap<CoinType>) {
    assert!(coin::total_supply(&treasury_cap) == 0, EMustHaveZeroSupply);
    dfo::add(&mut self.id, type_name::get<CoinType>(), treasury_cap);
  }
 
  // === Public-View Functions ===

  public fun coin_cap<CoinType: drop>(self: &Treasury): &TreasuryCap<CoinType> {
    dfo::borrow(&self.id, type_name::get<CoinType>())
  }

  // === Public-Friend Functions ===

  // ** We will replace by public(package) once it is released.
  public(friend) fun coin_cap_mut<CoinType: drop, Witness: drop>(self: &mut Treasury, _: Witness): &mut TreasuryCap<CoinType> {
    dfo::borrow_mut(&mut self.id, type_name::get<CoinType>())
  }

  // === Test Functions === 
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }   
}