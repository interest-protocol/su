module su::treasury {
  // === Imports ===

  use std::type_name::{Self, TypeName};
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::vec_set::{Self, VecSet};
  use sui::coin::{Self, TreasuryCap};
  use sui::dynamic_object_field as dfo;

  use su::admin::Admin;

  // === Errors ===

  const EDisallowedWitness: u64 = 0;
  const EMustHaveZeroSupply: u64 = 1;

  // === Structs ===

  struct Treasury has key {
    id: UID,
    allow_list: VecSet<TypeName>
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use)]
  fun init(ctx: &mut TxContext) {
    share_object(Treasury { id: object::new(ctx), allow_list: vec_set::empty() });
  }

  public fun add<CoinType: drop>(self: &mut Treasury, treasury_cap: TreasuryCap<CoinType>) {
    assert!(coin::total_supply(&treasury_cap) == 0, EMustHaveZeroSupply);
    dfo::add(&mut self.id, type_name::get<CoinType>(), treasury_cap);
  }

  public fun coin_cap_mut<CoinType: drop, Witness: drop>(self: &mut Treasury, _: Witness): &mut TreasuryCap<CoinType> {
    assert!(vec_set::contains(&self.allow_list, &type_name::get<Witness>()), EDisallowedWitness);
    dfo::borrow_mut(&mut self.id, type_name::get<CoinType>())
  }
 
  // === Public-View Functions ===

  public fun coin_cap<CoinType: drop>(self: &Treasury): &TreasuryCap<CoinType> {
    dfo::borrow(&self.id, type_name::get<CoinType>())
  }

  // === Admin Functions ===

  public fun allow<Witness: drop>(self: &mut Treasury, _: &Admin) {
    vec_set::insert(&mut self.allow_list, type_name::get<Witness>());
  }

  public fun disallow<Witness: drop>(self: &mut Treasury, _: &Admin) {
    vec_set::remove(&mut self.allow_list, &type_name::get<Witness>());
  }

  // === Test Functions === 
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }   
}