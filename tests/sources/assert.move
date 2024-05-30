#[test_only]
module su_tests::assert_state {

  use sui::test_utils::assert_eq;

  use su::su_state::SuState;

  use suitears::int::Int;

  public struct State has drop {
    state: SuState
  }

  public fun new(state: SuState): State {
    State {
      state
    }
  }

  public fun base_supply(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.base_supply(), value);
    self
  }

  public fun base_nav(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.base_nav(), value);
    self
  }

  public fun f_multiple(self: &State, value: Int): &State {
    let state = self.state;
    assert_eq(state.f_multiple(), value);
    self
  }

  public fun d_nav(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.d_nav(), value);
    self
  }

  public fun d_supply(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.d_supply(), value);
    self
  }

  public fun f_supply(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.f_supply(), value);
    self
  }

  public fun f_nav(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.f_nav(), value);
    self
  }

  public fun x_supply(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.x_supply(), value);
    self
  }  

  public fun x_nav(self: &State, value: u64): &State {
    let state = self.state;
    assert_eq(state.x_nav(), value);
    self
  }    
}