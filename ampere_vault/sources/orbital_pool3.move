module ampere_vault::orbital_pool3;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::event;

/// === Constants ===
const FEE_DENOMINATOR: u64 = 1_000_000;
const LP_FEE: u64 = 1000; // 0.1%
const MIN_LP_LOCK: u64 = 1000;
const R: u256 = 1000000_000000000000000000000000u256; // 1_000_000e18
const BPS: u64 = 10000;

/// === Errors ===
const EZeroShares: u64 = 0;
const EInsufficientLiquidity: u64 = 1;
const EInvariantViolation: u64 = 2;
const EReservesExceedRadius: u64 = 3;
const EMathError: u64 = 4;
const EInvalidDecimals: u64 = 5;
const EInvalidWeights: u64 = 6;
const EInvalidBand: u64 = 7;
const EInvalidBandOrder: u64 = 8;
const EZeroTicks: u64 = 9;

/// Event emitted when liquidity is added
public struct LiquidityAdded has copy, drop {
  provider: address,
  amount_a: u64,
  amount_b: u64,
  amount_c: u64,
  shares: u64
}

/// Event emitted when liquidity is removed
public struct LiquidityRemoved has copy, drop {
  provider: address,
  amount_a: u64,
  amount_b: u64,
  amount_c: u64,
  shares: u64
}

/// Event emitted for swaps
public struct SwapEvent has copy, drop {
  sender: address,
  amount_in: u64,
  amount_out: u64
}

/// Tick config
public struct OrbitalTickConfig has copy, drop, store {
  band_bps: u64,
  weight_bps: u64
}

/// Internal tick state
public struct OrbitalTick<phantom A, phantom B, phantom C> has store {
  band_bps: u64,
  weight_bps: u64,
  balance_a: Balance<A>,
  balance_b: Balance<B>,
  balance_c: Balance<C>,
  l_squared: u256
}

/// Orbital 3-asset pool with ticks
public struct OrbitalPool3<phantom A, phantom B, phantom C, phantom LP> has key, store {
  id: UID,
  lp_treasury_cap: TreasuryCap<LP>,
  ticks: vector<OrbitalTick<A, B, C>>,
  decimals_a: u8,
  decimals_b: u8,
  decimals_c: u8,
  locked_lp_balance: Balance<LP>
}

public fun new_tick_config(band_bps: u64, weight_bps: u64): OrbitalTickConfig {
  OrbitalTickConfig { band_bps, weight_bps }
}

/// Creates and shares a new orbital pool object
public fun create_pool3<A, B, C, LP>(
  lp_treasury_cap: TreasuryCap<LP>,
  decimals_a: u8,
  decimals_b: u8,
  decimals_c: u8,
  ticks: vector<OrbitalTickConfig>,
  ctx: &mut TxContext
): ID {
  assert!(decimals_a <= 18 && decimals_b <= 18 && decimals_c <= 18, EInvalidDecimals);
  validate_ticks(&ticks);

  let mut tick_vec = vector::empty<OrbitalTick<A, B, C>>();
  let mut i = 0;
  let tick_count = vector::length(&ticks);
  while (i < tick_count) {
    let cfg = vector::borrow(&ticks, i);
    let tick = OrbitalTick<A, B, C> {
      band_bps: cfg.band_bps,
      weight_bps: cfg.weight_bps,
      balance_a: balance::zero<A>(),
      balance_b: balance::zero<B>(),
      balance_c: balance::zero<C>(),
      l_squared: compute_l_squared(0, 0, 0, decimals_a, decimals_b, decimals_c)
    };
    vector::push_back(&mut tick_vec, tick);
    i = i + 1;
  };

  let pool = OrbitalPool3<A, B, C, LP> {
    id: object::new(ctx),
    lp_treasury_cap,
    ticks: tick_vec,
    decimals_a,
    decimals_b,
    decimals_c,
    locked_lp_balance: balance::zero<LP>()
  };

  let id = object::id(&pool);
  transfer::share_object(pool);
  id
}

/// === Liquidity ===

public fun add_liquidity<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_a: Coin<A>,
  coin_b: Coin<B>,
  coin_c: Coin<C>,
  ctx: &mut TxContext
): Coin<LP> {
  let amount_a = coin::value(&coin_a);
  let amount_b = coin::value(&coin_b);
  let amount_c = coin::value(&coin_c);

  let total_supply = coin::total_supply(&pool.lp_treasury_cap);
  let shares: u64;

  if (total_supply == 0) {
    let sum = (amount_a as u128) + (amount_b as u128) + (amount_c as u128);
    assert!(sum > (MIN_LP_LOCK as u128), EZeroShares);
    shares = (sum - (MIN_LP_LOCK as u128)) as u64;

    let locked = coin::mint(&mut pool.lp_treasury_cap, MIN_LP_LOCK, ctx);
    balance::join(&mut pool.locked_lp_balance, coin::into_balance(locked));
  } else {
    let (r0, r1, r2) = total_reserves(pool);

    let s0 = (amount_a as u128) * (total_supply as u128) / (r0 as u128);
    let s1 = (amount_b as u128) * (total_supply as u128) / (r1 as u128);
    let s2 = (amount_c as u128) * (total_supply as u128) / (r2 as u128);

    let mut s = if (s0 < s1) { s0 } else { s1 };
    s = if (s < s2) { s } else { s2 };
    assert!(s > 0, EZeroShares);
    shares = s as u64;
  };

  let mut a_bal = coin::into_balance(coin_a);
  let mut b_bal = coin::into_balance(coin_b);
  let mut c_bal = coin::into_balance(coin_c);

  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  let mut remaining_a = amount_a;
  let mut remaining_b = amount_b;
  let mut remaining_c = amount_c;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);

    let mut share_a = if (is_last) { remaining_a } else {
      mul_div_u128(amount_a as u128, tick.weight_bps as u128, BPS as u128) as u64
    };
    let mut share_b = if (is_last) { remaining_b } else {
      mul_div_u128(amount_b as u128, tick.weight_bps as u128, BPS as u128) as u64
    };
    let mut share_c = if (is_last) { remaining_c } else {
      mul_div_u128(amount_c as u128, tick.weight_bps as u128, BPS as u128) as u64
    };

    if (!is_last) {
      remaining_a = remaining_a - share_a;
      remaining_b = remaining_b - share_b;
      remaining_c = remaining_c - share_c;
    };

    if (share_a > 0) {
      let part = balance::split(&mut a_bal, share_a);
      balance::join(&mut tick.balance_a, part);
    };
    if (share_b > 0) {
      let part = balance::split(&mut b_bal, share_b);
      balance::join(&mut tick.balance_b, part);
    };
    if (share_c > 0) {
      let part = balance::split(&mut c_bal, share_c);
      balance::join(&mut tick.balance_c, part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    i = i + 1;
  };

  balance::destroy_zero(a_bal);
  balance::destroy_zero(b_bal);
  balance::destroy_zero(c_bal);

  let lp = coin::mint(&mut pool.lp_treasury_cap, shares, ctx);

  event::emit(LiquidityAdded {
    provider: ctx.sender(),
    amount_a,
    amount_b,
    amount_c,
    shares
  });

  lp
}

