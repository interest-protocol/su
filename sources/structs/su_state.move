module su::su_state {
  // === Imports ===

  use suitears::math64::min;
  use suitears::int::{Self, Int};
  use suitears::math256::mul_div_down;

  // === Friends ===

  friend su::treasury;

  // === Structs ===

  struct SuState has copy, store, drop {
    base_supply: u256,
    base_nav: u256,
    base_value: u256,
    f_multiple: Int,
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

  public(friend) fun new(
    base_supply: u64,
    base_nav: u64,
    f_multiple: Int,
    f_supply: u64,
    f_nav: u64,
    x_supply: u64,
    x_nav: u64        
  ): SuState {
    SuState {
      base_supply: (base_supply as u256),
      base_nav: (base_nav as u256),
      base_value: (base_supply as u256) * (base_nav as u256) * PRECISION,
      f_multiple,
      f_supply: (f_supply as u256),
      f_nav: (f_nav as u256),
      x_supply: (x_supply as u256),
      x_nav: (x_nav as u256)
    }
  }

  // === Public-View Functions ===

  public(friend) fun base_supply(self: SuState): u64 {
    (self.base_supply as u64)
  }

  public(friend) fun base_nav(self: SuState): u64 {
    (self.base_nav as u64)
  }  

  public(friend) fun base_value(self: SuState): u64 {
    (self.base_value as u64)
  }   

  public(friend) fun f_multiple(self: SuState): Int {
    self.f_multiple
  }

  public(friend) fun f_supply(self: SuState): u64 {
    (self.f_supply as u64)
  }        

  public(friend) fun f_nav(self: SuState): u64 {
    (self.f_nav as u64)
  }    

  public(friend) fun x_supply(self: SuState): u64 {
    (self.x_supply as u64)
  }    

  public(friend) fun x_nav(self: SuState): u64 {
    (self.x_nav as u64)
  } 

  public(friend) fun collateral_ratio(self: SuState): u64 {
    ((self.base_supply * self.base_nav * PRECISION) / (self.f_supply * self.f_nav)  as u64)
  }

  public(friend) fun max_mintable_f_coin(
    self: SuState,
    new_collateral_ratio: u64  
  ): (u64, u64) {

    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;

    if (f_value >= self.base_value) return (0 ,0);

      let new_collateral_ratio = new_collateral_ratio - PRECISION;
      let delta = self.base_value - f_value;

    (
      (delta / (self.base_nav * new_collateral_ratio) as u64),
      (delta / (self.f_nav * new_collateral_ratio) as u64)
    )
  }

  public(friend) fun max_mintable_x_coin(
    self: SuState,
    new_collateral_ratio: u64       
  ): (u64, u64) {
    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;

    if (self.base_value >= f_value) return (0, 0);

    let delta = f_value - self.base_value;
    
    (
      (delta / (self.base_nav * PRECISION) as u64), 
      (delta / (self.x_nav * PRECISION) as u64)
    )
  }

  public(friend) fun max_mintable_x_coin_with_incentives(
    self: SuState,
    incentive_ratio: u64,
    new_collateral_ratio: u64         
  ): (u64, u64) {
    let (
      incentive_ratio,
      new_collateral_ratio,
    ) = (
      (incentive_ratio as u256),
      (new_collateral_ratio as u256),
    );

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;

    if (self.base_value >= f_value) return (0, 0);

    let delta = f_value - self.base_value;

    let max_base_in = delta / (self.base_nav * (PRECISION + (incentive_ratio * new_collateral_ratio)));
    
    (
      (max_base_in as u64), 
      (max_base_in * self.base_nav * (PRECISION + incentive_ratio) / (self.x_nav * PRECISION) as u64)
    )    
  }

  public(friend) fun max_redeemable_f_coin(
    self: SuState,  
    new_collateral_ratio: u64   
  ): (u64, u64) {
    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;

    if (self.base_value >= f_value) return (0, 0);    

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = f_value - self.base_value;

    (
      (delta / (new_collateral_ratio * self.f_nav) as u64),
      (delta / (new_collateral_ratio * self.base_nav) as u64)
    )
  }

  public(friend) fun max_redeemable_x_coin(
    self: SuState,
    new_collateral_ratio: u64      
  ): (u64, u64) {
    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * self.f_supply * self.f_nav;

    if (f_value >= self.base_value) return (0, 0);  

    let delta = self.base_value - f_value;

    (
      (delta / (self.x_nav * PRECISION) as u64),
      (delta / (self.base_nav * PRECISION) as u64)
    )  
  }

  public(friend) fun mint(self: SuState, base_in: u64): (u64, u64) {
    let base_in = (base_in as u256);
    (
      (mul_div_down(self.f_supply, base_in, self.base_supply) as u64),
      (mul_div_down(self.x_supply, base_in, self.base_supply) as u64)
    )
  }

  public(friend) fun mint_f_coin(self: SuState, base_in: u64): u64 {
    (mul_div_down((base_in as u256), self.base_nav, self.f_nav) as u64)
  }

  public(friend) fun mint_x_coin(self: SuState, base_in: u64): u64 {
    let base_in = (base_in as u256);

    let x_coin_out = base_in * self.base_nav * self.x_supply;
    (x_coin_out / (self.base_supply * self.base_nav - (self.f_supply * self.f_nav)) as u64) 
  }

  public(friend) fun redeem(
    self: SuState,
    f_coin_in: u64,
    x_coin_in: u64
  ): u64 {
    let (f_coin_in, x_coin_in) = ((f_coin_in as u256), (x_coin_in as u256));   

    if (self.x_supply == 0) return (f_coin_in * self.f_nav / self.base_nav as u64);

    let x_value = self.base_supply * self.base_nav - (self.f_supply * self.f_nav);

    let base_out = f_coin_in * self.f_nav;
    base_out = base_out + (x_coin_in * x_value / self.x_supply);
    (base_out / self.base_nav as u64)
  }

  public(friend) fun leverage_ratio(
    self: SuState,
    beta: u64,
    earning_ratio: Int
  ): u64 {
    let beta = (beta as u256); 

    let rho = self.f_supply * self.f_nav * PRECISION / (self.base_supply * self.base_nav);
    let x = rho * beta * (int::to_u256(int::add(int::from_u256(PRECISION), earning_ratio))) / (PRECISION * PRECISION);
    let ratio = ((PRECISION - x) * PRECISION / (PRECISION - rho) as u64);  
    min(MAX_LEVERAGE_RATIO, ratio)
  }
}