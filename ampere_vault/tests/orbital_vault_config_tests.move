#[test_only]
module ampere_vault::orbital_vault_config_tests;

use ampere_vault::orbital_vault::{OrbitalTickConfig, new_tick_config, test_validate_config, test_allocate_tick_lots};

const E_INVALID_WEIGHTS: u64 = 5;
const E_INVALID_BAND_ORDER: u64 = 10;

#[test]
fun test_validate_config_ok() {
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 6000));
  vector::push_back(&mut ticks, new_tick_config(150, 4000));

  test_validate_config(ticks, 25);
}

#[test, expected_failure(abort_code = E_INVALID_WEIGHTS, location = ampere_vault::orbital_vault)]
fun test_validate_config_bad_weights() {
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 5000));
  vector::push_back(&mut ticks, new_tick_config(150, 4000));

  test_validate_config(ticks, 25);
}

#[test, expected_failure(abort_code = E_INVALID_BAND_ORDER, location = ampere_vault::orbital_vault)]
fun test_validate_config_bad_band_order() {
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(150, 5000));
  vector::push_back(&mut ticks, new_tick_config(50, 5000));

  test_validate_config(ticks, 25);
}

#[test]
fun test_allocate_tick_lots_weighted() {
  let mut ticks = vector::empty<OrbitalTickConfig>();
  vector::push_back(&mut ticks, new_tick_config(50, 6000));
  vector::push_back(&mut ticks, new_tick_config(150, 4000));

  let sizes = test_allocate_tick_lots(100, 10, ticks);
  let first = *vector::borrow(&sizes, 0);
  let second = *vector::borrow(&sizes, 1);

  // 10 lots per tick minimum + weighted remainder allocation
  assert!(first == 58, 0);
  assert!(second == 42, 0);
}
