#[test_only]
module ampere_vault::orbital_vault_integration_tests;

use std::unit_test;
use sui::clock::{Self, Clock};
use sui::coin::{create_treasury_cap_for_testing, mint_for_testing};
use sui::test_scenario::{Scenario, begin, end, return_shared, take_shared, take_shared_by_id};
use deepbook::balance_manager;
use deepbook::constants;
use deepbook::pool::{Self, Pool};
use deepbook::registry;
use ampere_vault::orbital_vault::{
  OrbitalTickConfig,
  OrbitalVault,
  TradingCap,
  create_orbital_vault,
  generate_trade_proof,
  new_tick_config,
  place_orbital_orders,
  test_seed_balances,
};

public struct BASE has drop, store {}
public struct QUOTE has drop, store {}
public struct LP has drop, store {}

const OWNER: address = @0x1;
const E_EXPIRED: u64 = 7;
const E_ORDER_TOO_SMALL: u64 = 3;
const E_INSUFFICIENT_BASE: u64 = 11;

#[test]
fun test_place_orbital_orders_success() {
  let mut test = begin(OWNER);

  setup_clock(&mut test);
  let registry_id = setup_registry(&mut test);
  let pool_id = setup_pool<BASE, QUOTE>(registry_id, &mut test);
  seed_mid_price<BASE, QUOTE>(pool_id, &mut test);

  create_vault<BASE, QUOTE, LP>(pool_id, &mut test);
  seed_vault_balances<BASE, QUOTE, LP>(&mut test);

  test.next_tx(OWNER);
  let clock = test.take_shared<Clock>();
  let mut pool = take_shared_by_id<Pool<BASE, QUOTE>>(&test, pool_id);
  let mut vault = take_shared<OrbitalVault<BASE, QUOTE, LP>>(&test);
  let cap = test.take_from_sender<TradingCap>();
  let trade_proof = generate_trade_proof<BASE, QUOTE, LP>(&cap, &mut vault, test.ctx());

  place_orbital_orders<BASE, QUOTE, LP>(
    &cap,
    &mut vault,
    &trade_proof,
    &mut pool,
    100,
    constants::no_restriction(),
    constants::self_matching_allowed(),
    false,
    constants::max_u64(),
    &clock,
    test.ctx()
  );

  test.return_to_sender(cap);
  return_shared(vault);
  return_shared(pool);
  return_shared(clock);
  end(test);
}

#[test, expected_failure(abort_code = E_EXPIRED, location = ampere_vault::orbital_vault)]
fun test_place_orbital_orders_expired() {
  let mut test = begin(OWNER);

  setup_clock(&mut test);
  let registry_id = setup_registry(&mut test);
  let pool_id = setup_pool<BASE, QUOTE>(registry_id, &mut test);
  seed_mid_price<BASE, QUOTE>(pool_id, &mut test);

  create_vault<BASE, QUOTE, LP>(pool_id, &mut test);
  seed_vault_balances<BASE, QUOTE, LP>(&mut test);

  test.next_tx(OWNER);
  let clock = test.take_shared<Clock>();
  let mut pool = take_shared_by_id<Pool<BASE, QUOTE>>(&test, pool_id);
  let mut vault = take_shared<OrbitalVault<BASE, QUOTE, LP>>(&test);
  let cap = test.take_from_sender<TradingCap>();
  let trade_proof = generate_trade_proof<BASE, QUOTE, LP>(&cap, &mut vault, test.ctx());

  place_orbital_orders<BASE, QUOTE, LP>(
    &cap,
    &mut vault,
    &trade_proof,
    &mut pool,
    100,
    constants::no_restriction(),
    constants::self_matching_allowed(),
    false,
    clock.timestamp_ms(),
    &clock,
    test.ctx()
  );

  test.return_to_sender(cap);
  return_shared(vault);
  return_shared(pool);
  return_shared(clock);
  end(test);
}

#[test, expected_failure(abort_code = E_ORDER_TOO_SMALL, location = ampere_vault::orbital_vault)]
fun test_place_orbital_orders_too_small() {
  let mut test = begin(OWNER);

  setup_clock(&mut test);
  let registry_id = setup_registry(&mut test);
  let pool_id = setup_pool<BASE, QUOTE>(registry_id, &mut test);
  seed_mid_price<BASE, QUOTE>(pool_id, &mut test);

  create_vault<BASE, QUOTE, LP>(pool_id, &mut test);
  seed_vault_balances<BASE, QUOTE, LP>(&mut test);

  test.next_tx(OWNER);
  let clock = test.take_shared<Clock>();
  let mut pool = take_shared_by_id<Pool<BASE, QUOTE>>(&test, pool_id);
  let mut vault = take_shared<OrbitalVault<BASE, QUOTE, LP>>(&test);
  let cap = test.take_from_sender<TradingCap>();
  let trade_proof = generate_trade_proof<BASE, QUOTE, LP>(&cap, &mut vault, test.ctx());

  // order_size_lots < min_lots * tick_count (min_lots is 10, tick_count is 2)
  place_orbital_orders<BASE, QUOTE, LP>(
    &cap,
    &mut vault,
    &trade_proof,
    &mut pool,
    10,
    constants::no_restriction(),
    constants::self_matching_allowed(),
    false,
    constants::max_u64(),
    &clock,
    test.ctx()
  );

  test.return_to_sender(cap);
  return_shared(vault);
  return_shared(pool);
  return_shared(clock);
  end(test);
}