public fun remove_liquidity<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  lp_coin: Coin<LP>,
  ctx: &mut TxContext
): (Coin<A>, Coin<B>, Coin<C>) {
  let shares = coin::value(&lp_coin);
  let total_supply = coin::total_supply(&pool.lp_treasury_cap);

  let (r0, r1, r2) = total_reserves(pool);

  let amount_a = (r0 as u128) * (shares as u128) / (total_supply as u128);
  let amount_b = (r1 as u128) * (shares as u128) / (total_supply as u128);
  let amount_c = (r2 as u128) * (shares as u128) / (total_supply as u128);

  coin::burn(&mut pool.lp_treasury_cap, lp_coin);

  let mut out_a = balance::zero<A>();
  let mut out_b = balance::zero<B>();
  let mut out_c = balance::zero<C>();

  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  let mut remaining_a = amount_a as u64;
  let mut remaining_b = amount_b as u64;
  let mut remaining_c = amount_c as u64;

  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);

    let tick_a = balance::value(&tick.balance_a) as u128;
    let tick_b = balance::value(&tick.balance_b) as u128;
    let tick_c = balance::value(&tick.balance_c) as u128;

    let mut share_a = if (is_last) { remaining_a } else {
      (tick_a * (shares as u128) / (total_supply as u128)) as u64
    };
    let mut share_b = if (is_last) { remaining_b } else {
      (tick_b * (shares as u128) / (total_supply as u128)) as u64
    };
    let mut share_c = if (is_last) { remaining_c } else {
      (tick_c * (shares as u128) / (total_supply as u128)) as u64
    };

    if (!is_last) {
      remaining_a = remaining_a - share_a;
      remaining_b = remaining_b - share_b;
      remaining_c = remaining_c - share_c;
    };

    if (share_a > 0) {
      let part = balance::split(&mut tick.balance_a, share_a);
      balance::join(&mut out_a, part);
    };
    if (share_b > 0) {
      let part = balance::split(&mut tick.balance_b, share_b);
      balance::join(&mut out_b, part);
    };
    if (share_c > 0) {
      let part = balance::split(&mut tick.balance_c, share_c);
      balance::join(&mut out_c, part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    i = i + 1;
  };

  let out_a_coin = out_a.into_coin(ctx);
  let out_b_coin = out_b.into_coin(ctx);
  let out_c_coin = out_c.into_coin(ctx);

  event::emit(LiquidityRemoved {
    provider: ctx.sender(),
    amount_a: out_a_coin.value(),
    amount_b: out_b_coin.value(),
    amount_c: out_c_coin.value(),
    shares
  });

  (out_a_coin, out_b_coin, out_c_coin)
}

/// === Swaps (Exact In) ===

public fun swap_a_for_b_exact_in<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  ctx: &mut TxContext
): Coin<B> {
  swap_exact_in_ticks_ab(pool, coin_in, ctx)
}

public fun swap_b_for_a_exact_in<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  ctx: &mut TxContext
): Coin<A> {
  swap_exact_in_ticks_ba(pool, coin_in, ctx)
}

public fun swap_a_for_c_exact_in<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  ctx: &mut TxContext
): Coin<C> {
  swap_exact_in_ticks_ac(pool, coin_in, ctx)
}

public fun swap_c_for_a_exact_in<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  ctx: &mut TxContext
): Coin<A> {
  swap_exact_in_ticks_ca(pool, coin_in, ctx)
}

public fun swap_b_for_c_exact_in<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  ctx: &mut TxContext
): Coin<C> {
  swap_exact_in_ticks_bc(pool, coin_in, ctx)
}

public fun swap_c_for_b_exact_in<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  ctx: &mut TxContext
): Coin<B> {
  swap_exact_in_ticks_cb(pool, coin_in, ctx)
}

/// === Swaps (Exact Out) ===

public fun swap_a_for_b_exact_out<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<B>, Coin<A>) {
  swap_exact_out_ticks_ab(pool, coin_in, amount_out, ctx)
}

public fun swap_b_for_a_exact_out<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<A>, Coin<B>) {
  swap_exact_out_ticks_ba(pool, coin_in, amount_out, ctx)
}

public fun swap_a_for_c_exact_out<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<C>, Coin<A>) {
  swap_exact_out_ticks_ac(pool, coin_in, amount_out, ctx)
}

public fun swap_c_for_a_exact_out<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<A>, Coin<C>) {
  swap_exact_out_ticks_ca(pool, coin_in, amount_out, ctx)
}

public fun swap_b_for_c_exact_out<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<C>, Coin<B>) {
  swap_exact_out_ticks_bc(pool, coin_in, amount_out, ctx)
}

public fun swap_c_for_b_exact_out<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<B>, Coin<C>) {
  swap_exact_out_ticks_cb(pool, coin_in, amount_out, ctx)
}

/// === Views ===

public fun get_reserves<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): (u64, u64, u64) {
  total_reserves(pool)
}

public fun get_l_squared<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u256 {
  let mut sum: u256 = 0;
  let mut i = 0;
  let tick_count = vector::length(&pool.ticks);
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    sum = sum + tick.l_squared;
    i = i + 1;
  };
  sum
}

public fun get_tick_count<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u64 {
  vector::length(&pool.ticks) as u64
}

public fun get_tick_weights<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): vector<u64> {
  let mut out = vector::empty<u64>();
  let mut i = 0;
  let tick_count = vector::length(&pool.ticks);
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    vector::push_back(&mut out, tick.weight_bps);
    i = i + 1;
  };
  out
}

