#[test_only]
module su_tests::test_runner {

  use sui::object;
  use sui::test_utils;
  use sui::clock::{Self, Clock};
  use sui::coin::{Self, Coin, TreasuryCap};
  use sui::test_scenario::{Self, Scenario, ctx};

  use su::treasury::Treasury;
  use su::vault::{Self, Vault};
  use su::f_sui::{Self, F_SUI};
  use su::x_sui::{Self, X_SUI};
  use su::i_sui::{Self, I_SUI, Treasury as ISuiTreasury};

  use suitears::oracle::{Self, Price};

  const BASE_CAP: u64 = 10000000000000000;

  public struct TestRunner { 
    clock: Clock,
    scenario: Scenario   
  }

  public fun start(): TestRunner {
    let mut scenario = test_scenario::begin(@alice);

    let scenario_mut = &mut scenario;

    let clock = clock::create_for_testing(ctx(scenario_mut));

    f_sui::init_for_testing(ctx(scenario_mut));
    x_sui::init_for_testing(ctx(scenario_mut));
    i_sui::init_for_testing(ctx(scenario_mut));

    test_scenario::next_tx(scenario_mut, @alice);

    let f_treasury_cap = test_scenario::take_from_sender<TreasuryCap<F_SUI>>(scenario_mut);
    let x_treasury_cap = test_scenario::take_from_sender<TreasuryCap<X_SUI>>(scenario_mut);
    let genesis_price = new_price(1000000000000000000);

    vault::share_genesis_state(
      f_treasury_cap,
      x_treasury_cap,
      &clock,
      genesis_price,
      BASE_CAP,
      ctx(scenario_mut)
    );

    let runner = TestRunner {
      clock,
      scenario
    };

    runner
  }

  public fun next_tx(self: &mut TestRunner, sender: address): &mut TestRunner {
    test_scenario::next_tx(&mut self.scenario, sender);
    self
  }

  public fun set_time(self: &mut TestRunner, time: u64): &mut TestRunner {
    self.clock.set_for_testing(time);

    self
  }

  public fun mint_i_sui(self: &mut TestRunner, amount: u64): Coin<I_SUI> {
    let mut treasury = test_scenario::take_shared<ISuiTreasury>(&self.scenario);

    let i_sui = i_sui::mint(&mut treasury, amount, ctx(&mut self.scenario));

    test_scenario::return_shared(treasury);

    i_sui
  }

  public fun destroy<T>(self: &mut TestRunner, v: T): &mut TestRunner {
    test_utils::destroy(v);
    self
  }

  public fun mint_both(
    self: &mut TestRunner, 
    base_in: u64, 
    oracle_price: u256,  
    min_f_coin_amount: u64, 
    min_x_coin_amount: u64
  ): (Coin<F_SUI>, Coin<X_SUI>) {
    let vault = test_scenario::take_shared<Vault>(&self.scenario);
    let mut treasury = test_scenario::take_shared<Treasury>(&self.scenario);

    let i_sui = mint_i_sui(self, base_in);

    let (f_sui, x_sui) = vault::mint_both(
      &vault,
      &mut treasury,
      &self.clock,
      i_sui,
      new_price(oracle_price),
      min_f_coin_amount,
      min_x_coin_amount,
      ctx(&mut self.scenario)
    );
    
    test_scenario::return_shared(treasury);
    test_scenario::return_shared(vault);

    (f_sui, x_sui)
  }

  public fun end(self: TestRunner) {
    test_utils::destroy(self);
  }

  public fun burn_coin<T>(coin_in: Coin<T>, value: u64) {
    test_utils::assert_eq(coin::burn_for_testing(coin_in), value);
  }

  fun new_price(oracle_price: u256): Price {
    oracle::new_price_for_testing(
      object::id_from_address(@oracle),
      oracle_price,
      18,
      0
    )
  }
}