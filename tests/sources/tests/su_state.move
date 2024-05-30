#[test_only]
module su_tests::su_state_tests {
  
  use sui::test_utils::assert_eq;

  use suitears::int;
  use suitears::math64;
  use suitears::math256;

  use su::su_state::{Self, SuState};

  use su_tests::assert_state;

  use fun math64::mul_div_down as u64.mul_div_down;
  use fun math256::mul as u256.mul;
  use fun math256::div_down as u256.div_down;
  use fun math256::sub as u256.sub;
  use fun math256::add as u256.add;

  const PRECISION: u64 = 1_000_000_000;
  const D_NAV: u256 = 1_000_000_000;
  const REBALANCE_COLLATERAL_RATIO: u64 = 1_600_000_000;

  #[test]
  fun view_functions() {
    let base_supply = 100 * PRECISION;
    let base_nav = 2 * PRECISION;
    let f_multiple = int::from_u64(11 * PRECISION / 10);
    let f_supply = 10 * PRECISION;
    let d_supply = 10 * PRECISION;
    let f_nav = 11 * PRECISION / 10;
    let x_supply = 80 * PRECISION;
    let x_nav = 2225 * PRECISION / 1000;

    let state = su_state::new(
      base_supply,
      base_nav,
      f_multiple,
      d_supply,
      f_supply,
      f_nav,
      x_supply,
      x_nav,
    );

    let assert = assert_state::new(state);

    // Sui Move 2024 on Steroids
    assert
    .base_supply(base_supply)
    .base_nav(base_nav)
    .f_multiple(f_multiple)
    .f_supply(f_supply)
    .f_nav(f_nav)
    .x_supply(x_supply)
    .x_nav(x_nav);
  }

  #[test]
  fun collateral_ratio() {
    let state = make_high_cr_state();

    // 200 / 22 => 9.523x
    assert_eq(state.collateral_ratio(), 9523809523);  
  }

  #[test]
  fun max_mintable_d_coin() {
    let state = make_high_cr_state();

    let (max_base_in_before_rebalance, max_f_coin_minted_before_rebalance ) = state.max_mintable_d_coin(REBALANCE_COLLATERAL_RATIO);
    
    // 9x CR => we can mint a lot of F_COIN
    assert_eq(max_base_in_before_rebalance, 138666666666);
    assert_eq(max_f_coin_minted_before_rebalance, 277333333333);

    let state = make_low_cr_state();

    let (max_base_in_before_rebalance, max_f_coin_minted_before_rebalance ) = state.max_mintable_d_coin(REBALANCE_COLLATERAL_RATIO);

    // CR <= 1.6X can NOT mint any more F_COIN
    assert_eq(max_base_in_before_rebalance, 0);
    assert_eq(max_f_coin_minted_before_rebalance, 0);    
  }

  #[test]
  fun max_mintable_f_coin() {
    let state = make_high_cr_state();

    let (max_base_in_before_rebalance, max_f_coin_minted_before_rebalance ) = state.max_mintable_f_coin(REBALANCE_COLLATERAL_RATIO);
    
    // 9x CR => we can mint a lot of F_COIN
    assert_eq(max_base_in_before_rebalance, 138666666666);
    assert_eq(max_f_coin_minted_before_rebalance, 252121212121);

    let state = make_low_cr_state();

    let (max_base_in_before_rebalance, max_f_coin_minted_before_rebalance ) = state.max_mintable_f_coin(REBALANCE_COLLATERAL_RATIO);

    // CR <= 1.6X can NOT mint any more F_COIN
    assert_eq(max_base_in_before_rebalance, 0);
    assert_eq(max_f_coin_minted_before_rebalance, 0);    
  }

  #[test]
  fun max_mintable_x_coin() {
    let state = make_high_cr_state();

    let (max_base_in_before_rebalance,max_x_coin_minted_before_rebalance ) = state.max_mintable_x_coin(REBALANCE_COLLATERAL_RATIO);

    // Have a CR >= 1.6x can mint as much X_COIN as we wish
    assert_eq(max_base_in_before_rebalance, 0);
    assert_eq(max_x_coin_minted_before_rebalance, 0);

    let state = make_low_cr_state();

    let (max_base_in_before_rebalance, max_x_coin_minted_before_rebalance ) = state.max_mintable_x_coin( REBALANCE_COLLATERAL_RATIO);

    // Have a CR < 1.6x there is an incentive to mint X Coin
    assert_eq(max_base_in_before_rebalance, 20 * PRECISION);
    assert_eq(max_x_coin_minted_before_rebalance, 8988764044);    
  }  

