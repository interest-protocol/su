module su::cast {

  public fun to_u64(x: u256): u64 {
    (x as u64)
  }

  public fun to_u256(x: u64): u256 {
    (x as u256)
  }

}