public fun get_tick_reserves<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): vector<u64> {
  let mut out = vector::empty<u64>();
  let mut i = 0;
  let tick_count = vector::length(&pool.ticks);
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    vector::push_back(&mut out, balance::value(&tick.balance_a));
    vector::push_back(&mut out, balance::value(&tick.balance_b));
    vector::push_back(&mut out, balance::value(&tick.balance_c));
    i = i + 1;
  };
  out
}

public fun lp_total_supply<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u64 {
  coin::total_supply(&pool.lp_treasury_cap)
}

#[test_only]
public fun test_burn_lp<A, B, C, LP>(pool: &mut OrbitalPool3<A, B, C, LP>, lp: Coin<LP>) {
  coin::burn(&mut pool.lp_treasury_cap, lp);
}

public fun quote_a_for_b_exact_in<A, B, C, LP>(
  pool: &OrbitalPool3<A, B, C, LP>,
  amount_in: u64
): u64 {
  quote_exact_in_ticks_ab(pool, amount_in)
}

public fun quote_a_for_b_exact_out<A, B, C, LP>(
  pool: &OrbitalPool3<A, B, C, LP>,
  amount_out: u64
): u64 {
  quote_exact_out_ticks_ab(pool, amount_out)
}

/// === Tick Validation ===

fun validate_ticks(ticks: &vector<OrbitalTickConfig>) {
  let tick_count = vector::length(ticks);
  assert!(tick_count > 0, EZeroTicks);

  let mut total_weight: u64 = 0;
  let mut i = 0;
  let mut last_band: u64 = 0;
  while (i < tick_count) {
    let tick = vector::borrow(ticks, i);
    assert!(tick.band_bps <= BPS, EInvalidBand);
    assert!(tick.weight_bps > 0, EInvalidWeights);
    if (i > 0) {
      assert!(tick.band_bps > last_band, EInvalidBandOrder);
    };
    total_weight = total_weight + tick.weight_bps;
    last_band = tick.band_bps;
    i = i + 1;
  };

  assert!(total_weight == BPS, EInvalidWeights);
}

/// === Swap Helpers (Ticks) ===

fun swap_exact_in_ticks_ab<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  ctx: &mut TxContext
): Coin<B> {
  let amount_in = coin::value(&coin_in);
  let fee = (amount_in as u128) * (LP_FEE as u128) / (FEE_DENOMINATOR as u128);
  let amount_in_net = amount_in - (fee as u64);

  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let mut out_balance = balance::zero<B>();

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_net = amount_in_net;
  let mut remaining_fee = fee as u64;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);

    let mut net_i = if (is_last) { remaining_net } else {
      mul_div_u128(amount_in_net as u128, tick_liq, total_liquidity) as u64
    };
    let mut fee_i = if (is_last) { remaining_fee } else {
      mul_div_u128(fee as u128, tick_liq, total_liquidity) as u64
    };

    if (!is_last) {
      remaining_net = remaining_net - net_i;
      remaining_fee = remaining_fee - fee_i;
    };

    if (net_i > 0 || fee_i > 0) {
      let x = balance::value(&tick.balance_a);
      let y = balance::value(&tick.balance_b);
      let z = balance::value(&tick.balance_c);
      let out_i = quote_exact_in(x, y, z, net_i, pool.decimals_a, pool.decimals_b, pool.decimals_c, tick.l_squared);

      let gross_i = net_i + fee_i;
      let part_in = balance::split(&mut in_balance, gross_i);
      balance::join(&mut tick.balance_a, part_in);

      let part_out = balance::split(&mut tick.balance_b, out_i);
      balance::join(&mut out_balance, part_out);

      update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);
    };

    i = i + 1;
  };

  balance::destroy_zero(in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in, amount_out: out_coin.value() });
  out_coin
}

fun swap_exact_in_ticks_ba<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  ctx: &mut TxContext
): Coin<A> {
  let amount_in = coin::value(&coin_in);
  let fee = (amount_in as u128) * (LP_FEE as u128) / (FEE_DENOMINATOR as u128);
  let amount_in_net = amount_in - (fee as u64);

  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let mut out_balance = balance::zero<A>();

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_net = amount_in_net;
  let mut remaining_fee = fee as u64;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);

    let mut net_i = if (is_last) { remaining_net } else {
      mul_div_u128(amount_in_net as u128, tick_liq, total_liquidity) as u64
    };
    let mut fee_i = if (is_last) { remaining_fee } else {
      mul_div_u128(fee as u128, tick_liq, total_liquidity) as u64
    };

    if (!is_last) {
      remaining_net = remaining_net - net_i;
      remaining_fee = remaining_fee - fee_i;
    };

    if (net_i > 0 || fee_i > 0) {
      let x = balance::value(&tick.balance_b);
      let y = balance::value(&tick.balance_a);
      let z = balance::value(&tick.balance_c);
      let out_i = quote_exact_in(x, y, z, net_i, pool.decimals_b, pool.decimals_a, pool.decimals_c, tick.l_squared);

      let gross_i = net_i + fee_i;
      let part_in = balance::split(&mut in_balance, gross_i);
      balance::join(&mut tick.balance_b, part_in);

      let part_out = balance::split(&mut tick.balance_a, out_i);
      balance::join(&mut out_balance, part_out);

      update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);
    };

    i = i + 1;
  };

  balance::destroy_zero(in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in, amount_out: out_coin.value() });
  out_coin
}

