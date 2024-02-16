module su::s_sui {
  // === Imports ===

  use std::option;

  use sui::coin::create_currency;
  use sui::tx_context::{sender, TxContext};
  use sui::transfer::{public_transfer, public_share_object};

  // === Structs ===
  
  struct S_SUI has drop {}

  // === Public-Mutative Functions ===

  #[allow(unused_use, lint(share_owned))]
  fun init(otw: S_SUI, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = create_currency(
      otw,
      9,
      b"sSui",
      b"Stable Sui",
      b"A floating stable coin with a beta of 0.1",
      option::none(),
      ctx
    );

    public_share_object(coin_metadata);
    public_transfer(treasury_cap, sender(ctx));
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(S_SUI {}, ctx);
  }
}