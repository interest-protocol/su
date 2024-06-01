module su::x_sui {
  // === Imports ===

  use sui::coin::create_currency;
  use sui::transfer::{public_transfer, public_share_object};

  // === Structs ===
  
  public struct X_SUI has drop {}

  // === Public-Mutative Functions ===

  #[allow(lint(share_owned))]
  fun init(otw: X_SUI, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = create_currency(
      otw,
      9,
      b"xSui",
      b"Leveraged Sui",
      b"A leveraged coin without funding rate nor liquidations.",
      option::none(),
      ctx
    );

    public_share_object(coin_metadata);
    public_transfer(treasury_cap, ctx.sender());
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(X_SUI {}, ctx);
  }
}