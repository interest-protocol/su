module su::state_math {
  // === Imports ===

  use suitears::math64::min;
  use suitears::int::{Self, Int};
  use suitears::math256::mul_div_down;

  // === Structs ===

  struct State has copy, store, drop {
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

  public fun new(
    base_supply: u64,
    base_nav: u64,
    f_multiple: Int,
    f_supply: u64,
    f_nav: u64,
    x_supply: u64,
    x_nav: u64        
  ): State {
    State {
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

  public fun max_mintable_f_coin(
    state: State,
    new_collateral_ratio: u64  
  ): (u64, u64) {

    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * state.f_supply * state.f_nav;

    if (f_value >= state.base_value) return (0 ,0);

      let new_collateral_ratio = new_collateral_ratio - PRECISION;
      let delta = state.base_value - f_value;

    (
      (delta / (state.base_nav * new_collateral_ratio) as u64),
      (delta / (state.f_nav * new_collateral_ratio) as u64)
    )
  }

  public fun max_mintable_x_coin(
    state: State,
    new_collateral_ratio: u64       
  ): (u64, u64) {
    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * state.f_supply * state.f_nav;

    if (state.base_value >= f_value) return (0, 0);

    let delta = f_value - state.base_value;
    
    (
      (delta / (state.base_nav * PRECISION) as u64), 
      (delta / (state.x_nav * PRECISION) as u64)
    )
  }

  public fun max_mintable_x_coin_with_incentives(
    state: State,
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

    let f_value = new_collateral_ratio * state.f_supply * state.f_nav;

    if (state.base_value >= f_value) return (0, 0);

    let delta = f_value - state.base_value;

    let max_base_in = delta / (state.base_nav * (PRECISION + (incentive_ratio * new_collateral_ratio)));
    
    (
      (max_base_in as u64), 
      (max_base_in * state.base_nav * (PRECISION + incentive_ratio) / (state.x_nav * PRECISION) as u64)
    )    
  }

  public fun max_redeemable_f_coin(
    state: State,  
    new_collateral_ratio: u64   
  ): (u64, u64) {
    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * state.f_supply * state.f_nav;

    if (state.base_value >= f_value) return (0, 0);    

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = f_value - state.base_value;

    (
      (delta / (new_collateral_ratio * state.f_nav) as u64),
      (delta / (new_collateral_ratio * state.base_nav) as u64)
    )
  }

  public fun max_redeemable_x_coin(
    state: State,
    new_collateral_ratio: u64      
  ): (u64, u64) {
    let new_collateral_ratio = (new_collateral_ratio as u256);

    let f_value = new_collateral_ratio * state.f_supply * state.f_nav;

    if (f_value >= state.base_value) return (0, 0);  

    let delta = state.base_value - f_value;

    (
      (delta / (state.x_nav * PRECISION) as u64),
      (delta / (state.base_nav * PRECISION) as u64)
    )  
  }

  public fun max_liquitable(
    state: State,
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

    let f_value = new_collateral_ratio * state.f_supply * state.f_nav;

    if (state.base_value >= f_value) return (0, 0);

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = f_value - state.base_value;

    (
      (delta / (state.base_nav * new_collateral_ratio) as u64), 
      (((delta / new_collateral_ratio) * PRECISION ) / ((PRECISION + incentive_ratio) * state.f_nav)  as u64)
    )    
  }

  public fun mint(state: State, base_in: u64): (u64, u64) {
    let base_in = (base_in as u256);
    (
      (mul_div_down(state.f_supply, base_in, state.base_supply) as u64),
      (mul_div_down(state.x_supply, base_in, state.base_supply) as u64)
    )
  }

  public fun mint_f_coin(state: State, base_in: u64): u64 {
    (mul_div_down((base_in as u256), state.base_nav, state.f_nav) as u64)
  }

  public fun mint_x_coin(state: State, base_in: u64): u64 {
    let base_in = (base_in as u256);

    let x_coin_out = base_in * state.base_nav * state.x_supply;
    (x_coin_out / (state.base_supply * state.base_nav - (state.f_supply * state.f_nav)) as u64) 
  }

  public fun mint_x_coin_with_incentives(state: State, base_in: u64, incentive_ratio: u64): (u64, u64) {
    let (base_in, incentive_ratio) = ((base_in as u256), (incentive_ratio as u256));

    let delta_value = base_in * state.base_nav;

    let x_coin_out = delta_value * (PRECISION + incentive_ratio) / PRECISION;
    let f_delta_nav = delta_value * incentive_ratio / PRECISION;

    (
      (x_coin_out / state.x_nav as u64),
      (f_delta_nav / state.f_supply as u64)
    )
  }

  public fun redeem(
    state: State,
    f_coin_in: u64,
    x_coin_in: u64
  ): u64 {
    let (f_coin_in, x_coin_in) = ((f_coin_in as u256), (x_coin_in as u256));   

    if (state.x_supply == 0) return (f_coin_in * state.f_nav / state.base_nav as u64);

    let x_value = state.base_supply * state.base_nav - (state.f_supply * state.f_nav);

    let base_out = f_coin_in * state.f_nav;
    base_out = base_out + (x_coin_in * x_value / state.x_supply);
    (base_out / state.base_nav as u64)
  }

  public fun liquidate_with_incentive(
    state: State,
    f_coin_in: u64,
    incentive_ratio: u64
  ): (u64, u64) {
    let (f_coin_in, incentive_ratio) = ((f_coin_in as u256), (incentive_ratio as u256));      

    let f_delta_value = f_coin_in * state.f_nav;

    let base_out = f_delta_value * (PRECISION + incentive_ratio) / PRECISION;
    let f_delta_nav = f_delta_value * incentive_ratio / PRECISION;
    
    (
      (base_out / state.base_nav as u64),
      (f_delta_nav / (state.f_supply - f_coin_in) as u64)
    )
  }

  public fun leverage_ratio(
    state: State,
    beta: u64,
    earning_ratio: Int
  ): u64 {
    let beta = (beta as u256); 

    let rho = state.f_supply * state.f_nav * PRECISION / (state.base_supply * state.base_nav);
    let x = rho * beta * (int::to_u256(int::add(int::from_u256(PRECISION), earning_ratio))) / (PRECISION * PRECISION);
    let ratio = ((PRECISION - x) * PRECISION / (PRECISION - rho) as u64);  
    min(MAX_LEVERAGE_RATIO, ratio)
  }
}