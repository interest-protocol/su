#[test_only]
module su_tests::vault_tests {

  use sui::test_utils::assert_eq;
  use sui::coin::burn_for_testing as burn;
  

  use su_tests::test_runner;
  
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

    assert_eq(burn(f_coin), 83500000000);
    assert_eq(burn(x_coin), 83500000000);

    test_runner::end(runner);
  }
}