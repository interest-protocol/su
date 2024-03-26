module su::oracle {
  // === Imports ===

  use sui::transfer::public_transfer;
  use sui::tx_context::{Self, TxContext};

  use suitears::owner;
  use suitears::oracle;

  // === Constants ===

  /// ! 5 minutes in milliseconds - TEST NET ONLY
  const TIME_LIMIT: u64 = 300000;

  /// ! 3% - TEST NET ONLY
  const PRICE_DEVIATION: u256 = 30000000000000000;

  // === Structs ===

  struct SuOracle has drop {}

  // === Public-Mutative Functions ===

  fun init(ctx: &mut TxContext) {
    let oracle_cap = owner::new(SuOracle {}, vector[], ctx);
    let su_oracle = oracle::new(&mut oracle_cap, SuOracle {}, vector[], TIME_LIMIT, PRICE_DEVIATION, ctx);

    oracle::share(su_oracle);
    public_transfer(oracle_cap, tx_context::sender(ctx));
  } 
}
