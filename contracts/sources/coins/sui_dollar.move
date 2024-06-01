module su::sui_dollar {
  // === Imports ===

  use sui::coin::create_currency;
  use sui::transfer::{public_transfer, public_share_object};

  // === Structs ===
  
  public struct SUI_DOLLAR has drop {}

  // === Public-Mutative Functions ===

  #[allow(lint(share_owned))]
  fun init(otw: SUI_DOLLAR, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = create_currency(
      otw,
      9,
      b"SuiD",
      b"Sui Dollar",
      b"Su protocol stablecoin.",
      option::none(),
      ctx
    );

    public_share_object(coin_metadata);
    public_transfer(treasury_cap, ctx.sender());
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(SUI_DOLLAR {}, ctx);
  }
}