// TODO replace by a live LST coin
module su::f_sui {
  // === Imports ===

  use sui::coin::create_currency;
  use sui::transfer::{public_transfer, public_share_object};

  // === Structs ===
  
  public struct F_SUI has drop {}

  // === Public-Mutative Functions ===

  fun init(otw: F_SUI, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = create_currency(
      otw,
      9,
      b"fSui",
      b"Fractional Sui",
      b"A floating stable coin with a beta of 0.1",
      option::none(),
      ctx
    );

    public_share_object(coin_metadata);
    public_transfer(treasury_cap, ctx.sender());
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(F_SUI {}, ctx);
  }
}