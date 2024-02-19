module su::metadata {
  // === Imports ===

  use std::ascii;
  use std::string;

  use sui::coin::{Self, CoinMetadata};

  use su::admin::Admin;
  use su::treasury_cap_map::{Self, TreasuryCapMap};

  // === Admin Functions ===

  public fun update_name<T: drop>(
    _: &Admin,
    treasury_cap_map: &mut TreasuryCapMap,
    metadata: &mut CoinMetadata<T>, 
    name: string::String
  ) {
    let treasury_cap = treasury_cap_map::borrow_mut<T>(treasury_cap_map);
    coin::update_name(treasury_cap, metadata, name);
  }

  public fun update_symbol<T: drop>(
    _: &Admin,
    treasury_cap_map: &mut TreasuryCapMap,
    metadata: &mut CoinMetadata<T>, 
    symbol: ascii::String
  ) {
    let treasury_cap = treasury_cap_map::borrow_mut<T>(treasury_cap_map);
    coin::update_symbol(treasury_cap, metadata, symbol);
  }

  public fun update_description<T: drop>(
    _: &Admin,
    treasury_cap_map: &mut TreasuryCapMap,
    metadata: &mut CoinMetadata<T>, 
    description: string::String
  ) {
    let treasury_cap = treasury_cap_map::borrow_mut<T>(treasury_cap_map);
    coin::update_description(treasury_cap, metadata, description);
  }

  public fun update_icon_url<T: drop>(
    _: &Admin,
    treasury_cap_map: &mut TreasuryCapMap,
    metadata: &mut CoinMetadata<T>, 
    url: ascii::String
  ) {
    let treasury_cap = treasury_cap_map::borrow_mut<T>(treasury_cap_map);
    coin::update_icon_url(treasury_cap, metadata, url);
  }  
}