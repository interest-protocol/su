module su::treasury {
  // === Imports ===

  use sui::object::{Self, UID};
  use sui::versioned::{Self, Versioned};

  // === Friends ===

  // === Errors ===

  const EInvalidVersion: u64 = 0;

  // === Constants ===
  
  const STATE_VERSION_V1: u64 = 1;

  // === Structs ===

  struct StateV1 has store {
    
  }

  struct Treasury has key {
    id: UID,
    inner: Versioned
  }

  // === Public-Mutative Functions ===

  // === Public-View Functions ===

  // === Admin Functions ===

  // === Public-Friend Functions ===

  // === Private Functions ===

  fun load_state_maybe_upgrade(self: &mut Treasury): &mut StateV1 {
    upgrade_to_latest(self);
    versioned::load_value_mut(&mut self.inner)
  }

  fun upgrade_to_latest(self: &mut Treasury) {
    // * IMPORTANT: When new versions are added, we need to explicitly upgrade here.
    assert!(versioned::version(&self.inner) == STATE_VERSION_V1, EInvalidVersion);
  }

  // === Test Functions ===  
}