fun swap_exact_in_ticks_ac<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  ctx: &mut TxContext
): Coin<C> {
  let amount_in = coin::value(&coin_in);
  let fee = (amount_in as u128) * (LP_FEE as u128) / (FEE_DENOMINATOR as u128);
  let amount_in_net = amount_in - (fee as u64);

  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let mut out_balance = balance::zero<C>();

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_net = amount_in_net;
  let mut remaining_fee = fee as u64;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);

    let mut net_i = if (is_last) { remaining_net } else {
      mul_div_u128(amount_in_net as u128, tick_liq, total_liquidity) as u64
    };
    let mut fee_i = if (is_last) { remaining_fee } else {
      mul_div_u128(fee as u128, tick_liq, total_liquidity) as u64
    };

    if (!is_last) {
      remaining_net = remaining_net - net_i;
      remaining_fee = remaining_fee - fee_i;
    };

    if (net_i > 0 || fee_i > 0) {
      let x = balance::value(&tick.balance_a);
      let y = balance::value(&tick.balance_c);
      let z = balance::value(&tick.balance_b);
      let out_i = quote_exact_in(x, y, z, net_i, pool.decimals_a, pool.decimals_c, pool.decimals_b, tick.l_squared);

      let gross_i = net_i + fee_i;
      let part_in = balance::split(&mut in_balance, gross_i);
      balance::join(&mut tick.balance_a, part_in);

      let part_out = balance::split(&mut tick.balance_c, out_i);
      balance::join(&mut out_balance, part_out);

      update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);
    };

    i = i + 1;
  };

  balance::destroy_zero(in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in, amount_out: out_coin.value() });
  out_coin
}

fun swap_exact_in_ticks_ca<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  ctx: &mut TxContext
): Coin<A> {
  let amount_in = coin::value(&coin_in);
  let fee = (amount_in as u128) * (LP_FEE as u128) / (FEE_DENOMINATOR as u128);
  let amount_in_net = amount_in - (fee as u64);

  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let mut out_balance = balance::zero<A>();

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_net = amount_in_net;
  let mut remaining_fee = fee as u64;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);

    let mut net_i = if (is_last) { remaining_net } else {
      mul_div_u128(amount_in_net as u128, tick_liq, total_liquidity) as u64
    };
    let mut fee_i = if (is_last) { remaining_fee } else {
      mul_div_u128(fee as u128, tick_liq, total_liquidity) as u64
    };

    if (!is_last) {
      remaining_net = remaining_net - net_i;
      remaining_fee = remaining_fee - fee_i;
    };

    if (net_i > 0 || fee_i > 0) {
      let x = balance::value(&tick.balance_c);
      let y = balance::value(&tick.balance_a);
      let z = balance::value(&tick.balance_b);
      let out_i = quote_exact_in(x, y, z, net_i, pool.decimals_c, pool.decimals_a, pool.decimals_b, tick.l_squared);

      let gross_i = net_i + fee_i;
      let part_in = balance::split(&mut in_balance, gross_i);
      balance::join(&mut tick.balance_c, part_in);

      let part_out = balance::split(&mut tick.balance_a, out_i);
      balance::join(&mut out_balance, part_out);

      update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);
    };

    i = i + 1;
  };

  balance::destroy_zero(in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in, amount_out: out_coin.value() });
  out_coin
}

fun swap_exact_in_ticks_bc<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  ctx: &mut TxContext
): Coin<C> {
  let amount_in = coin::value(&coin_in);
  let fee = (amount_in as u128) * (LP_FEE as u128) / (FEE_DENOMINATOR as u128);
  let amount_in_net = amount_in - (fee as u64);

  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let mut out_balance = balance::zero<C>();

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_net = amount_in_net;
  let mut remaining_fee = fee as u64;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);

    let mut net_i = if (is_last) { remaining_net } else {
      mul_div_u128(amount_in_net as u128, tick_liq, total_liquidity) as u64
    };
    let mut fee_i = if (is_last) { remaining_fee } else {
      mul_div_u128(fee as u128, tick_liq, total_liquidity) as u64
    };

    if (!is_last) {
      remaining_net = remaining_net - net_i;
      remaining_fee = remaining_fee - fee_i;
    };

    if (net_i > 0 || fee_i > 0) {
      let x = balance::value(&tick.balance_b);
      let y = balance::value(&tick.balance_c);
      let z = balance::value(&tick.balance_a);
      let out_i = quote_exact_in(x, y, z, net_i, pool.decimals_b, pool.decimals_c, pool.decimals_a, tick.l_squared);

      let gross_i = net_i + fee_i;
      let part_in = balance::split(&mut in_balance, gross_i);
      balance::join(&mut tick.balance_b, part_in);

      let part_out = balance::split(&mut tick.balance_c, out_i);
      balance::join(&mut out_balance, part_out);

      update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);
    };

    i = i + 1;
  };

  balance::destroy_zero(in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in, amount_out: out_coin.value() });
  out_coin
}

fun swap_exact_in_ticks_cb<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  ctx: &mut TxContext
): Coin<B> {
  let amount_in = coin::value(&coin_in);
  let fee = (amount_in as u128) * (LP_FEE as u128) / (FEE_DENOMINATOR as u128);
  let amount_in_net = amount_in - (fee as u64);

  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let mut out_balance = balance::zero<B>();

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_net = amount_in_net;
  let mut remaining_fee = fee as u64;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);

    let mut net_i = if (is_last) { remaining_net } else {
      mul_div_u128(amount_in_net as u128, tick_liq, total_liquidity) as u64
    };
    let mut fee_i = if (is_last) { remaining_fee } else {
      mul_div_u128(fee as u128, tick_liq, total_liquidity) as u64
    };

    if (!is_last) {
      remaining_net = remaining_net - net_i;
      remaining_fee = remaining_fee - fee_i;
    };

    if (net_i > 0 || fee_i > 0) {
      let x = balance::value(&tick.balance_c);
      let y = balance::value(&tick.balance_b);
      let z = balance::value(&tick.balance_a);
      let out_i = quote_exact_in(x, y, z, net_i, pool.decimals_c, pool.decimals_b, pool.decimals_a, tick.l_squared);

      let gross_i = net_i + fee_i;
      let part_in = balance::split(&mut in_balance, gross_i);
      balance::join(&mut tick.balance_c, part_in);

      let part_out = balance::split(&mut tick.balance_b, out_i);
      balance::join(&mut out_balance, part_out);

      update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);
    };

    i = i + 1;
  };

  balance::destroy_zero(in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in, amount_out: out_coin.value() });
  out_coin
}

