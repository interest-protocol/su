#[test_only]
module su_tests::vault_tests {

  use sui::coin::Coin;
  
  use suitears::int;

  use su_tests::test_runner;
  use su_tests::assert_state;
  
  use fun test_runner::burn_coin as Coin.assert_value;

  const PRECISION: u64 = 1_000_000_000;
  const ORACLE_PRECISION: u256 = 1000000000000000000;

  #[test]
  fun test_mint_both() {
    let mut runner = test_runner::start();

    runner.next_tx(@alice);

    let initial_supply = 50000000000;
    let base_supply = 100 * PRECISION;

    let (f_coin, x_coin) = runner.mint_both(
      base_supply,
      ORACLE_PRECISION,
      0,
      0
    );

    f_coin.assert_value(initial_supply);
    x_coin.assert_value(initial_supply);

    runner.next_tx(@alice);

    let assert = assert_state::new(runner.state());

    assert
    .base_supply(base_supply)
    .base_nav(PRECISION)
    .f_multiple(int::zero())
    .f_supply(initial_supply)
    .f_nav(PRECISION)                                                  
    .x_supply(initial_supply)
    .x_nav(PRECISION);   

    runner.end();
  }

  #[test]
  fun test_mint_f_coin() {
    let mut runner = test_runner::start_and_mint_both();

    runner.next_tx(@alice);

    let base_in = 5 * PRECISION;
    let price = 167 * (ORACLE_PRECISION / 100);

    let f_coin = runner.mint_f_coin(base_in, price, 0);

    f_coin.assert_value(7684395499);

    runner.next_tx(@alice);

    let state = runner.state();

    let assert = assert_state::new(state);

    // let expected_f_coin_value = 7684395499;
    // let expected_base_supply = 1;

    // assert
    // .base_supply(base_supply)
    // .base_nav(PRECISION)
    // .f_multiple(int::zero())
    // .f_supply(initial_supply)
    // .f_nav(PRECISION)                                                  
    // .x_supply(initial_supply)
    // .x_nav(PRECISION);      

    runner.end();
  }
}