// #[test_only]
// module su_tests::vault_tests {

//   use sui::coin::Coin;
  
//   use suitears::int;
//   use suitears::math64;
//   use suitears::math256;

//   use su_tests::test_runner;
//   use su_tests::assert_state;
  
//   use fun math64::mul_div_down as u64.mul_div;
//   use fun test_runner::to_u64 as u256.to_u64;
//   use fun test_runner::to_u256 as u64.to_u256;
//   use fun test_runner::burn_coin as Coin.assert_value;
//   use fun test_runner::remove_fee as u64.remove_fee;

//   const PRECISION: u64 = 1_000_000_000;
//   const ORACLE_PRECISION: u256 = 1000000000000000000;

//   #[test]
//   fun test_mint_both() {
//     let mut runner = test_runner::start();

//     runner.next_tx(@alice);

//     let initial_supply = 50 * PRECISION;
//     let base_supply = 100 * PRECISION;

//     let (f_coin, x_coin) = runner.mint_both(
//       base_supply,
//       ORACLE_PRECISION,
//       0,
//       0
//     );

//     f_coin.assert_value(initial_supply);
//     x_coin.assert_value(initial_supply);

//     let assert = assert_state::new(runner.state());

//     assert
//     .base_supply(base_supply)
//     .base_nav(PRECISION)
//     .f_multiple(int::zero())
//     .f_supply(initial_supply)
//     .f_nav(PRECISION)                                                  
//     .x_supply(initial_supply)
//     .x_nav(PRECISION);   

//     runner.end();
//   }

//   #[test]
//   fun test_mint_f_coin() {
//     let mut runner = test_runner::start_and_mint_both();

//     runner.next_tx(@alice);

//     let base_in = 5 * PRECISION;
//     let price = 167 * (ORACLE_PRECISION / 100);

//     let initial_base_supply = runner.base_balance();
//     let initial_f_supply = runner.f_supply();
//     let initial_x_supply = runner.x_supply();

//     let expected_base_in = base_in.remove_fee(runner.f_standard_mint_fee());
//     let expected_base_nav = 167 * (PRECISION / 100);
//     let expected_f_multiple = 67 * (PRECISION / 1000);
//     let expected_f_nav = PRECISION + expected_f_multiple;
//     let expected_f_coin_value = expected_base_in.mul_div(expected_base_nav, expected_f_nav);
//     let expected_x_nav  = test_runner::compute_x_nav(
//       initial_base_supply + expected_base_in, 
//       expected_base_nav, 
//       initial_f_supply + expected_f_coin_value, 
//       expected_f_nav, 
//       initial_x_supply
//     );

//     let f_coin = runner.mint_f_coin(base_in, price, 0);

//     f_coin.assert_value(expected_f_coin_value);

//     let assert = assert_state::new(runner.state());

//     assert
//     .base_supply(initial_base_supply + expected_base_in)
//     .base_nav(expected_base_nav)
//     .f_multiple(int::from_u64(expected_f_multiple))
//     .f_supply(initial_f_supply + expected_f_coin_value)
//     .f_nav(expected_f_nav)                                                  
//     .x_supply(initial_x_supply)
//     .x_nav(expected_x_nav);      

//     runner.end();
//   }

//   #[test]
//   fun test_mint_x_coin() {
//     let mut runner = test_runner::start_and_mint_both();

//     runner.next_tx(@alice);

//     let initial_base_supply = runner.base_balance();
//     let initial_f_supply = runner.f_supply();
//     let initial_x_supply = runner.x_supply();
//     let base_in = 15 * PRECISION;
//     let price = 221 * (ORACLE_PRECISION / 100);  
      
//     let expected_base_nav = 221 * (PRECISION / 100);
//     let expected_f_multiple = 121 * (PRECISION / 1000);
//     let expected_f_nav = PRECISION + expected_f_multiple;

//     let expected_base_in = base_in.remove_fee(runner.x_standard_mint_fee());

//     let expected_x_value = test_runner::compute_x_mint_amount(
//       expected_base_in,
//       expected_base_nav,
//       initial_base_supply,
//       expected_f_nav,
//       initial_f_supply,
//       initial_x_supply
//     );
//     let expected_x_nav  = test_runner::compute_x_nav(
//       initial_base_supply + expected_base_in, 
//       expected_base_nav, 
//       initial_f_supply, 
//       expected_f_nav, 
//       initial_x_supply + expected_x_value
//     );

