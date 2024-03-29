module su::x_sui {
  // === Imports ===

  use std::option;

  use sui::coin::create_currency;
  use sui::tx_context::{sender, TxContext};
  use sui::transfer::{public_transfer, public_share_object};

  // === Structs ===
  
  struct X_SUI has drop {}

  // === Public-Mutative Functions ===

  fun init(otw: X_SUI, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = create_currency(
      otw,
      9,
      b"xSui",
      b"Leveraged Sui",
      b"A leveraged coin with a beta of 0.9",
      option::none(),
      ctx
    );

    public_share_object(coin_metadata);
    public_transfer(treasury_cap, sender(ctx));
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(X_SUI {}, ctx);
  }
}