  #[test]
  fun max_redeemable_d_coin() {
    let state = make_high_cr_state();

    let (max_base_out_before_rebalance, max_f_coin_burnt_before_rebalance ) = state.max_redeemable_d_coin(REBALANCE_COLLATERAL_RATIO);

    // CR is very healthy, no bonuses. 
    assert_eq(max_base_out_before_rebalance, 0);
    assert_eq(max_f_coin_burnt_before_rebalance, 0);   

    let state = make_low_cr_state();

    let (max_base_out_before_rebalance, max_f_coin_burnt_before_rebalance ) = state.max_redeemable_d_coin(REBALANCE_COLLATERAL_RATIO);

    // CR is very unhealthy, we have a bonus when minting SUI_DOLLAR
    assert_eq(max_base_out_before_rebalance, 33333333333);
    assert_eq(max_f_coin_burnt_before_rebalance, 33333333333);       
  }

  #[test]
  fun max_redeemable_f_coin() {
    let state = make_high_cr_state();

    let (max_base_out_before_rebalance, max_f_coin_burnt_before_rebalance ) = state.max_redeemable_f_coin(REBALANCE_COLLATERAL_RATIO);

    // CR is very healthy, no bonuses. 
    assert_eq(max_base_out_before_rebalance, 0);
    assert_eq(max_f_coin_burnt_before_rebalance, 0);   

    let state = make_low_cr_state();

    let (max_base_out_before_rebalance, max_f_coin_burnt_before_rebalance ) = state.max_redeemable_f_coin(REBALANCE_COLLATERAL_RATIO);

    // CR is very unhealthy, we have a bonus when minting F_COIN
    assert_eq(max_base_out_before_rebalance, 22222222222);
    assert_eq(max_f_coin_burnt_before_rebalance, 33333333333);       
  }

  #[test]
  fun max_redeemable_x_coin() {
    let state = make_high_cr_state();

    let (max_base_out_before_rebalance, max_f_coin_burnt_before_rebalance ) = state.max_redeemable_x_coin(REBALANCE_COLLATERAL_RATIO);

    // CR is very healthy, can mint X_COIN
    assert_eq(max_base_out_before_rebalance, 74786516853);
    assert_eq(max_f_coin_burnt_before_rebalance, 83200000000);   

    let state = make_low_cr_state();

    let (max_base_out_before_rebalance, max_f_coin_burnt_before_rebalance ) = state.max_redeemable_x_coin(REBALANCE_COLLATERAL_RATIO);

    // CR is very unhealthy, should not be able to redeem X_COINS
    assert_eq(max_base_out_before_rebalance, 0);
    assert_eq(max_f_coin_burnt_before_rebalance, 0);       
  }

  #[test]  
  fun mint () {
    let state = make_high_cr_state();

    let base_in = 20 * PRECISION;

    let (d_coin_value, f_coin_value, x_coin_value) = state.mint(20 * PRECISION);

    let expected_d_coin_value = state.d_supply().mul_div_down(base_in, state.base_supply());
    let expected_f_coin_value = state.f_supply().mul_div_down(base_in, state.base_supply());
    let expected_x_coin_value = state.x_supply().mul_div_down(base_in, state.base_supply());

    assert_eq(d_coin_value, expected_d_coin_value);
    assert_eq(f_coin_value, expected_f_coin_value);
    assert_eq(x_coin_value, expected_x_coin_value);
  }

  #[test]
  fun mint_f_coin() {
    let state = make_high_cr_state();

    let base_in = 20 * PRECISION;

    let f_coin_value = state.mint_f_coin(base_in);

    let expected_f_coin_value = base_in.mul_div_down(state.base_nav(), state.f_nav());

    assert_eq(f_coin_value, expected_f_coin_value);
  }

  #[test]
  fun mint_x_coin() {
    let state = make_high_cr_state();

    let base_in = 20 * PRECISION;

    let x_coin_value = state.mint_x_coin(base_in);    

    let expected_x_coin_value = 
      (base_in as u256)
      .mul((state.base_nav() as u256))
      .mul((state.x_supply() as u256))
      .div_down(
        (state.base_supply() as u256)
        .mul((state.base_nav() as u256))
        .sub((state.f_supply() as u256).mul((state.f_nav() as u256)).add((state.d_supply() as u256).mul((state.d_nav() as u256))))
      );

    assert_eq(x_coin_value, (expected_x_coin_value as u64));    
  }