fun swap_exact_out_ticks_ab<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<B>, Coin<A>) {
  if (amount_out == 0) {
    let refund = coin_in;
    let zero = balance::zero<B>().into_coin(ctx);
    return (zero, refund)
  };

  let total_out = total_balance_b(pool) as u128;
  assert!(total_out >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);

  let mut out_balance = balance::zero<B>();
  let mut total_net_in: u128 = 0;

  let mut out_plan = vector::empty<u64>();
  let mut i = 0;
  let mut remaining_out = amount_out;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_b) as u128;
    let mut out_i = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out) as u64
    };

    if (!is_last) {
      remaining_out = remaining_out - out_i;
    };

    vector::push_back(&mut out_plan, out_i);
    i = i + 1;
  };

  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&pool.ticks, j);
    let out_i = *vector::borrow(&out_plan, j);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_c),
        out_i,
        pool.decimals_a,
        pool.decimals_b,
        pool.decimals_c,
        tick.l_squared
      )
    };
    total_net_in = total_net_in + (net_in_i as u128);
    j = j + 1;
  };

  let total_gross_in = mul_div_ceil_u128(total_net_in, FEE_DENOMINATOR as u128, (FEE_DENOMINATOR - LP_FEE) as u128) as u64;
  assert!(coin::value(&coin_in) >= total_gross_in, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let used_in = balance::split(&mut in_balance, total_gross_in);
  let refund = in_balance.into_coin(ctx);

  let mut used_in_balance = used_in;
  let mut remaining_fee: u128 = (total_gross_in as u128) - total_net_in;

  let mut k = 0;
  let mut remaining_net = total_net_in as u64;
  while (k < tick_count) {
    let is_last = k + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, k);
    let out_i = *vector::borrow(&out_plan, k);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_c),
        out_i,
        pool.decimals_a,
        pool.decimals_b,
        pool.decimals_c,
        tick.l_squared
      )
    };

    let fee_i = if (is_last) { remaining_fee as u64 } else {
      if (total_net_in == 0) { 0 } else { mul_div_u128(remaining_fee as u128, net_in_i as u128, remaining_net as u128) as u64 }
    };

    if (!is_last) {
      remaining_fee = remaining_fee - (fee_i as u128);
      remaining_net = remaining_net - net_in_i;
    };

    let gross_i = net_in_i + fee_i;
    if (gross_i > 0) {
      let in_part = balance::split(&mut used_in_balance, gross_i);
      balance::join(&mut tick.balance_a, in_part);
    };

    if (out_i > 0) {
      let out_part = balance::split(&mut tick.balance_b, out_i);
      balance::join(&mut out_balance, out_part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    k = k + 1;
  };

  balance::destroy_zero(used_in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in: total_gross_in, amount_out: out_coin.value() });
  (out_coin, refund)
}

fun swap_exact_out_ticks_ba<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<A>, Coin<B>) {
  if (amount_out == 0) {
    let refund = coin_in;
    let zero = balance::zero<A>().into_coin(ctx);
    return (zero, refund)
  };

  let total_out = total_balance_a(pool) as u128;
  assert!(total_out >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);

  let mut out_balance = balance::zero<A>();
  let mut total_net_in: u128 = 0;

  let mut out_plan = vector::empty<u64>();
  let mut i = 0;
  let mut remaining_out = amount_out;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_a) as u128;
    let mut out_i = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out) as u64
    };

    if (!is_last) {
      remaining_out = remaining_out - out_i;
    };

    vector::push_back(&mut out_plan, out_i);
    i = i + 1;
  };

  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&pool.ticks, j);
    let out_i = *vector::borrow(&out_plan, j);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_c),
        out_i,
        pool.decimals_b,
        pool.decimals_a,
        pool.decimals_c,
        tick.l_squared
      )
    };
    total_net_in = total_net_in + (net_in_i as u128);
    j = j + 1;
  };

  let total_gross_in = mul_div_ceil_u128(total_net_in, FEE_DENOMINATOR as u128, (FEE_DENOMINATOR - LP_FEE) as u128) as u64;
  assert!(coin::value(&coin_in) >= total_gross_in, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let used_in = balance::split(&mut in_balance, total_gross_in);
  let refund = in_balance.into_coin(ctx);

  let mut used_in_balance = used_in;
  let mut remaining_fee: u128 = (total_gross_in as u128) - total_net_in;

  let mut k = 0;
  let mut remaining_net = total_net_in as u64;
  while (k < tick_count) {
    let is_last = k + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, k);
    let out_i = *vector::borrow(&out_plan, k);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_c),
        out_i,
        pool.decimals_b,
        pool.decimals_a,
        pool.decimals_c,
        tick.l_squared
      )
    };

    let fee_i = if (is_last) { remaining_fee as u64 } else {
      if (total_net_in == 0) { 0 } else { mul_div_u128(remaining_fee as u128, net_in_i as u128, remaining_net as u128) as u64 }
    };

    if (!is_last) {
      remaining_fee = remaining_fee - (fee_i as u128);
      remaining_net = remaining_net - net_in_i;
    };

    let gross_i = net_in_i + fee_i;
    if (gross_i > 0) {
      let in_part = balance::split(&mut used_in_balance, gross_i);
      balance::join(&mut tick.balance_b, in_part);
    };

    if (out_i > 0) {
      let out_part = balance::split(&mut tick.balance_a, out_i);
      balance::join(&mut out_balance, out_part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    k = k + 1;
  };

  balance::destroy_zero(used_in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in: total_gross_in, amount_out: out_coin.value() });
  (out_coin, refund)
}

