#[test_only]
module ampere_vault::orbital_pool3_tests;

use sui::coin::{Self, create_treasury_cap_for_testing, mint_for_testing, burn_for_testing};
use sui::test_scenario::{Scenario, begin, end, return_shared, take_shared_by_id};
use ampere_vault::orbital_pool3::{
  OrbitalPool3,
  OrbitalTickConfig,
  add_liquidity,
  create_pool3,
  get_l_squared,
  get_reserves,
  get_tick_count,
  get_tick_reserves,
  get_tick_weights,
  lp_total_supply,
  new_tick_config,
  quote_a_for_b_exact_in,
  quote_a_for_b_exact_out,
  remove_liquidity,
  swap_a_for_b_exact_in,
  swap_a_for_b_exact_out,
  swap_a_for_c_exact_in,
  test_burn_lp,
};

public struct A has drop, store {}
public struct B has drop, store {}
public struct C has drop, store {}
public struct LP has drop, store {}

const OWNER: address = @0x1;
const MIN_LP_LOCK: u64 = 1000;
const E_INSUFFICIENT_LIQ: u64 = 1;
const E_INVALID_WEIGHTS: u64 = 6;
const E_INVALID_BAND_ORDER: u64 = 8;

#[test]
fun test_add_liquidity_initial() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);

  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );

  let expected = 3_000_000 - MIN_LP_LOCK;
  assert!(coin::value(&lp) == expected, 0);
  assert!(lp_total_supply(&pool) == 3_000_000, 0);

  test_burn_lp(&mut pool, lp);
  return_shared(pool);
  end(test);
}

#[test]
fun test_add_liquidity_proportional() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp1 = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(2_000_000, test.ctx()),
    mint_for_testing<C>(3_000_000, test.ctx()),
    test.ctx()
  );
  return_shared(pool);

  test.next_tx(OWNER);
  let mut pool2 = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);

  let lp2 = add_liquidity<A, B, C, LP>(
    &mut pool2,
    mint_for_testing<A>(500_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_500_000, test.ctx()),
    test.ctx()
  );

  // proportional: second deposit is exactly half of first, so shares should be half
  let expected = 3_000_000;
  assert!(coin::value(&lp2) == expected, 0);

  test_burn_lp(&mut pool2, lp1);
  test_burn_lp(&mut pool2, lp2);
  return_shared(pool2);
  end(test);
}

#[test]
fun test_remove_liquidity() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let mut lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );

  let half = coin::value(&lp) / 2;
  let lp_half = coin::split(&mut lp, half, test.ctx());

  let (out_a, out_b, out_c) = remove_liquidity<A, B, C, LP>(&mut pool, lp_half, test.ctx());
  assert!(coin::value(&out_a) > 0, 0);
  assert!(coin::value(&out_b) > 0, 0);
  assert!(coin::value(&out_c) > 0, 0);

  burn_for_testing(out_a);
  burn_for_testing(out_b);
  burn_for_testing(out_c);
  test_burn_lp(&mut pool, lp);
  return_shared(pool);
  end(test);
}

#[test]
fun test_tick_distribution_after_add_liquidity() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000, test.ctx()),
    mint_for_testing<B>(1_000, test.ctx()),
    mint_for_testing<C>(1_000, test.ctx()),
    test.ctx()
  );

  let reserves = get_tick_reserves(&pool);
  let a0 = *vector::borrow(&reserves, 0);
  let b0 = *vector::borrow(&reserves, 1);
  let c0 = *vector::borrow(&reserves, 2);
  let a1 = *vector::borrow(&reserves, 3);
  let b1 = *vector::borrow(&reserves, 4);
  let c1 = *vector::borrow(&reserves, 5);

  assert!(a0 == 600 && b0 == 600 && c0 == 600, 0);
  assert!(a1 == 400 && b1 == 400 && c1 == 400, 0);

  test_burn_lp(&mut pool, lp);
  return_shared(pool);
  end(test);
}

#[test]
fun test_swap_exact_in_ab() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );
  test_burn_lp(&mut pool, lp);

  let fee = 10_000 * 1000 / 1_000_000;
  let expected = quote_a_for_b_exact_in(&pool, 10_000 - fee);
  let out = swap_a_for_b_exact_in<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(10_000, test.ctx()),
    test.ctx()
  );

  let l_after = get_l_squared(&pool);
  assert!(coin::value(&out) == expected, 0);
  assert!(l_after > 0, 0);

  burn_for_testing(out);
  return_shared(pool);
  end(test);
}

