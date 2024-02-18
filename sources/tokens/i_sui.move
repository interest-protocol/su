module su::i_sui {
  // === Imports ===

  use std::option;

  use sui::coin::create_currency;
  use sui::tx_context::{sender, TxContext};
  use sui::transfer::{public_transfer, public_share_object};

  // === Structs ===
  
  struct I_SUI has drop {}

  // === Public-Mutative Functions ===

  fun init(otw: I_SUI, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = create_currency(
      otw,
      9,
      b"iSui",
      b"Interest Protocol Sui",
      b"Liquid Staking Token developed by Interest Labs.",
      option::none(),
      ctx
    );

    public_share_object(coin_metadata);
    public_transfer(treasury_cap, sender(ctx));
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(I_SUI {}, ctx);
  }
}