fun swap_exact_out_ticks_ac<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<A>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<C>, Coin<A>) {
  if (amount_out == 0) {
    let refund = coin_in;
    let zero = balance::zero<C>().into_coin(ctx);
    return (zero, refund)
  };

  let total_out = total_balance_c(pool) as u128;
  assert!(total_out >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);

  let mut out_balance = balance::zero<C>();
  let mut total_net_in: u128 = 0;

  let mut out_plan = vector::empty<u64>();
  let mut i = 0;
  let mut remaining_out = amount_out;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_c) as u128;
    let mut out_i = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out) as u64
    };

    if (!is_last) {
      remaining_out = remaining_out - out_i;
    };

    vector::push_back(&mut out_plan, out_i);
    i = i + 1;
  };

  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&pool.ticks, j);
    let out_i = *vector::borrow(&out_plan, j);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_b),
        out_i,
        pool.decimals_a,
        pool.decimals_c,
        pool.decimals_b,
        tick.l_squared
      )
    };
    total_net_in = total_net_in + (net_in_i as u128);
    j = j + 1;
  };

  let total_gross_in = mul_div_ceil_u128(total_net_in, FEE_DENOMINATOR as u128, (FEE_DENOMINATOR - LP_FEE) as u128) as u64;
  assert!(coin::value(&coin_in) >= total_gross_in, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let used_in = balance::split(&mut in_balance, total_gross_in);
  let refund = in_balance.into_coin(ctx);

  let mut used_in_balance = used_in;
  let mut remaining_fee: u128 = (total_gross_in as u128) - total_net_in;

  let mut k = 0;
  let mut remaining_net = total_net_in as u64;
  while (k < tick_count) {
    let is_last = k + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, k);
    let out_i = *vector::borrow(&out_plan, k);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_b),
        out_i,
        pool.decimals_a,
        pool.decimals_c,
        pool.decimals_b,
        tick.l_squared
      )
    };

    let fee_i = if (is_last) { remaining_fee as u64 } else {
      if (total_net_in == 0) { 0 } else { mul_div_u128(remaining_fee as u128, net_in_i as u128, remaining_net as u128) as u64 }
    };

    if (!is_last) {
      remaining_fee = remaining_fee - (fee_i as u128);
      remaining_net = remaining_net - net_in_i;
    };

    let gross_i = net_in_i + fee_i;
    if (gross_i > 0) {
      let in_part = balance::split(&mut used_in_balance, gross_i);
      balance::join(&mut tick.balance_a, in_part);
    };

    if (out_i > 0) {
      let out_part = balance::split(&mut tick.balance_c, out_i);
      balance::join(&mut out_balance, out_part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    k = k + 1;
  };

  balance::destroy_zero(used_in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in: total_gross_in, amount_out: out_coin.value() });
  (out_coin, refund)
}

fun swap_exact_out_ticks_ca<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<A>, Coin<C>) {
  if (amount_out == 0) {
    let refund = coin_in;
    let zero = balance::zero<A>().into_coin(ctx);
    return (zero, refund)
  };

  let total_out = total_balance_a(pool) as u128;
  assert!(total_out >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);

  let mut out_balance = balance::zero<A>();
  let mut total_net_in: u128 = 0;

  let mut out_plan = vector::empty<u64>();
  let mut i = 0;
  let mut remaining_out = amount_out;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_a) as u128;
    let mut out_i = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out) as u64
    };

    if (!is_last) {
      remaining_out = remaining_out - out_i;
    };

    vector::push_back(&mut out_plan, out_i);
    i = i + 1;
  };

  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&pool.ticks, j);
    let out_i = *vector::borrow(&out_plan, j);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_b),
        out_i,
        pool.decimals_c,
        pool.decimals_a,
        pool.decimals_b,
        tick.l_squared
      )
    };
    total_net_in = total_net_in + (net_in_i as u128);
    j = j + 1;
  };

  let total_gross_in = mul_div_ceil_u128(total_net_in, FEE_DENOMINATOR as u128, (FEE_DENOMINATOR - LP_FEE) as u128) as u64;
  assert!(coin::value(&coin_in) >= total_gross_in, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let used_in = balance::split(&mut in_balance, total_gross_in);
  let refund = in_balance.into_coin(ctx);

  let mut used_in_balance = used_in;
  let mut remaining_fee: u128 = (total_gross_in as u128) - total_net_in;

  let mut k = 0;
  let mut remaining_net = total_net_in as u64;
  while (k < tick_count) {
    let is_last = k + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, k);
    let out_i = *vector::borrow(&out_plan, k);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_b),
        out_i,
        pool.decimals_c,
        pool.decimals_a,
        pool.decimals_b,
        tick.l_squared
      )
    };

    let fee_i = if (is_last) { remaining_fee as u64 } else {
      if (total_net_in == 0) { 0 } else { mul_div_u128(remaining_fee as u128, net_in_i as u128, remaining_net as u128) as u64 }
    };

    if (!is_last) {
      remaining_fee = remaining_fee - (fee_i as u128);
      remaining_net = remaining_net - net_in_i;
    };

    let gross_i = net_in_i + fee_i;
    if (gross_i > 0) {
      let in_part = balance::split(&mut used_in_balance, gross_i);
      balance::join(&mut tick.balance_c, in_part);
    };

    if (out_i > 0) {
      let out_part = balance::split(&mut tick.balance_a, out_i);
      balance::join(&mut out_balance, out_part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    k = k + 1;
  };

  balance::destroy_zero(used_in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in: total_gross_in, amount_out: out_coin.value() });
  (out_coin, refund)
}

fun swap_exact_out_ticks_bc<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<B>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<C>, Coin<B>) {
  if (amount_out == 0) {
    let refund = coin_in;
    let zero = balance::zero<C>().into_coin(ctx);
    return (zero, refund)
  };

  let total_out = total_balance_c(pool) as u128;
  assert!(total_out >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);

  let mut out_balance = balance::zero<C>();
  let mut total_net_in: u128 = 0;

  let mut out_plan = vector::empty<u64>();
  let mut i = 0;
  let mut remaining_out = amount_out;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_c) as u128;
    let mut out_i = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out) as u64
    };

    if (!is_last) {
      remaining_out = remaining_out - out_i;
    };

    vector::push_back(&mut out_plan, out_i);
    i = i + 1;
  };

  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&pool.ticks, j);
    let out_i = *vector::borrow(&out_plan, j);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_a),
        out_i,
        pool.decimals_b,
        pool.decimals_c,
        pool.decimals_a,
        tick.l_squared
      )
    };
    total_net_in = total_net_in + (net_in_i as u128);
    j = j + 1;
  };

  let total_gross_in = mul_div_ceil_u128(total_net_in, FEE_DENOMINATOR as u128, (FEE_DENOMINATOR - LP_FEE) as u128) as u64;
  assert!(coin::value(&coin_in) >= total_gross_in, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let used_in = balance::split(&mut in_balance, total_gross_in);
  let refund = in_balance.into_coin(ctx);

  let mut used_in_balance = used_in;
  let mut remaining_fee: u128 = (total_gross_in as u128) - total_net_in;

  let mut k = 0;
  let mut remaining_net = total_net_in as u64;
  while (k < tick_count) {
    let is_last = k + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, k);
    let out_i = *vector::borrow(&out_plan, k);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_a),
        out_i,
        pool.decimals_b,
        pool.decimals_c,
        pool.decimals_a,
        tick.l_squared
      )
    };

    let fee_i = if (is_last) { remaining_fee as u64 } else {
      if (total_net_in == 0) { 0 } else { mul_div_u128(remaining_fee as u128, net_in_i as u128, remaining_net as u128) as u64 }
    };

    if (!is_last) {
      remaining_fee = remaining_fee - (fee_i as u128);
      remaining_net = remaining_net - net_in_i;
    };

    let gross_i = net_in_i + fee_i;
    if (gross_i > 0) {
      let in_part = balance::split(&mut used_in_balance, gross_i);
      balance::join(&mut tick.balance_b, in_part);
    };

    if (out_i > 0) {
      let out_part = balance::split(&mut tick.balance_c, out_i);
      balance::join(&mut out_balance, out_part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    k = k + 1;
  };

  balance::destroy_zero(used_in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in: total_gross_in, amount_out: out_coin.value() });
  (out_coin, refund)
}

