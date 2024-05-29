// #[test_only]
// module su_tests::assert_state {

//   use sui::test_utils::assert_eq;

//   use su::su_state::{Self, SuState};

//   use suitears::int::Int;

//   public struct State has drop {
//     state: SuState
//   }

//   public fun new(state: SuState): State {
//     State {
//       state
//     }
//   }

//   public fun base_supply(self: &State, value: u64): &State {
//     let state = self.state;
//     assert_eq(su_state::base_supply(state), value);
//     self
//   }

//   public fun base_nav(self: &State, value: u64): &State {
//     let state = self.state;
//     assert_eq(su_state::base_nav(state), value);
//     self
//   }

//   public fun f_multiple(self: &State, value: Int): &State {
//     let state = self.state;
//     assert_eq(su_state::f_multiple(state), value);
//     self
//   }

//   public fun f_supply(self: &State, value: u64): &State {
//     let state = self.state;
//     assert_eq(su_state::f_supply(state), value);
//     self
//   }

//   public fun f_nav(self: &State, value: u64): &State {
//     let state = self.state;
//     assert_eq(su_state::f_nav(state), value);
//     self
//   }

//   public fun x_supply(self: &State, value: u64): &State {
//     let state = self.state;
//     assert_eq(su_state::x_supply(state), value);
//     self
//   }  

//   public fun x_nav(self: &State, value: u64): &State {
//     let state = self.state;
//     assert_eq(su_state::x_nav(state), value);
//     self
//   }    
// }