//     let (x_coin, i_coin) = runner.mint_x_coin(base_in, price, expected_x_value);

//     x_coin.assert_value(expected_x_value);
//     i_coin.assert_value(0);

//     let assert = assert_state::new(runner.state());    

//     assert
//     .base_supply(initial_base_supply + expected_base_in)
//     .base_nav(expected_base_nav)
//     .f_multiple(int::from_u64(expected_f_multiple))
//     .f_supply(initial_f_supply)
//     .f_nav(expected_f_nav)                                                  
//     .x_supply(initial_x_supply + expected_x_value)
//     .x_nav(expected_x_nav);   

//     runner.end();
//   }

//   #[test]
//   public fun test_redeem_f_coin() {
//     let mut runner = test_runner::start_and_mint_both();

//     runner.next_tx(@alice);

//     let base_in = 15 * PRECISION;
//     let price = 221 * (ORACLE_PRECISION / 100);  

//     let (x_coin, i_coin) = runner.mint_x_coin(base_in, price, 0);

//     runner
//     .destroy(x_coin)
//     .destroy(i_coin);

//     runner.next_tx(@alice);

//     let state = runner.state();

//     let base_supply = state.base_supply();
//     let base_nav = state.base_nav();

//     let f_supply = state.f_supply();
//     let f_nav = state.f_nav();
    
//     let x_nav = state.x_nav();
//     let x_supply = state.x_supply();
    
//     let f_amount_in = 10 * PRECISION;

//     let expected_i_sui_amount = math256::mul_div_down(f_amount_in.to_u256(), f_nav.to_u256(), base_nav.to_u256());

//     let i_sui = runner.redeem_f_coin(f_amount_in, price, 0);

//     i_sui.assert_value(expected_i_sui_amount.to_u64().remove_fee(runner.f_standard_redeem_fee()));

//     let assert = assert_state::new(runner.state());

//     assert
//     .base_supply(base_supply - expected_i_sui_amount.to_u64())
//     .base_nav(base_nav)
//     .f_multiple(state.f_multiple())
//     .f_supply(f_supply - f_amount_in)
//     .f_nav(f_nav)                                                  
//     .x_supply(x_supply)
//     .x_nav(x_nav);     

//     runner.end();
//   }

//   #[test]
//   public fun test_redeem_x_coin() {
//     let mut runner = test_runner::start_and_mint_both();

//     runner.next_tx(@alice);

//     let base_in = 15 * PRECISION;
//     let price = 221 * (ORACLE_PRECISION / 100);  

//     let (x_coin, i_coin) = runner.mint_x_coin(base_in, price, 0);

//     runner
//     .destroy(x_coin)
//     .destroy(i_coin);

//     runner.next_tx(@alice);

//     let state = runner.state();

//     let base_supply = state.base_supply();
//     let base_nav = state.base_nav();

//     let f_supply = state.f_supply();
//     let f_nav = state.f_nav();
    
//     let x_nav = state.x_nav();
//     let x_supply = state.x_supply();
    
//     let x_amount_in = 10 * PRECISION;

//     let x_value = test_runner::compute_x_value(base_supply, base_nav, f_supply, f_nav);
//     let expected_i_sui_amount = math256::mul_div_down(x_amount_in.to_u256(), x_value, x_supply.to_u256()) / base_nav.to_u256();

//     let i_sui = runner.redeem_x_coin(x_amount_in, price, 0);

//     i_sui.assert_value(expected_i_sui_amount.to_u64().remove_fee(runner.x_standard_redeem_fee()));

//     let assert = assert_state::new(runner.state());

//     assert
//     .base_supply(base_supply - expected_i_sui_amount.to_u64())
//     .base_nav(base_nav)
//     .f_multiple(state.f_multiple())
//     .f_supply(f_supply)
//     .f_nav(f_nav)                                                  
//     .x_supply(x_supply - x_amount_in)
//     .x_nav(x_nav);   

//     runner.end();
//   }  
// }