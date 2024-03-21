#[test_only]
module su_tests::vault_tests {

  use sui::coin::Coin;
  
  use su_tests::test_runner;
  
  use fun test_runner::burn_coin as Coin.assert_value;

  const PRECISION: u64 = 1_000_000_000;
  const ORACLE_PRECISION: u256 = 1000000000000000000;

  #[test]
  fun test_mint_both() {
    let mut runner = test_runner::start();

    runner.next_tx(@alice);

    let (f_coin, x_coin) = runner.mint_both(
      100 * PRECISION,
      (167 * ORACLE_PRECISION) / 100,
      0,
      0
    );

    f_coin.assert_value(83500000000);
    x_coin.assert_value(83500000000);

    test_runner::end(runner);
  }
}