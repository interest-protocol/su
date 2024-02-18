module su::ema {
  // === Imports ===

  use sui::clock::{Self, Clock};

  use suitears::int;
  use suitears::fixed_point_wad;

  // === Constants ===

  const PRECISION: u256 = 1_000_000_000;

  // === Structs ===

  struct EMA has store, copy, drop {
    last_timestamp: u64,
    sample_interval: u64,
    last_value: u64,
    last_ema_value: u64
  }

  // === Public-Mutative Functions ===

  public fun new(c: &Clock, sample_interval: u64): EMA {
    EMA {
      last_timestamp: timestamp_s(c),
      sample_interval: sample_interval,
      last_value: 0,
      last_ema_value: 0
    }
  }

  public fun set(self: &mut EMA, c: &Clock, last_value: u64) {
    self.last_value = last_value;
    self.last_timestamp = timestamp_s(c);
  }

  public fun ema_value(self: EMA, c: &Clock): u64 {
    let current_s = timestamp_s(c);
    if (current_s > self.last_timestamp) {

      let dt = current_s - self.last_timestamp;
      let e = ((dt as u256) * PRECISION) / (self.last_timestamp as u256);

      if (e > 41000000000) {
        self.last_value
      } else {
        let alpha = int::to_u256(fixed_point_wad::exp(int::neg_from_u256((e * PRECISION))));

        let (
          last_value,
          last_ema_value,
          alpha
        ) = (
          (self.last_value as u256),
          (self.last_ema_value as u256),
          (alpha / PRECISION)
        );

        ((last_value * (PRECISION - alpha) + last_ema_value * alpha) / PRECISION as u64)
      }
    } else {
      self.last_ema_value
    }
  }

  // === Public-View Functions === 

  public fun last_timestamp(self: EMA): u64 {
    self.last_timestamp
  }

  public fun sample_interval(self: EMA): u64 {
    self.sample_interval
  }  

  public fun last_value(self: EMA): u64 {
    self.last_value
  }    

  public fun last_ema_value(self: EMA): u64 {
    self.last_ema_value
  }
  
  // === Private Functions ===

  fun timestamp_s(c: &Clock): u64 {
    clock::timestamp_ms(c) / 1000
  }
}