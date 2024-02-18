module su::repository {
  // === Imports ===

  use std::option::Option;
  
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::object::{Self, UID, ID};
  use sui::object_bag::{Self, ObjectBag};

  // === Structs ===

  struct Repository has key {
    id: UID,
    data: ObjectBag
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use)]
  fun init(ctx: &mut TxContext) {
    share_object(Repository { id: object::new(ctx), data: object_bag::new(ctx) });
  }

  public fun add<K: copy + drop + store, V: key + store>(self: &mut Repository, k: K, v: V) {
    object_bag::add(&mut self.data, k, v);
  }
 
  // === Public-View Functions ===

  public fun borrow<K: copy + drop + store, V: key + store>(self: &Repository, k: K): &V {
    object_bag::borrow(&self.data, k)
  }

  public fun contains<K: copy + drop + store>(self: &Repository, k: K): bool {
    object_bag::contains(&self.data, k)
  }

  public fun contains_with_type<K: copy + drop + store, V: key + store>(self: &Repository, k: K): bool {
    object_bag::contains_with_type<K, V>(&self.data, k)
  }

  public fun length(self: &Repository): u64 {
    object_bag::length(&self.data)
  }

  public fun is_empty(self: &Repository): bool {
    object_bag::is_empty(&self.data)
  }

  public fun value_id<K: copy + drop + store>(self: &Repository, k: K): Option<ID> {
    object_bag::value_id(&self.data, k)
  }

  // === Public-Friend Functions ===

  public(friend) fun borrow_mut<K: copy + drop + store, V: key + store>(self: &mut Repository, k: K): &mut V {
    object_bag::borrow_mut(&mut self.data, k)
  }

  public(friend) fun remove<K: copy + drop + store, V: key + store>(self: &mut Repository, k: K): V {
    object_bag::remove(&mut self.data, k)
  }

  public(friend) fun destroy_empty(self: Repository) {
    let Repository { id, data } = self;

    object::delete(id);
    object_bag::destroy_empty(data);
  }

  // === Test Functions === 
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }   
}