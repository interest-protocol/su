module su::quote {
  // === Imports ===

  use suitears::int;
  use suitears::math64::{min, mul_div_up, mul_div_down};

  use su::su_state;
  use su::vault::{Self, Vault};
  use su::treasury::{Self, Treasury};

  // === Constants ===
  const PRECISION: u64 = 1_000_000_000;

  // === Public-View Functions ===

  public fun base_nav(treasury: &mut Treasury, price: u64): u64 {
    treasury::base_nav(treasury, price)    
  }

  public fun f_multiple(treasury: &mut Treasury, price: u64): (bool, u128) {
    let f_multiple = treasury::f_multiple(treasury, price);
    (int::is_positive(f_multiple), int::to_u128(f_multiple))
  }  

  public fun f_nav(treasury: &mut Treasury, price: u64): u64 {
    treasury::f_nav(treasury, price)
  }

  public fun x_nav(treasury: &mut Treasury, price: u64): u64 {
    treasury::x_nav(treasury, price)
  }  

  public fun collateral_ratio(treasury: &mut Treasury, price: u64): u64 {
   treasury::collateral_ratio(treasury, price)
  }  

  public fun mint_f_coin(
    vault: &mut Vault,
    treasury: &mut Treasury,
    base_in_value: u64,
    base_price: u64
  ): u64 {
    if (base_in_value == 0) return 0;

    let (max_base_in_before_stability_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      base_price, 
      vault::stability_collateral_ratio(vault)
    );

    let (max_base_in_before_rebalance_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      base_price, 
      vault::rebalance_collateral_ratio(vault)
    );

    if (max_base_in_before_rebalance_mode == 0 || base_in_value >= max_base_in_before_rebalance_mode) return 0;

    let fee_amount = mint_f_coin_fee(vault, treasury, base_in_value, base_price);

    let base_balance_cap = treasury::base_balance_cap(treasury);

    let base_supply = treasury::base_supply(treasury);

    if (base_supply + base_in_value >= base_balance_cap) return 0;

    let su_state = treasury::su_state(treasury, base_price);

    su_state::mint_x_coin(su_state, base_in_value) - fee_amount
  }  

  public fun mint_x_coin(
    vault: &mut Vault,
    treasury: &mut Treasury,
    base_in_value: u64,
    base_price: u64
  ): (u64, u64) {
    if (base_in_value == 0) return (0, 0);  

    let (max_base_in_before_stability_mode, _) = treasury::max_mintable_x_coin(
      treasury, 
      base_price, 
      vault::stability_collateral_ratio(vault)
    );

    let (max_base_in_before_rebalance_mode, _) = treasury::max_mintable_x_coin(
      treasury, 
      base_price, 
      vault::rebalance_collateral_ratio(vault)
    );

    let fee_amount = mint_x_coin_fee(vault, treasury, base_in_value, base_price);

    let base_balance_cap = vault::base_balance_cap(treasury);

    let base_supply = vault::base_supply(treasury);

    if (base_supply + base_in_value >= base_balance_cap) return (0, 0);

    let su_state = treasury::su_state(treasury, base_price);

    let x_amount = su_state::mint_x_coin(su_state, base_in_value);

    let bonus_amount = if (max_base_in_before_rebalance_mode != 0) {
      let rebalance_amount = treasury::rebalance_balance(treasury);
      let bonus_rate = treasury::bonus_rate(treasury);
      min(mul_div_down(min(max_base_in_before_rebalance_mode, base_in_value), bonus_rate, PRECISION), rebalance_amount)
    } else 0;

    (x_amount - fee_amount, bonus_amount)
  }

  public fun redeem_f_coin(
    vault: &mut Vault,
    treasury: &mut Treasury,
    f_coin_in_value: u64,
    base_price: u64,     
  ): u64 {
    if (f_coin_in_value == 0) return 0;  

    let (_, max_base_out_before_rebalance_mode) = treasury::max_redeemable_f_coin(
      treasury, 
      base_price, 
      vault::rebalance_collateral_ratio(vault)
    );     

    let su_state = treasury::su_state(treasury, base_price);

    let base_out = su_state::redeem(su_state, f_coin_in_value, 0);

    let bonus_amout = if (max_base_out_before_rebalance_mode != 0) {
      let rebalance_amount = treasury::rebalance_balance(treasury);
      let bonus_rate = treasury::bonus_rate(treasury);
      min(mul_div_down(min(max_base_out_before_rebalance_mode, base_out), bonus_rate, PRECISION), rebalance_amount)
    } else 0;

    let fee_amount = redeem_f_coin_fee(vault, treasury, base_out, base_price);

    base_out - fee_amount
  }

  public fun redeem_x_coin(
    vault: &mut Vault,
    treasury: &mut Treasury,
    x_coin_in_value: u64,
    base_price: u64   
  ): u64 {
    if (x_coin_in_value == 0) return 0;

    let (_, max_base_out_before_rebalance_mode) = treasury::max_redeemable_x_coin(
      treasury, 
      base_price, 
      vault::rebalance_collateral_ratio(vault)
    );

    if (max_base_out_before_rebalance_mode == 0) return 0;

    let su_state = treasury::su_state(treasury, base_price);

    let base_out = su_state::redeem(su_state, 0, x_coin_in_value);

    let fee_amount = redeem_x_coin_fee(vault, treasury, base_out, base_price);

    base_out - fee_amount
  }

  public fun mint_f_coin_fee(
    vault: &Vault,
    treasury: &mut Treasury,
    base_in_value: u64, 
    base_price: u64
  ): u64 {

   let (max_base_in_before_stability_mode, _) = treasury::max_mintable_f_coin(
      treasury, 
      base_price, 
      vault::stability_collateral_ratio(vault)
    );

    if (max_base_in_before_stability_mode == 0)
      compute_fee(base_in_value,vault::f_stability_mint_fee(vault))
    else {
      let standard_fee_amount = compute_fee(min(max_base_in_before_stability_mode, base_in_value), vault::f_standard_mint_fee(vault));

      let stability_fee_amount = if (base_in_value >= max_base_in_before_stability_mode) 
        compute_fee(base_in_value - max_base_in_before_stability_mode, vault::f_stability_mint_fee(vault))
      else 
        0;

      stability_fee_amount + standard_fee_amount
    }
  }

  public fun mint_x_coin_fee(
    vault: &Vault,
    treasury: &mut Treasury,
    base_in_value: u64, 
    base_price: u64
  ): u64 {

   let (max_base_in_before_stability_mode, _) = treasury::max_mintable_x_coin(
      treasury, 
      base_price, 
      vault::stability_collateral_ratio(vault)
    );

    if (max_base_in_before_stability_mode == 0) {
      compute_fee(base_in_value, vault::x_standard_mint_fee(vault))
    } else if (max_base_in_before_stability_mode >= base_in_value) {
      compute_fee(base_in_value,vault::x_stability_mint_fee(vault))
    } else {
      let standard_fee_amount = compute_fee(base_in_value - max_base_in_before_stability_mode, vault::x_standard_mint_fee(vault));
      let stability_fee_amount = compute_fee(max_base_in_before_stability_mode, vault::x_stability_mint_fee(vault));   
      stability_fee_amount + standard_fee_amount
    }
  }

  public fun redeem_f_coin_fee(
    vault: &Vault,
    treasury: &mut Treasury,
    base_out_value: u64, 
    base_price: u64
  ): u64 {

    let (_, max_base_out_before_stability_mode) = treasury::max_redeemable_f_coin(
      treasury, 
      base_price, 
      vault::stability_collateral_ratio(vault)
    ); 

    if (max_base_out_before_stability_mode == 0) {
      compute_fee(base_out_value, vault::f_standard_redeem_fee(vault))
    } else if (max_base_out_before_stability_mode >= base_out_value) {
      compute_fee(base_out_value, vault::f_stability_redeem_fee(vault))
    } else {
      let stability_fee_amount = compute_fee(max_base_out_before_stability_mode, vault::f_stability_redeem_fee(vault));
      let standard_fee_amount = compute_fee(base_out_value - max_base_out_before_stability_mode,vault::f_standard_redeem_fee(vault));

      stability_fee_amount + standard_fee_amount
    }
  }  

  public fun redeem_x_coin_fee(
    vault: &Vault,
    treasury: &mut Treasury,
    base_out_value: u64, 
    base_price: u64
  ): u64 {

    let (_, max_base_out_before_stability_mode) = treasury::max_redeemable_x_coin(
      treasury, 
      base_price, 
      vault::stability_collateral_ratio(vault)
    );

    if (max_base_out_before_stability_mode == 0) {
      compute_fee(base_out_value, vault::x_stability_redeem_fee(vault))
    } else if (max_base_out_before_stability_mode >= base_out_value) {
      compute_fee(base_out_value, vault::x_standard_redeem_fee(vault))
    } else {
      let standard_fee_amount = compute_fee(max_base_out_before_stability_mode, vault::x_standard_redeem_fee(vault));
      let stability_fee_amount = compute_fee(base_out_value - max_base_out_before_stability_mode,vault::x_stability_redeem_fee(vault));

      stability_fee_amount + standard_fee_amount
    }
  } 

  // === Private Functions ===

  fun compute_fee(value: u64, fee: u64): u64 {
    mul_div_up(value, fee, PRECISION)
  }  
}