fun swap_exact_out_ticks_cb<A, B, C, LP>(
  pool: &mut OrbitalPool3<A, B, C, LP>,
  coin_in: Coin<C>,
  amount_out: u64,
  ctx: &mut TxContext
): (Coin<B>, Coin<C>) {
  if (amount_out == 0) {
    let refund = coin_in;
    let zero = balance::zero<B>().into_coin(ctx);
    return (zero, refund)
  };

  let total_out = total_balance_b(pool) as u128;
  assert!(total_out >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);

  let mut out_balance = balance::zero<B>();
  let mut total_net_in: u128 = 0;

  let mut out_plan = vector::empty<u64>();
  let mut i = 0;
  let mut remaining_out = amount_out;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_b) as u128;
    let mut out_i = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out) as u64
    };

    if (!is_last) {
      remaining_out = remaining_out - out_i;
    };

    vector::push_back(&mut out_plan, out_i);
    i = i + 1;
  };

  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&pool.ticks, j);
    let out_i = *vector::borrow(&out_plan, j);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_a),
        out_i,
        pool.decimals_c,
        pool.decimals_b,
        pool.decimals_a,
        tick.l_squared
      )
    };
    total_net_in = total_net_in + (net_in_i as u128);
    j = j + 1;
  };

  let total_gross_in = mul_div_ceil_u128(total_net_in, FEE_DENOMINATOR as u128, (FEE_DENOMINATOR - LP_FEE) as u128) as u64;
  assert!(coin::value(&coin_in) >= total_gross_in, EInsufficientLiquidity);

  let mut in_balance = coin::into_balance(coin_in);
  let used_in = balance::split(&mut in_balance, total_gross_in);
  let refund = in_balance.into_coin(ctx);

  let mut used_in_balance = used_in;
  let mut remaining_fee: u128 = (total_gross_in as u128) - total_net_in;

  let mut k = 0;
  let mut remaining_net = total_net_in as u64;
  while (k < tick_count) {
    let is_last = k + 1 == tick_count;
    let tick = vector::borrow_mut(&mut pool.ticks, k);
    let out_i = *vector::borrow(&out_plan, k);
    let net_in_i = if (out_i == 0) { 0 } else {
      quote_exact_out(
        balance::value(&tick.balance_c),
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_a),
        out_i,
        pool.decimals_c,
        pool.decimals_b,
        pool.decimals_a,
        tick.l_squared
      )
    };

    let fee_i = if (is_last) { remaining_fee as u64 } else {
      if (total_net_in == 0) { 0 } else { mul_div_u128(remaining_fee as u128, net_in_i as u128, remaining_net as u128) as u64 }
    };

    if (!is_last) {
      remaining_fee = remaining_fee - (fee_i as u128);
      remaining_net = remaining_net - net_in_i;
    };

    let gross_i = net_in_i + fee_i;
    if (gross_i > 0) {
      let in_part = balance::split(&mut used_in_balance, gross_i);
      balance::join(&mut tick.balance_c, in_part);
    };

    if (out_i > 0) {
      let out_part = balance::split(&mut tick.balance_b, out_i);
      balance::join(&mut out_balance, out_part);
    };

    update_tick_l_squared(tick, pool.decimals_a, pool.decimals_b, pool.decimals_c);

    k = k + 1;
  };

  balance::destroy_zero(used_in_balance);
  let out_coin = out_balance.into_coin(ctx);
  event::emit(SwapEvent { sender: ctx.sender(), amount_in: total_gross_in, amount_out: out_coin.value() });
  (out_coin, refund)
}

fun quote_exact_in_ticks_ab<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>, amount_in: u64): u64 {
  if (amount_in == 0) {
    return 0
  };
  let total_liquidity = total_liquidity_value(pool);
  assert!(total_liquidity > 0, EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_in = amount_in;
  let mut total_out: u64 = 0;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_liq = tick_liquidity_value(tick);
    let share = if (is_last) { remaining_in } else {
      mul_div_u128(amount_in as u128, tick_liq, total_liquidity) as u64
    };
    if (!is_last) {
      remaining_in = remaining_in - share;
    };
    if (share > 0) {
      let out_i = quote_exact_in(
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_c),
        share,
        pool.decimals_a,
        pool.decimals_b,
        pool.decimals_c,
        tick.l_squared
      );
      total_out = total_out + out_i;
    };
    i = i + 1;
  };

  total_out
}

fun quote_exact_out_ticks_ab<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>, amount_out: u64): u64 {
  if (amount_out == 0) {
    return 0
  };
  let total_out_balance = total_balance_b(pool) as u128;
  assert!(total_out_balance >= (amount_out as u128), EInsufficientLiquidity);

  let tick_count = vector::length(&pool.ticks);
  let mut remaining_out = amount_out;
  let mut total_in: u64 = 0;
  let mut i = 0;
  while (i < tick_count) {
    let is_last = i + 1 == tick_count;
    let tick = vector::borrow(&pool.ticks, i);
    let tick_out = balance::value(&tick.balance_b) as u128;
    let share = if (is_last) { remaining_out } else {
      (tick_out * (amount_out as u128) / total_out_balance) as u64
    };
    if (!is_last) {
      remaining_out = remaining_out - share;
    };
    if (share > 0) {
      let in_i = quote_exact_out(
        balance::value(&tick.balance_a),
        balance::value(&tick.balance_b),
        balance::value(&tick.balance_c),
        share,
        pool.decimals_a,
        pool.decimals_b,
        pool.decimals_c,
        tick.l_squared
      );
      total_in = total_in + in_i;
    };
    i = i + 1;
  };

  total_in
}