#[test]
fun test_swap_exact_out_ab() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );
  test_burn_lp(&mut pool, lp);

  let amount_out = 5_000;
  let raw_in = quote_a_for_b_exact_out(&pool, amount_out);
  let expected_in = raw_in * 1_000_000 / (1_000_000 - 1000) + 1;

  let (out, refund) = swap_a_for_b_exact_out<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(expected_in + 10, test.ctx()),
    amount_out,
    test.ctx()
  );

  assert!(coin::value(&out) == amount_out, 0);
  assert!(coin::value(&refund) == 10, 0);

  burn_for_testing(out);
  burn_for_testing(refund);
  return_shared(pool);
  end(test);
}

#[test]
fun test_swap_exact_in_ac() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );
  test_burn_lp(&mut pool, lp);

  let out = swap_a_for_c_exact_in<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(20_000, test.ctx()),
    test.ctx()
  );

  assert!(coin::value(&out) > 0, 0);
  burn_for_testing(out);
  return_shared(pool);
  end(test);
}

#[test]
fun test_tick_weights_and_count() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);

  assert!(get_tick_count(&pool) == 2, 0);
  let weights = get_tick_weights(&pool);
  assert!(*vector::borrow(&weights, 0) == 6000, 0);
  assert!(*vector::borrow(&weights, 1) == 4000, 0);

  return_shared(pool);
  end(test);
}

#[test]
fun test_swap_spreads_across_ticks() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool_equal_weights(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );
  test_burn_lp(&mut pool, lp);

  let reserves_before = get_tick_reserves(&pool);
  let out = swap_a_for_b_exact_in<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(10_000, test.ctx()),
    test.ctx()
  );

  let reserves_after = get_tick_reserves(&pool);
  assert!(*vector::borrow(&reserves_after, 0) > *vector::borrow(&reserves_before, 0), 0);
  assert!(*vector::borrow(&reserves_after, 3) > *vector::borrow(&reserves_before, 3), 0);

  burn_for_testing(out);
  return_shared(pool);
  end(test);
}

#[test, expected_failure(abort_code = E_INSUFFICIENT_LIQ, location = ampere_vault::orbital_pool3)]
fun test_swap_exact_out_insufficient_liquidity() {
  let mut test = begin(OWNER);
  let pool_id = setup_pool(&mut test);

  test.next_tx(OWNER);
  let mut pool = take_shared_by_id<OrbitalPool3<A, B, C, LP>>(&test, pool_id);
  let lp = add_liquidity<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(1_000_000, test.ctx()),
    mint_for_testing<B>(1_000_000, test.ctx()),
    mint_for_testing<C>(1_000_000, test.ctx()),
    test.ctx()
  );
  burn_for_testing(lp);

  let (_a, b, _c) = get_reserves(&pool);
  let (out, refund) = swap_a_for_b_exact_out<A, B, C, LP>(
    &mut pool,
    mint_for_testing<A>(b, test.ctx()),
    b + 1,
    test.ctx()
  );
  burn_for_testing(out);
  burn_for_testing(refund);

  return_shared(pool);
  end(test);
}

#[test, expected_failure(abort_code = E_INVALID_WEIGHTS, location = ampere_vault::orbital_pool3)]
fun test_invalid_tick_weights() {
  let mut test = begin(OWNER);
  test.next_tx(OWNER);
  let cap = create_treasury_cap_for_testing<LP>(test.ctx());
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 6000));
  vector::push_back(&mut ticks, new_tick_config(100, 3000));
  create_pool3<A, B, C, LP>(cap, 18, 18, 18, ticks, test.ctx());
  end(test);
}

#[test, expected_failure(abort_code = E_INVALID_BAND_ORDER, location = ampere_vault::orbital_pool3)]
fun test_invalid_tick_band_order() {
  let mut test = begin(OWNER);
  test.next_tx(OWNER);
  let cap = create_treasury_cap_for_testing<LP>(test.ctx());
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(100, 5000));
  vector::push_back(&mut ticks, new_tick_config(50, 5000));
  create_pool3<A, B, C, LP>(cap, 18, 18, 18, ticks, test.ctx());
  end(test);
}

fun setup_pool(test: &mut Scenario): ID {
  test.next_tx(OWNER);
  let cap = create_treasury_cap_for_testing<LP>(test.ctx());
  create_pool3<A, B, C, LP>(cap, 18, 18, 18, default_ticks(), test.ctx())
}

fun setup_pool_equal_weights(test: &mut Scenario): ID {
  test.next_tx(OWNER);
  let cap = create_treasury_cap_for_testing<LP>(test.ctx());
  create_pool3<A, B, C, LP>(cap, 18, 18, 18, equal_ticks(), test.ctx())
}

fun default_ticks(): vector<OrbitalTickConfig> {
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 6000));
  vector::push_back(&mut ticks, new_tick_config(100, 4000));
  ticks
}

fun equal_ticks(): vector<OrbitalTickConfig> {
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 5000));
  vector::push_back(&mut ticks, new_tick_config(100, 5000));
  ticks
}
