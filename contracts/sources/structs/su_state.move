module su::su_state {
  // === Imports ===
  
  use suitears::math64::min;
  use suitears::int::{Self, Int};
  use suitears::math256::mul_div_down;

  use su::cast;

  // Method Aliases

  use fun cast::to_u64 as u256.to_u64;
  use fun cast::to_u256 as u64.to_u256;  

  // === Structs ===

  public struct SuState has copy, store, drop {
    base_supply: u256,
    base_nav: u256,
    base_value: u256,
    f_multiple: Int,
    d_supply: u256,
    d_nav: u256,
    f_supply: u256,
    f_nav: u256,
    x_supply: u256,
    x_nav: u256  
  }

  /// @dev The precision used to compute nav.
  const PRECISION: u256 = 1_000_000_000;

  /// @dev The maximum value of leverage ratio.
  const MAX_LEVERAGE_RATIO: u64 = 1_000_000_000_000;

  // === Public-Mutative Functions ===

  public fun new(
    base_supply: u64,
    base_nav: u64,
    f_multiple: Int,
    d_supply: u64,
    f_supply: u64,
    f_nav: u64,
    x_supply: u64,
    x_nav: u64        
  ): SuState {
    SuState {
      base_supply: base_supply.to_u256(),
      base_nav: base_nav.to_u256(),
      base_value: base_supply.to_u256() * base_nav.to_u256() * PRECISION,
      f_multiple,
      d_supply: d_supply.to_u256(),
      d_nav: PRECISION,
      f_supply: f_supply.to_u256(),
      f_nav: f_nav.to_u256(),
      x_supply: x_supply.to_u256(),
      x_nav: x_nav.to_u256()
    }
  }

  // === Public-View Functions ===

  public fun base_supply(self: SuState): u64 {
    self.base_supply.to_u64()
  }

  public fun base_nav(self: SuState): u64 {
    self.base_nav.to_u64()
  }  

  public fun base_value(self: SuState): u64 {
    self.base_value.to_u64()
  }   

  public fun d_supply(self: SuState): u64 {
    self.d_supply.to_u64()
  }

  public fun d_nav(self: SuState): u64 {
    self.d_nav.to_u64()
  }

  public fun f_multiple(self: SuState): Int {
    self.f_multiple
  }

  public fun f_supply(self: SuState): u64 {
    self.f_supply.to_u64()
  }        

  public fun f_nav(self: SuState): u64 {
    self.f_nav.to_u64()
  }    

  public fun x_supply(self: SuState): u64 {
    self.x_supply.to_u64()
  }    

  public fun x_nav(self: SuState): u64 {
    self.x_nav.to_u64()
  } 

  public fun collateral_ratio(self: SuState): u64 {
    ((self.base_supply * self.base_nav * PRECISION) / ((self.f_supply * self.f_nav) + (self.d_supply * self.d_nav))).to_u64()
  }

  public fun max_mintable_d_coin(
    self: SuState,
    new_collateral_ratio: u64  
  ): (u64, u64) {

    let new_collateral_ratio = new_collateral_ratio.to_u256();

    let d_value = new_collateral_ratio * self.d_supply * self.d_nav;
    //@dev We need to remove the current f_value from the base_value
    let base_value = self.base_value - (new_collateral_ratio * self.f_supply * self.f_nav);

    if (d_value >= base_value) return (0, 0);

      let new_collateral_ratio = new_collateral_ratio - PRECISION;
      let delta = base_value - d_value;

    (
      (delta / (self.base_nav * new_collateral_ratio)).to_u64(),
      (delta / (self.d_nav * new_collateral_ratio)).to_u64()
    )
  }

  public fun max_mintable_f_coin(
    self: SuState,
    new_collateral_ratio: u64  
  ): (u64, u64) {

    let new_collateral_ratio = new_collateral_ratio.to_u256();

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;
    //@dev We need to remove the current d_value from the base_value
    let base_value = self.base_value - (new_collateral_ratio * self.d_supply * self.d_nav);

    if (f_value >= base_value) return (0, 0);

      let new_collateral_ratio = new_collateral_ratio - PRECISION;
      let delta = base_value - f_value;

    (
      (delta / (self.base_nav * new_collateral_ratio)).to_u64(),
      (delta / (self.f_nav * new_collateral_ratio)).to_u64()
    )
  }

  public fun max_mintable_x_coin(
    self: SuState,
    new_collateral_ratio: u64       
  ): (u64, u64) {
    let new_collateral_ratio = new_collateral_ratio.to_u256();

    let df_value = (new_collateral_ratio * self.f_supply * self.f_nav) + (new_collateral_ratio * self.d_supply * self.d_nav);

    if (self.base_value >= df_value) return (0, 0);

    let delta = df_value - self.base_value;
    
    (
      (delta / (self.base_nav * PRECISION)).to_u64(), 
      (delta / (self.x_nav * PRECISION)).to_u64()
    )
  }

  public fun max_redeemable_d_coin(
    self: SuState,  
    new_collateral_ratio: u64   
  ): (u64, u64) {
    let new_collateral_ratio = new_collateral_ratio.to_u256();

    let d_value = new_collateral_ratio * self.d_supply * self.d_nav;
    let base_value = self.base_value - (new_collateral_ratio * self.f_supply * self.f_nav);
    
    if (base_value >= d_value) return (0, 0);    

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = d_value - base_value;

    (
      (delta / (new_collateral_ratio * self.d_nav)).to_u64(),
      (delta / (new_collateral_ratio * self.base_nav)).to_u64()
    )
  }

  public fun max_redeemable_f_coin(
    self: SuState,  
    new_collateral_ratio: u64   
  ): (u64, u64) {
    let new_collateral_ratio = new_collateral_ratio.to_u256();

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;
    let base_value = self.base_value - (new_collateral_ratio * self.d_supply * self.d_nav);
    
    if (base_value >= f_value) return (0, 0);    

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = f_value - base_value;

    (
      (delta / (new_collateral_ratio * self.f_nav)).to_u64(),
      (delta / (new_collateral_ratio * self.base_nav)).to_u64()
    )
  }

  public fun max_redeemable_x_coin(
    self: SuState,
    new_collateral_ratio: u64      
  ): (u64, u64) {
    let new_collateral_ratio = new_collateral_ratio.to_u256();

    let df_value = (new_collateral_ratio * self.f_supply * self.f_nav) + (new_collateral_ratio * self.d_supply * self.d_nav);

    if (df_value >= self.base_value) return (0, 0);  

    let delta = self.base_value - df_value;

    (
      (delta / (self.x_nav * PRECISION)).to_u64(),
      (delta / (self.base_nav * PRECISION)).to_u64()
    )  
  }

  public fun mint(self: SuState, base_in: u64): (u64, u64, u64) {
    let base_in = base_in.to_u256();
    (
      (mul_div_down(self.d_supply, base_in, self.base_supply)).to_u64(),
      (mul_div_down(self.f_supply, base_in, self.base_supply)).to_u64(),
      (mul_div_down(self.x_supply, base_in, self.base_supply)).to_u64()
    )
  }

  public fun mint_d_coin(self: SuState, base_in: u64): u64 {
    (mul_div_down(base_in.to_u256(), self.base_nav, self.d_nav)).to_u64()
  }

  public fun mint_f_coin(self: SuState, base_in: u64): u64 {
    (mul_div_down(base_in.to_u256(), self.base_nav, self.f_nav)).to_u64()
  }

  public fun mint_x_coin(self: SuState, base_in: u64): u64 {
    let base_in = base_in.to_u256();

    let x_coin_out = base_in * self.base_nav * self.x_supply;
    (x_coin_out / (self.base_supply * self.base_nav - ((self.f_supply * self.f_nav) + (self.d_supply * self.d_nav)))).to_u64() 
  }

  public fun redeem(
    self: SuState,
    d_coin_in: u64,
    f_coin_in: u64,
    x_coin_in: u64
  ): u64 {
    let (d_coin_in, f_coin_in, x_coin_in) = (d_coin_in.to_u256(), f_coin_in.to_u256(), x_coin_in.to_u256());   

    if (self.x_supply == 0) return (((f_coin_in * self.f_nav) + (d_coin_in * self.d_nav)) / self.base_nav).to_u64();

    let x_value = self.base_supply * self.base_nav - ((self.f_supply * self.f_nav) + (self.d_supply * self.d_nav));

    let mut base_out = (f_coin_in * self.f_nav) + (d_coin_in * self.d_nav);
    base_out = base_out + (x_coin_in * x_value / self.x_supply);
    (base_out / self.base_nav).to_u64()
  }

  public fun leverage_ratio(
    self: SuState,
    beta: u64,
    earning_ratio: Int
  ): u64 {
    let beta = beta.to_u256(); 

    let rho = ((self.f_supply * self.f_nav * PRECISION) + (self.d_supply * self.d_nav * PRECISION)) / (self.base_supply * self.base_nav);
    let x = rho * beta * int::from_u256(PRECISION).add(earning_ratio).to_u256() / (PRECISION * PRECISION);
    let ratio = ((PRECISION - x) * PRECISION / (PRECISION - rho)).to_u64();  
    min(MAX_LEVERAGE_RATIO, ratio)
  }
}