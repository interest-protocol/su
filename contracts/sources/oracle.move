module su::oracle {
  // === Imports ===

  use sui::transfer::public_transfer;

  use suitears::owner;
  use suitears::oracle;

  // === Constants ===

  /// ! 5 minutes in milliseconds - TEST NET ONLY
  const TIME_LIMIT: u64 = 3600000;

  /// ! 3% - TEST NET ONLY
  const PRICE_DEVIATION: u256 = 30000000000000000;

  // === Structs ===

  public struct SuOracle has drop {}

  // === Public-Mutative Functions ===

  fun init(ctx: &mut TxContext) {
    let mut oracle_cap = owner::new(SuOracle {}, vector[], ctx);
    let su_oracle = oracle::new(&mut oracle_cap, SuOracle {}, vector[], TIME_LIMIT, PRICE_DEVIATION, ctx);

    su_oracle.share();
    public_transfer(oracle_cap, ctx.sender());
  } 
}
