// ! This is a test net only coin
module su::i_sui {
  // === Imports ===

  use sui::transfer::{public_share_object, share_object};
  use sui::coin::{Self, create_currency, Coin, TreasuryCap};

  // === Structs ===
  
  public struct I_SUI has drop {}

  public struct Treasury has key {
    id: UID,
    cap: TreasuryCap<I_SUI>
  }

  // === Public-Mutative Functions ===

  #[allow(lint(share_owned))]
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
    share_object(Treasury {
      id: object::new(ctx),
      cap: treasury_cap
    });
  }

  // === Test Functions ===  
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(I_SUI {}, ctx);
  }

  public fun mint(
    treasury: &mut Treasury,
    amount: u64,
    ctx: &mut TxContext
  ): Coin<I_SUI> { 
    coin::mint(&mut treasury.cap, amount, ctx)
  }  
}