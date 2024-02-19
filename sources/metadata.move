module su::metadata {
  // === Imports ===

  use std::ascii;
  use std::string;
  use std::type_name::{Self, TypeName};

  use sui::coin::{Self, CoinMetadata, TreasuryCap};

  use su::admin::Admin;
  use su::repository::{Self, Repository};

  // === Admin Functions ===

  public fun update_name<T: drop>(
    _: &Admin,
    repository: &mut Repository,
    metadata: &mut CoinMetadata<T>, 
    name: string::String
  ) {
    let treasury_cap = repository::borrow_mut<TypeName, TreasuryCap<T>>(repository, type_name::get<T>());
    coin::update_name(treasury_cap, metadata, name);
  }

  public fun update_symbol<T: drop>(
    _: &Admin,
    repository: &mut Repository,
    metadata: &mut CoinMetadata<T>, 
    symbol: ascii::String
  ) {
    let treasury_cap = repository::borrow_mut<TypeName, TreasuryCap<T>>(repository, type_name::get<T>());
    coin::update_symbol(treasury_cap, metadata, symbol);
  }

  public fun update_description<T: drop>(
    _: &Admin,
    repository: &mut Repository,
    metadata: &mut CoinMetadata<T>, 
    description: string::String
  ) {
    let treasury_cap = repository::borrow_mut<TypeName, TreasuryCap<T>>(repository, type_name::get<T>());
    coin::update_description(treasury_cap, metadata, description);
  }

  public fun update_icon_url<T>(
    _: &Admin,
    repository: &mut Repository,
    metadata: &mut CoinMetadata<T>, 
    url: ascii::String
  ) {
    let treasury_cap = repository::borrow_mut<TypeName, TreasuryCap<T>>(repository, type_name::get<T>());
    coin::update_icon_url(treasury_cap, metadata, url);
  }  
}