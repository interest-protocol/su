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
  use su::su_state::{Self, SuState};
  use su::i_sui::{Self, I_SUI, Treasury as ISuiTreasury};

  use suitears::math64;
  use suitears::oracle::{Self, Price};

  const BASE_CAP: u64 = 10000000000000000;
  const PRECISION: u64 = 1_000_000_000;
  const GENESIS_PRICE: u256 = 1000000000000000000;

  public struct TestRunner { 
    clock: Clock,
    scenario: Scenario,
    vault: Vault,
    treasury: Treasury,
    i_sui_treasury: ISuiTreasury   
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
    let genesis_price = new_price(GENESIS_PRICE);

    vault::share_genesis_state(
      f_treasury_cap,
      x_treasury_cap,
      &clock,
      genesis_price,
      BASE_CAP,
      ctx(scenario_mut)
    );

    test_scenario::next_tx(scenario_mut, @alice);

    let vault = test_scenario::take_shared<Vault>(scenario_mut);
    let treasury = test_scenario::take_shared<Treasury>(scenario_mut);
    let i_sui_treasury = test_scenario::take_shared<ISuiTreasury>(scenario_mut);

    let runner = TestRunner {
      clock,
      scenario,
      vault,
      treasury,
      i_sui_treasury
    };

    runner
  }

  public fun start_and_mint_both(): TestRunner {
    let mut runner = start();

    runner.next_tx(@alice);

    let (x, y) = mint_both(&mut runner, 100 * PRECISION, GENESIS_PRICE, 0, 0);

    test_utils::destroy(x);
    test_utils::destroy(y);

    runner
  }

  public fun state(self: &mut TestRunner): SuState {

    let treasury_mut = &mut self.treasury;
    let vault = &self.vault;

    su_state::new(
      vault::base_supply(treasury_mut),
      vault::base_nav(vault, treasury_mut),
      vault::f_multiple(vault, treasury_mut),
      vault::f_supply(treasury_mut),
      vault::f_nav(vault, treasury_mut),
      vault::x_supply(treasury_mut),
      vault::x_nav(vault, treasury_mut)
    )
  }

  public fun next_tx(self: &mut TestRunner, sender: address): &mut TestRunner {
    test_scenario::next_tx(&mut self.scenario, sender);
    self
  }

  public fun set_time(self: &mut TestRunner, time: u64): &mut TestRunner {
    self.clock.set_for_testing(time);

    self
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

    let i_sui = mint_i_sui(self, base_in);

    vault::mint_both(
      &mut self.vault,
      &mut self.treasury,
      &self.clock,
      i_sui,
      new_price(oracle_price),
      min_f_coin_amount,
      min_x_coin_amount,
      ctx(&mut self.scenario)
    )
  }

  public fun mint_f_coin(
    self: &mut TestRunner,
    base_in: u64,
    oracle_price: u256,
    min_f_coin_amount: u64, 
  ): Coin<F_SUI> {
    let i_sui = mint_i_sui(self, base_in);

    self.vault.mint_f_coin(
      &mut self.treasury,
      &self.clock,
      i_sui,
      new_price(oracle_price),
      min_f_coin_amount,
      ctx(&mut self.scenario)
    )
  }

  public fun mint_x_coin(
    self: &mut TestRunner,
    base_in: u64,
    oracle_price: u256,
    min_x_coin_amount: u64,         
  ): (Coin<X_SUI>, Coin<I_SUI>) {
    let i_sui = mint_i_sui(self, base_in);

    self.vault.mint_x_coin(
      &mut self.treasury,
      &self.clock,
      i_sui,
      new_price(oracle_price),
      min_x_coin_amount,
      ctx(&mut self.scenario)
    )
  }

  public fun f_standard_mint_fee(self: &TestRunner): u64 {
    vault::f_standard_mint_fee(&self.vault)
  }

  public fun f_stability_mint_fee(self: &TestRunner): u64 {
    vault::f_stability_mint_fee(&self.vault)
  }

  public fun f_standard_redeem_fee(self: &TestRunner): u64 {
    vault::f_standard_redeem_fee(&self.vault)
  }

  public fun f_stability_redeem_fee(self: &TestRunner): u64 {
    vault::f_stability_redeem_fee(&self.vault)
  }  

  public fun x_standard_mint_fee(self: &TestRunner): u64 {
    vault::x_standard_mint_fee(&self.vault)
  }

  public fun x_stability_mint_fee(self: &TestRunner): u64 {
    vault::x_stability_mint_fee(&self.vault)
  }

  public fun x_standard_redeem_fee(self: &TestRunner): u64 {
    vault::x_standard_redeem_fee(&self.vault)
  }

  public fun x_stability_redeem_fee(self: &TestRunner): u64 {
    vault::x_stability_redeem_fee(&self.vault)    
  }  

  public fun stability_collateral_ratio(self: &TestRunner): u64 {
    vault::stability_collateral_ratio(&self.vault)       
  }  

  public fun rebalance_collateral_ratio(self: &TestRunner): u64 {
    vault::rebalance_collateral_ratio(&self.vault)    
  }    

  public fun f_supply(self: &mut TestRunner): u64 {
    vault::f_supply(&mut self.treasury)
  }

  public fun x_supply(self: &mut TestRunner): u64 {
    vault::x_supply(&mut self.treasury)
  }  

  public fun reserve_fee(self: &mut TestRunner): u64 {
    vault::reserve_fee(&mut self.treasury)       
  }

  public fun rebalance_fee(self: &mut TestRunner): u64 {
    vault::rebalance_fee(&mut self.treasury)        
  }  

  public fun last_f_nav(self: &mut TestRunner): u64 {
    vault::last_f_nav(&mut self.treasury)       
  }

  public fun genesis_price(self: &mut TestRunner): u64 {
    vault::genesis_price(&mut self.treasury)  
  }  

  public fun base_balance_cap(self: &mut TestRunner): u64 {
    vault::base_balance_cap(&mut self.treasury) 
  }    

  public fun base_balance(self: &mut TestRunner): u64 {
    vault::base_balance(&mut self.treasury)     
  }    

  public fun reserve_balance(self: &mut TestRunner): u64 {
    vault::reserve_balance(&mut self.treasury) 
  }   

  public fun rebalance_balance(self: &mut TestRunner): u64 {
    vault::rebalance_balance(&mut self.treasury) 
  }   

  public fun burn_coin<T>(coin_in: Coin<T>, value: u64) {
    test_utils::assert_eq(coin::burn_for_testing(coin_in), value);
  }

  public fun compute_x_nav(base_supply: u64, base_nav: u64, f_supply: u64, f_nav: u64, x_supply: u64): u64 {
    let (
      base_supply,
      base_nav,
      f_supply,
      f_nav,
      x_supply
    ) = (
      (base_supply as u256),
      (base_nav as u256),
      (f_supply as u256),
      (f_nav as u256),
      (x_supply as u256),
    );

    (((base_supply * base_nav - (f_supply * f_nav)) / x_supply) as u64) 
  }

  public fun compute_x_mint_amount(
    base_in: u64,
    base_nav: u64,
    base_supply: u64,
    f_nav: u64,
    f_supply: u64,
    x_supply: u64
  ): u64 {
    let (
      base_in,
      base_nav,
      base_supply,
      f_nav,
      f_supply,
      x_supply
    ) = (
      (base_in as u256),
      (base_nav as u256),
      (base_supply as u256),
      (f_nav as u256),
      (f_supply as u256),
      (x_supply as u256),
    );  

    ((base_in * base_nav * x_supply / (
      (base_supply * base_nav) - 
      (f_supply * f_nav)
    )) as u64)
  }

  public fun remove_fee(base_in: u64, fee: u64): u64 {
    base_in - math64::mul_div_up(base_in, fee, PRECISION)
  }

  public fun end(self: TestRunner) {
    test_utils::destroy(self);
  }

  fun mint_i_sui(self: &mut TestRunner, amount: u64): Coin<I_SUI> {
    i_sui::mint(&mut self.i_sui_treasury, amount, ctx(&mut self.scenario))
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