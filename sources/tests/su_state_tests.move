#[test_only]
module su::su_state_tests {
  
  use sui::test_utils::assert_eq;

  use suitears::int;

  use su::su_state;

  const PRECISION: u64 = 1_000_000_000;

  #[test]
  fun view_functions() {

    let base_supply = 100 * PRECISION;
    let base_nav = 2 * PRECISION;
    let f_multiple =int::from_u64(11 * PRECISION / 10);
    let f_supply = 20 * PRECISION;
    let f_nav = 11 * PRECISION / 10;
    let x_supply = 80 * PRECISION;
    let x_nav = 2225 * PRECISION / 1000;

    let state = su_state::new(
      base_supply,
      base_nav,
      f_multiple,
      f_supply,
      f_nav,
      x_supply,
      x_nav,
    );


    assert_eq(su_state::base_supply(state), base_supply);
    assert_eq(su_state::base_nav(state), base_nav);
    assert_eq(su_state::f_multiple(state), f_multiple);
    assert_eq(su_state::f_supply(state), f_supply);
    assert_eq(su_state::f_nav(state), f_nav);
    assert_eq(su_state::x_supply(state), x_supply);
    assert_eq(su_state::x_nav(state), x_nav);
  }
}