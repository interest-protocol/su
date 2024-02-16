module su::admin {
  // === Imports ===

  use sui::transfer::transfer;
  use sui::object::{Self, UID};
  use sui::tx_context::{sender, TxContext};

  // === Structs ===

  struct Admin has key, store {
    id: UID
  }

  // === Public-Mutative Functions ===

  #[allow(unused_use)]
  fun init(ctx: &mut TxContext) {
    transfer(Admin { id: object::new(ctx) }, sender(ctx));  
  }  

  // === Test Functions ===  

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}