  #[test]
  fun redeem() {
    let base_supply = 100 * PRECISION;
    let base_nav = 2 * PRECISION;
    let f_multiple = int::from_u64(11 * PRECISION / 10);
    let f_supply = 10 * PRECISION;
    let d_supply = 10 * PRECISION;
    let f_nav = 11 * PRECISION / 10;
    let x_supply = 80 * PRECISION;
    let x_nav = 2225 * PRECISION / 1000;
    let f_coin_in = 10 * PRECISION;

    // First branch when x_supply is zero
    {

      let x_supply = 0;

      let state = su_state::new(
        base_supply,
        base_nav,
        f_multiple,
        d_supply,
        f_supply,
        f_nav,
        x_supply,
        x_nav,
      );

      let base_value_no_x_coin = state.redeem(0, f_coin_in, 0);
      let expected_base_value_no_x_coin = f_coin_in.mul_div_down(state.f_nav(), state.base_nav());

      assert_eq(base_value_no_x_coin, expected_base_value_no_x_coin);

      let base_value_no_f_coin = state.redeem(0, 0, f_coin_in);
      let expected_base_value_no_f_coin = state.f_nav().mul_div_down(0, state.base_nav());

      assert_eq(base_value_no_f_coin, expected_base_value_no_f_coin);      
    };

    let state = su_state::new(
      base_supply,
      base_nav,
      f_multiple,
      d_supply,
      f_supply,
      f_nav,
      x_supply,
      x_nav,
    );

    // First branch when x_supply is NOT zero

    let base_value_no_x_coin = state.redeem(0, f_coin_in, 0);
    let expected_base_value_no_x_coin = f_coin_in.mul_div_down(state.f_nav(), state.base_nav());
    assert_eq(base_value_no_x_coin, expected_base_value_no_x_coin);

    let base_value_no_beta_coins = su_state::redeem(state, d_supply, f_coin_in, 0);

    let expected_base_value_no_beta_coins = (f_coin_in as u256)
      .mul((f_nav as u256)).add((d_supply as u256).mul(D_NAV))
      .div_down((base_nav as u256));

    assert_eq(base_value_no_beta_coins, (expected_base_value_no_beta_coins as u64));    
  }


  #[test]
  fun leverage_ratio() {
    let beta = 100_000_000;
    let state = make_low_cr_state();
    let earning_ratio = int::from_u256(100_000_000 * 2);

    let leverage_ratio = state.leverage_ratio(beta, earning_ratio);

    let rho = (state.f_supply() as u256)
      .mul((state.f_nav() as u256))
      .mul((PRECISION as u256))
      .add(
       (state.d_supply() as u256).mul((PRECISION as u256)).mul((state.d_nav() as u256))
      )
      .div_down(
        (state.base_supply() as u256).mul((state.base_nav() as u256))
      );

    let x = rho
      .mul((beta as u256))
      .mul(int::to_u256(int::add(int::from_u64(PRECISION), earning_ratio)))
      .div_down((PRECISION as u256).mul((PRECISION as u256)));

    let expected_leveraged_ratio = (PRECISION as u256).sub(x).mul((PRECISION as u256)).div_down((PRECISION as u256).sub(rho));

    assert_eq(leverage_ratio, (expected_leveraged_ratio as u64));
  }

  // 9x CR
  fun make_high_cr_state(): SuState {
    let base_supply = 100 * PRECISION;
    let base_nav = 2 * PRECISION;
    let f_multiple = int::from_u64(11 * PRECISION / 10);
    let f_supply = 10 * PRECISION;
    let d_supply = 10 * PRECISION;
    let f_nav = 11 * PRECISION / 10;
    let x_supply = 80 * PRECISION;
    let x_nav = 2225 * PRECISION / 1000;

    su_state::new(
      base_supply,
      base_nav,
      f_multiple,
      d_supply,
      f_supply,
      f_nav,
      x_supply,
      x_nav,
    )
  }

  // 1.3X CR
  fun make_low_cr_state(): SuState {
    let base_supply = 100 * PRECISION;
    let base_nav = 1 * PRECISION;
    let f_multiple = int::from_u64(11 * PRECISION / 10);
    let f_supply = 30 * PRECISION;
    let d_supply = 30 * PRECISION;
    let f_nav = 15 * PRECISION / 10;
    let x_supply = 50 * PRECISION;
    let x_nav = 2225 * PRECISION / 1000; 

    su_state::new(
      base_supply,
      base_nav,
      f_multiple,
      d_supply,
      f_supply,
      f_nav,
      x_supply,
      x_nav,
    )   
  }
}