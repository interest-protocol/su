module sui::assets {
  // === Imports ===
  use std::type_name;
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::coin::{Self, TreasuryCap};
  use sui::dynamic_object_field as dfo;

  // === Errors ===

  const EDifferentPackage: u64 = 0;
  const EMustHaveZeroSupply: u64 = 1;

  // === Structs ===

  struct Assets has key {
    id: UID
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use, lint(share_owned))]
  fun init(ctx: &mut TxContext) {
    share_object(Assets { id: object::new(ctx) });
  }

  public fun add<CoinType: drop>(self: &mut Assets, treasury_cap: TreasuryCap<CoinType>) {
    assert!(coin::total_supply(&treasury_cap) == 0, EMustHaveZeroSupply);
    dfo::add(&mut self.id, type_name::get<CoinType>(), treasury_cap);
  }

  public fun treasury_cap_mut<CoinType: drop, Witness: drop>(self: &mut Assets, _: Witness): &mut TreasuryCap<CoinType> {
    assert_same_package<Witness>();
    dfo::borrow_mut(&mut self.id, type_name::get<CoinType>())
  }
 
  // === Public-View Functions ===

  public fun treasury_cap<T: drop>(self: &Assets): &TreasuryCap<T> {
    dfo::borrow(&self.id, type_name::get<T>())
  }

  // === Private Functions ===
  
  fun assert_same_package<Witness: drop>() {
    assert!(type_name::get_address(&type_name::get<Witness>()) == type_name::get_address(&type_name::get<Assets>()), EDifferentPackage);
  }

  // === Test Functions === 
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }   
}