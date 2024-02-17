module su::state_math {
  // === Imports ===

  use suitears::int::{Self, Int};
  use suitears::math64::{mul_div_down, min};

  // === Constants ===

  /// @dev The precision used to compute nav.
  const PRECISION: u256 = 1_000_000_000;

  /// @dev The maximum value of leverage ratio.
  const MAX_LEVERAGE_RATIO: u64 = 1_000_000_000_000;

  // === Public-View Functions ===

  public fun max_mintable_f_coin(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    new_collateral_ratio: u64  
  ): (u64, u64) {
    let (
      base_supply,
      base_nav,
      new_collateral_ratio,
      f_supply,
      f_nav
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (new_collateral_ratio as u256),
      (f_supply as u256),
      (f_nav as u256)
    );

    let base_value = base_supply * base_nav * PRECISION;
    let f_value = new_collateral_ratio * f_supply * f_nav;

    if (f_value >= base_value) return (0 ,0);

      let new_collateral_ratio = new_collateral_ratio - PRECISION;
      let delta = base_value - f_value;

    (
      (delta / (base_nav * new_collateral_ratio) as u64),
      (delta / (f_nav * new_collateral_ratio) as u64)
    )
  }

  public fun max_mintable_x_coin(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    x_nav: u64,
    new_collateral_ratio: u64      
  ): (u64, u64) {
    let (
      base_supply,
      base_nav,
      new_collateral_ratio,
      f_supply,
      f_nav,
      x_nav
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (new_collateral_ratio as u256),
      (f_supply as u256),
      (f_nav as u256),
      (x_nav as u256)
    );

    let base_value = base_supply * base_nav * PRECISION;
    let f_value = new_collateral_ratio * f_supply * f_nav;

    if (base_value >= f_value) return (0, 0);

    let delta = f_value - base_value;
    
    (
      (delta / (base_nav * PRECISION) as u64), 
      (delta / (x_nav * PRECISION) as u64)
    )
  }

  public fun max_mintable_x_coin_with_incentives(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    x_nav: u64,
    incentive_ratio: u64,
    new_collateral_ratio: u64         
  ): (u64, u64) {
    let (
      base_supply,
      base_nav,
      new_collateral_ratio,
      f_supply,
      f_nav,
      x_nav,
      incentive_ratio
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (new_collateral_ratio as u256),
      (f_supply as u256),
      (f_nav as u256),
      (x_nav as u256),
      (incentive_ratio as u256)
    );

    let base_value = base_supply * base_nav * PRECISION;
    let f_value = new_collateral_ratio * f_supply * f_nav;

    if (base_value >= f_value) return (0, 0);

    let delta = f_value - base_value;

    let max_base_in = delta / (base_nav * (PRECISION + (incentive_ratio * new_collateral_ratio)));
    
    (
      (max_base_in as u64), 
      (max_base_in * base_nav * (PRECISION + incentive_ratio) / (x_nav * PRECISION) as u64)
    )    
  }

  public fun max_redeemable_f_coin(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,    
    new_collateral_ratio: u64   
  ): (u64, u64) {
    let (
      base_supply,
      base_nav,
      new_collateral_ratio,
      f_supply,
      f_nav
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (new_collateral_ratio as u256),
      (f_supply as u256),
      (f_nav as u256)
    );

    let base_value = base_supply * base_nav * PRECISION;
    let f_value = new_collateral_ratio * f_supply * f_nav;

    if (base_value >= f_value) return (0, 0);    

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = f_value - base_value;

    (
      (delta / (new_collateral_ratio * f_nav) as u64),
      (delta / (new_collateral_ratio * base_nav) as u64)
    )
  }

  public fun max_redeemable_x_coin(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    x_nav: u64,
    new_collateral_ratio: u64      
  ): (u64, u64) {
    let (
      base_supply,
      base_nav,
      new_collateral_ratio,
      f_supply,
      f_nav,
      x_nav
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (new_collateral_ratio as u256),
      (f_supply as u256),
      (f_nav as u256),
      (x_nav as u256)
    );

    let base_value = base_supply * base_nav * PRECISION;
    let f_value = new_collateral_ratio * f_supply * f_nav;

    if (f_value >= base_value) return (0, 0);  

    let delta = base_value - f_value;

    (
      (delta / (x_nav * PRECISION) as u64),
      (delta / (base_nav * PRECISION) as u64)
    )  
  }

  public fun max_liquitable(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    incentive_ratio: u64,
    new_collateral_ratio: u64        
  ): (u64, u64) {
    let (
      base_supply,
      base_nav,
      new_collateral_ratio,
      f_supply,
      f_nav,
      incentive_ratio
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (new_collateral_ratio as u256),
      (f_supply as u256),
      (f_nav as u256),
      (incentive_ratio as u256)
    );

    let base_value = base_supply * base_nav * PRECISION;
    let f_value = new_collateral_ratio * f_supply * f_nav;

    if (base_value >= f_value) return (0, 0);

    let new_collateral_ratio = new_collateral_ratio - PRECISION;
    let delta = f_value - base_value;

    (
      (delta / (base_nav * new_collateral_ratio) as u64), 
      (((delta / new_collateral_ratio) * PRECISION ) / ((PRECISION + incentive_ratio) * f_nav)  as u64)
    )    
  }

  public fun mint(
    base_in: u64,
    base_supply: u64,
    f_supply: u64,
    x_supply: u64
  ): (u64, u64) {
    (
      mul_div_down(f_supply, base_in, base_supply),
      mul_div_down(x_supply, base_in, base_supply)
    )
  }

  public fun mint_f_coin(base_in: u64, base_nav: u64, f_nav: u64): u64 {
    mul_div_down(base_in, base_nav, f_nav)
  }

  public fun mint_x_coin(
    base_in: u64, 
    base_supply: u64, 
    base_nav: u64,
    f_supply: u64,  
    f_nav: u64, 
    x_supply: u64
  ): u64 {
    let (
      base_in,
      base_supply,
      base_nav,
      f_nav,
      f_supply,
      x_supply
    ) = (
      (base_in as u256),
      (base_supply as u256),
      (base_nav as u256),
      (f_nav as u256),
      (f_supply as u256),
      (x_supply as u256),
    );

    let x_coin_out = base_in * base_nav * x_supply;
    (x_coin_out / (base_supply * base_nav - (f_supply * f_nav)) as u64) 
  }

  public fun mint_x_coin_with_incentives(
    base_in: u64,
    base_nav: u64,
    f_supply: u64,
    x_nav: u64,
    incentive_ratio: u64,
  ): (u64, u64) {
    let (
      base_in,
      base_nav,
      f_supply,
      x_nav,
      incentive_ratio
    ) = (
      (base_in as u256),
      (base_nav as u256),
      (f_supply as u256),
      (x_nav as u256),
      (incentive_ratio as u256),
    );

    let delta_value = base_in * base_nav;

    let x_coin_out = delta_value * (PRECISION + incentive_ratio) / PRECISION;
    let f_delta_nav = delta_value * incentive_ratio / PRECISION;

    (
      (x_coin_out / x_nav as u64),
      (f_delta_nav / f_supply as u64)
    )
  }

  public fun redeem(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    x_supply: u64,
    f_coin_in: u64,
    x_coin_in: u64
  ): u64 {
    let (
      base_supply,
      base_nav,
      f_supply,
      f_nav,
      x_supply,
      f_coin_in,
      x_coin_in
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (f_supply as u256),
      (f_nav as u256),
      (x_supply as u256),
      (f_coin_in as u256),
      (x_coin_in as u256),
    );    

    if (x_supply == 0) return (f_coin_in * f_nav / base_nav as u64);

    let x_value = base_supply * base_nav - (f_supply * f_nav);

    let base_out = f_coin_in * f_nav;
    base_out = base_out + (x_coin_in * x_value / x_supply);
    (base_out / base_nav as u64)
  }

  public fun liquidate_with_incentive(
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    f_coin_in: u64,
    incentive_ratio: u64
  ): (u64, u64) {
    let (
      base_nav,
      f_supply,
      f_nav,
      f_coin_in,
      incentive_ratio,
    ) = (
      (base_nav as u256),
      (f_supply as u256),
      (f_nav as u256),
      (f_coin_in as u256),
      (incentive_ratio as u256),
    );    

    let f_delta_value = f_coin_in * f_nav;

    let base_out = f_delta_value * (PRECISION + incentive_ratio) / PRECISION;
    let f_delta_nav = f_delta_value * incentive_ratio / PRECISION;
    
    (
      (base_out / base_nav as u64),
      (f_delta_nav / (f_supply - f_coin_in) as u64)
    )
  }

  public fun leverage_ratio(
    base_supply: u64,
    base_nav: u64,
    f_supply: u64,
    f_nav: u64,
    beta: u64,
    earning_ratio: Int
  ): u64 {
    let (
      base_supply,
      base_nav,
      f_supply,
      f_nav,
      beta,
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (f_supply as u256),
      (f_nav as u256),
      (beta as u256),
    ); 

    let rho = f_supply * f_nav * PRECISION / (base_supply * base_nav);
    let x = rho * beta * (int::value(int::add(int::from_u256(PRECISION), earning_ratio))) / (PRECISION * PRECISION);
    let ratio = ((PRECISION - x) * PRECISION / (PRECISION - rho) as u64);  
    min(MAX_LEVERAGE_RATIO, ratio)
  }
}