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
}