/// === Internal Math ===

fun quote_exact_in(
  x: u64,
  y: u64,
  z: u64,
  amount_in: u64,
  decimals_x: u8,
  decimals_y: u8,
  decimals_z: u8,
  l_squared: u256
): u64 {
  if (amount_in == 0) {
    return 0
  };

  let x18 = to_18(x, decimals_x);
  let y18 = to_18(y, decimals_y);
  let z18 = to_18(z, decimals_z);
  let amount_in18 = to_18(amount_in, decimals_x);

  assert!(x18 + amount_in18 < R, EReservesExceedRadius);

  let term_x_new = (R - (x18 + amount_in18)) * (R - (x18 + amount_in18));
  let term_z = (R - z18) * (R - z18);
  assert!(l_squared >= term_x_new + term_z, EInvariantViolation);

  let term_y_new = l_squared - term_x_new - term_z;
  let sqrt_term_y = sqrt_u256(term_y_new);
  assert!(R >= sqrt_term_y, EMathError);

  let y_new18 = R - sqrt_term_y;
  assert!(y18 >= y_new18, EInsufficientLiquidity);
  let amount_out18 = y18 - y_new18;

  from_18(amount_out18, decimals_y)
}

fun quote_exact_out(
  x: u64,
  y: u64,
  z: u64,
  amount_out: u64,
  decimals_x: u8,
  decimals_y: u8,
  decimals_z: u8,
  l_squared: u256
): u64 {
  if (amount_out == 0) {
    return 0
  };

  let x18 = to_18(x, decimals_x);
  let y18 = to_18(y, decimals_y);
  let z18 = to_18(z, decimals_z);
  let amount_out18 = to_18(amount_out, decimals_y);

  assert!(y18 > amount_out18, EInsufficientLiquidity);
  let y_new18 = y18 - amount_out18;

  let term_y_new = (R - y_new18) * (R - y_new18);
  let term_z = (R - z18) * (R - z18);
  assert!(l_squared >= term_y_new + term_z, EInvariantViolation);

  let term_x_new = l_squared - term_y_new - term_z;
  let sqrt_term_x = sqrt_u256(term_x_new);
  assert!(R >= sqrt_term_x, EMathError);

  let x_new18 = R - sqrt_term_x;
  assert!(x_new18 >= x18, EInvariantViolation);
  let amount_in18 = x_new18 - x18;

  let amount_in = from_18(amount_in18, decimals_x);
  amount_in + 1
}

fun update_tick_l_squared<A, B, C>(tick: &mut OrbitalTick<A, B, C>, da: u8, db: u8, dc: u8) {
  tick.l_squared = compute_l_squared(
    balance::value(&tick.balance_a),
    balance::value(&tick.balance_b),
    balance::value(&tick.balance_c),
    da,
    db,
    dc
  );
}

fun total_reserves<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): (u64, u64, u64) {
  let mut a: u64 = 0;
  let mut b: u64 = 0;
  let mut c: u64 = 0;
  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    a = a + balance::value(&tick.balance_a);
    b = b + balance::value(&tick.balance_b);
    c = c + balance::value(&tick.balance_c);
    i = i + 1;
  };
  (a, b, c)
}

fun total_balance_a<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u64 {
  let mut a: u64 = 0;
  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    a = a + balance::value(&tick.balance_a);
    i = i + 1;
  };
  a
}

fun total_balance_b<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u64 {
  let mut b: u64 = 0;
  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    b = b + balance::value(&tick.balance_b);
    i = i + 1;
  };
  b
}

fun total_balance_c<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u64 {
  let mut c: u64 = 0;
  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    c = c + balance::value(&tick.balance_c);
    i = i + 1;
  };
  c
}

fun total_liquidity_value<A, B, C, LP>(pool: &OrbitalPool3<A, B, C, LP>): u128 {
  let mut total: u128 = 0;
  let tick_count = vector::length(&pool.ticks);
  let mut i = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&pool.ticks, i);
    total = total + tick_liquidity_value(tick);
    i = i + 1;
  };
  total
}

fun tick_liquidity_value<A, B, C>(tick: &OrbitalTick<A, B, C>): u128 {
  (balance::value(&tick.balance_a) as u128) +
    (balance::value(&tick.balance_b) as u128) +
    (balance::value(&tick.balance_c) as u128)
}

fun compute_l_squared(
  x: u64,
  y: u64,
  z: u64,
  decimals_x: u8,
  decimals_y: u8,
  decimals_z: u8
): u256 {
  let x18 = to_18(x, decimals_x);
  let y18 = to_18(y, decimals_y);
  let z18 = to_18(z, decimals_z);

  assert!(x18 <= R && y18 <= R && z18 <= R, EReservesExceedRadius);

  let t1 = R - x18;
  let t2 = R - y18;
  let t3 = R - z18;
  t1 * t1 + t2 * t2 + t3 * t3
}

fun to_18(amount: u64, decimals: u8): u256 {
  if (decimals == 18) {
    amount as u256
  } else if (decimals < 18) {
    (amount as u256) * pow10_u256((18 - decimals) as u8)
  } else {
    (amount as u256) / pow10_u256((decimals - 18) as u8)
  }
}

fun from_18(amount: u256, decimals: u8): u64 {
  if (decimals == 18) {
    amount as u64
  } else if (decimals < 18) {
    (amount / pow10_u256((18 - decimals) as u8)) as u64
  } else {
    (amount * pow10_u256((decimals - 18) as u8)) as u64
  }
}

fun pow10_u256(exp: u8): u256 {
  let mut i = 0;
  let mut result: u256 = 1;
  while (i < exp) {
    result = result * 10;
    i = i + 1;
  };
  result
}

fun sqrt_u256(x: u256): u256 {
  if (x == 0) {
    return 0
  };

  let mut z = x;
  let mut y = (x + 1) / 2;
  while (y < z) {
    z = y;
    y = (x / y + y) / 2;
  };
  z
}

fun mul_div_u128(a: u128, b: u128, denom: u128): u128 {
  (a * b) / denom
}

fun mul_div_ceil_u128(a: u128, b: u128, denom: u128): u128 {
  let prod = a * b;
  if (prod % denom == 0) {
    prod / denom
  } else {
    prod / denom + 1
  }
}