#[test, expected_failure(abort_code = E_INSUFFICIENT_BASE, location = ampere_vault::orbital_vault)]
fun test_place_orbital_orders_insufficient_base() {
  let mut test = begin(OWNER);

  setup_clock(&mut test);
  let registry_id = setup_registry(&mut test);
  let pool_id = setup_pool<BASE, QUOTE>(registry_id, &mut test);
  seed_mid_price<BASE, QUOTE>(pool_id, &mut test);

  create_vault<BASE, QUOTE, LP>(pool_id, &mut test);

  test.next_tx(OWNER);
  let clock = test.take_shared<Clock>();
  let mut pool = take_shared_by_id<Pool<BASE, QUOTE>>(&test, pool_id);
  let mut vault = take_shared<OrbitalVault<BASE, QUOTE, LP>>(&test);
  let cap = test.take_from_sender<TradingCap>();
  let trade_proof = generate_trade_proof<BASE, QUOTE, LP>(&cap, &mut vault, test.ctx());

  place_orbital_orders<BASE, QUOTE, LP>(
    &cap,
    &mut vault,
    &trade_proof,
    &mut pool,
    100,
    constants::no_restriction(),
    constants::self_matching_allowed(),
    false,
    constants::max_u64(),
    &clock,
    test.ctx()
  );

  test.return_to_sender(cap);
  return_shared(vault);
  return_shared(pool);
  return_shared(clock);
  end(test);
}

fun setup_clock(test: &mut Scenario) {
  test.next_tx(OWNER);
  clock::create_for_testing(test.ctx()).share_for_testing();
}

fun setup_registry(test: &mut Scenario): ID {
  test.next_tx(OWNER);
  registry::test_registry(test.ctx())
}

fun setup_pool<BaseAsset, QuoteAsset>(registry_id: ID, test: &mut Scenario): ID {
  test.next_tx(OWNER);

  let admin_cap = registry::get_admin_cap_for_testing(test.ctx());
  let mut registry = take_shared_by_id<registry::Registry>(test, registry_id);
  let pool_id = pool::create_pool_admin<BaseAsset, QuoteAsset>(
    &mut registry,
    constants::tick_size(),
    constants::lot_size(),
    constants::min_size(),
    false,
    false,
    &admin_cap,
    test.ctx()
  );

  return_shared(registry);
  unit_test::destroy(admin_cap);

  pool_id
}

fun seed_mid_price<BaseAsset, QuoteAsset>(pool_id: ID, test: &mut Scenario) {
  test.next_tx(OWNER);

  let clock = test.take_shared<Clock>();
  let mut pool = take_shared_by_id<Pool<BaseAsset, QuoteAsset>>(test, pool_id);
  let mut bm = balance_manager::new(test.ctx());

  bm.deposit<BaseAsset>(mint_for_testing<BaseAsset>(1_000_000_000, test.ctx()), test.ctx());
  bm.deposit<QuoteAsset>(mint_for_testing<QuoteAsset>(1_000_000_000_000, test.ctx()), test.ctx());

  let trade_proof = balance_manager::generate_proof_as_owner(&mut bm, test.ctx());

  pool::place_limit_order<BaseAsset, QuoteAsset>(
    &mut pool,
    &mut bm,
    &trade_proof,
    0,
    constants::no_restriction(),
    constants::self_matching_allowed(),
    1_000_000,
    constants::min_size(),
    true,
    false,
    constants::max_u64(),
    &clock,
    test.ctx()
  );

  pool::place_limit_order<BaseAsset, QuoteAsset>(
    &mut pool,
    &mut bm,
    &trade_proof,
    0,
    constants::no_restriction(),
    constants::self_matching_allowed(),
    1_100_000,
    constants::min_size(),
    false,
    false,
    constants::max_u64(),
    &clock,
    test.ctx()
  );

  return_shared(pool);
  return_shared(clock);
  transfer::public_share_object(bm);
}

fun create_vault<BaseAsset, QuoteAsset, Lp>(pool_id: ID, test: &mut Scenario) {
  test.next_tx(OWNER);

  let lp_cap = create_treasury_cap_for_testing<Lp>(test.ctx());
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 6000));
  vector::push_back(&mut ticks, new_tick_config(150, 4000));

  let cap = create_orbital_vault<BaseAsset, QuoteAsset, Lp>(
    lp_cap,
    vector::empty<u8>(),
    vector::empty<u8>(),
    pool_id,
    ticks,
    0,
    test.ctx()
  );

  transfer::public_transfer(cap, OWNER);
}

fun seed_vault_balances<BaseAsset, QuoteAsset, Lp>(test: &mut Scenario) {
  test.next_tx(OWNER);

  let mut vault = take_shared<OrbitalVault<BaseAsset, QuoteAsset, Lp>>(test);
  test_seed_balances<BaseAsset, QuoteAsset, Lp>(
    &mut vault,
    mint_for_testing<BaseAsset>(1_000_000_000, test.ctx()),
    mint_for_testing<QuoteAsset>(1_000_000_000_000, test.ctx()),
    test.ctx()
  );

  return_shared(vault);
}
