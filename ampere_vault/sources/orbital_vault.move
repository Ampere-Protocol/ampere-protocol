module ampere_vault::orbital_vault;

use sui::clock::Clock;
use sui::coin::{Coin, TreasuryCap};
use sui::event;
use std::u64::min;
use deepbook::balance_manager;
use deepbook::pool::{Pool, mid_price, place_limit_order, pool_book_params};
use deepbook::balance_manager::{TradeProof, balance};
use pyth::{pyth, price_info, price_identifier, price, i64};
use pyth::price_info::PriceInfoObject;

/// === Constants ===
const BPS: u64 = 10000;
const PERCENT: u64 = 100;
const MAX_SKEW_PERCENT: u64 = 100;

/// === Errors ===
const EInvalidID: u64 = 0;
const EWithdrawAmountTooLarge: u64 = 1;
const EMintAmountTooLarge: u64 = 2;
const EOrderSizeTooSmall: u64 = 3;
const EInvalidBand: u64 = 4;
const EInvalidWeights: u64 = 5;
const EInvalidSkew: u64 = 6;
const EExpiredTimestamp: u64 = 7;
const EUnauthorized: u64 = 8;
const EZeroTicks: u64 = 9;
const EInvalidBandOrder: u64 = 10;
const EInsufficientBaseAsset: u64 = 11;
const EInsufficientQuoteAsset: u64 = 12;
const EInvalidPool: u64 = 13;
const EInvalidTickSize: u64 = 14;
const EInvalidMidPrice: u64 = 15;
const EInvalidOrderSize: u64 = 16;

/// Event emitted when a deposit or withdrawal occurs
public struct BalanceEvent has copy, drop {
  vault: ID,
  user: address,
  base_asset_amount: u64,
  quote_asset_amount: u64,
  lp_amount: u64,
  deposit: bool
}

/// Event emitted when orbital orders are created
public struct OrbitalOrdersEvent has copy, drop {
  vault: ID,
  user: address,
  mid_price: u64,
  order_size_lots: u64,
  tick_count: u64,
  created_at: u64,
  expires_at: u64
}

/// Event emitted when config is updated
public struct ConfigUpdatedEvent has copy, drop {
  vault: ID,
  user: address,
  tick_count: u64,
  max_skew_percent: u64
}

/// Tick configuration for orbital order placement
public struct OrbitalTickConfig has copy, drop, store {
  /// Half-band distance from the mid price, in basis points
  band_bps: u64,
  /// Weight of this tick's order size, in basis points
  weight_bps: u64
}

/// Orbital configuration parameters
public struct OrbitalConfig has store, drop {
  ticks: vector<OrbitalTickConfig>,
  /// Maximum skew adjustment as a percentage (0-100)
  max_skew_percent: u64
}

/// A shared object that holds funds used by the orbital market maker
public struct OrbitalVault<phantom BaseAsset, phantom QuoteAsset, phantom T> has key, store {
  id: UID,
  lp_treasury_cap: TreasuryCap<T>,
  balance_manager: balance_manager::BalanceManager,
  base_price_id: vector<u8>,
  quote_price_id: vector<u8>,
  pool_id: ID,
  config: OrbitalConfig
}

/// Trading capability
public struct TradingCap has key, store {
  id: UID,
  vault_id: ID,
}

/// === Initialization ===

/// Initializes and shares an orbital vault object
public fun create_orbital_vault<BaseAsset, QuoteAsset, T>(
  lp_treasury_cap: TreasuryCap<T>,
  base_price_id: vector<u8>,
  quote_price_id: vector<u8>,
  pool_id: ID,
  ticks: vector<OrbitalTickConfig>,
  max_skew_percent: u64,
  ctx: &mut TxContext
): TradingCap {
  let config = OrbitalConfig { ticks, max_skew_percent };
  validate_config(&config);

  let vault = OrbitalVault<BaseAsset, QuoteAsset, T> {
    id: object::new(ctx),
    lp_treasury_cap,
    balance_manager: balance_manager::new(ctx),
    base_price_id,
    quote_price_id,
    pool_id,
    config
  };

  let vault_id = object::id(&vault);
  sui::transfer::share_object(vault);

  TradingCap {
    id: object::new(ctx),
    vault_id
  }
}

/// Updates orbital config (only TradingCap holder)
public fun update_config<BaseAsset, QuoteAsset, T>(
  cap: &TradingCap,
  vault: &mut OrbitalVault<BaseAsset, QuoteAsset, T>,
  ticks: vector<OrbitalTickConfig>,
  max_skew_percent: u64,
  ctx: &TxContext
) {
  assert!(cap.vault_id == object::id(vault), EUnauthorized);
  let config = OrbitalConfig { ticks, max_skew_percent };
  validate_config(&config);
  vault.config = config;

  event::emit(ConfigUpdatedEvent {
    vault: object::id(vault),
    user: ctx.sender(),
    tick_count: vector::length(&vault.config.ticks),
    max_skew_percent: vault.config.max_skew_percent
  });
}

/// === Liquidity Operations ===

/// Deposits into the orbital vault and mints LP tokens
public fun deposit<BaseAsset, QuoteAsset, T>(
  vault: &mut OrbitalVault<BaseAsset, QuoteAsset, T>,
  base_coin: Coin<BaseAsset>,
  quote_coin: Coin<QuoteAsset>,
  base_asset_price_info_object: &PriceInfoObject,
  quote_asset_price_info_object: &PriceInfoObject,
  clock: &Clock,
  ctx: &mut TxContext,
): Coin<T> {
  let base_deposit_amount = base_coin.value();
  let quote_deposit_amount = quote_coin.value();

  let (base_price, base_expo) = get_price(vault.base_price_id, base_asset_price_info_object, clock);
  let (quote_price, quote_expo) = get_price(vault.quote_price_id, quote_asset_price_info_object, clock);
  let normalized_base_price = normalize_price(&base_price, &base_expo);
  let normalized_quote_price = normalize_price(&quote_price, &quote_expo);

  let base_value_scaled = (base_deposit_amount as u256) * normalized_base_price;
  let quote_value_scaled = (quote_deposit_amount as u256) * normalized_quote_price;
  let deposit_value = base_value_scaled + quote_value_scaled;

  let total_lp_supply = vault.lp_treasury_cap.total_supply();
  let lp_tokens_to_mint = if (total_lp_supply == 0) {
    deposit_value
  } else {
    let total_vault_value = get_total_value(
      vault,
      base_asset_price_info_object,
      quote_asset_price_info_object,
      clock
    );
    deposit_value * (total_lp_supply as u256) / total_vault_value
  };

  assert!(lp_tokens_to_mint <= ((0xFFFFFFFFFFFFFFFFu64) as u256), EMintAmountTooLarge);

  vault.balance_manager.deposit(base_coin, ctx);
  vault.balance_manager.deposit(quote_coin, ctx);

  let lp = vault.lp_treasury_cap.mint(lp_tokens_to_mint as u64, ctx);

  event::emit(BalanceEvent {
    vault: object::id(vault),
    user: ctx.sender(),
    base_asset_amount: base_deposit_amount,
    quote_asset_amount: quote_deposit_amount,
    lp_amount: lp_tokens_to_mint as u64,
    deposit: true
  });

  lp
}

/// Withdraws from the orbital vault
public fun withdraw<BaseAsset, QuoteAsset, T>(
  vault: &mut OrbitalVault<BaseAsset, QuoteAsset, T>,
  lp_coin: Coin<T>,
  ctx: &mut TxContext,
): (Coin<BaseAsset>, Coin<QuoteAsset>) {
  let lp_amount = lp_coin.value();

  let total_lp_supply = vault.lp_treasury_cap.total_supply();
  let (total_base_balance, total_quote_balance) = get_vault_balance(vault);

  let base_to_withdraw = (total_base_balance as u256) * (lp_amount as u256) / (total_lp_supply as u256);
  let quote_to_withdraw = (total_quote_balance as u256) * (lp_amount as u256) / (total_lp_supply as u256);

  assert!(base_to_withdraw <= ((0xFFFFFFFFFFFFFFFFu64) as u256), EWithdrawAmountTooLarge);
  assert!(quote_to_withdraw <= ((0xFFFFFFFFFFFFFFFFu64) as u256), EWithdrawAmountTooLarge);

  let base_coin = vault.balance_manager.withdraw<BaseAsset>(base_to_withdraw as u64, ctx);
  let quote_coin = vault.balance_manager.withdraw<QuoteAsset>(quote_to_withdraw as u64, ctx);

  vault.lp_treasury_cap.burn(lp_coin);

  event::emit(BalanceEvent {
    vault: object::id(vault),
    user: ctx.sender(),
    base_asset_amount: base_coin.value(),
    quote_asset_amount: quote_coin.value(),
    lp_amount: lp_amount,
    deposit: false,
  });

  (base_coin, quote_coin)
}

/// === Trading ===

/// Generates a trade proof for the vault's balance manager
public fun generate_trade_proof<BaseAsset, QuoteAsset, T>(
  cap: &TradingCap,
  vault: &mut OrbitalVault<BaseAsset, QuoteAsset, T>,
  ctx: &TxContext,
): balance_manager::TradeProof {
  assert!(cap.vault_id == object::id(vault), EUnauthorized);
  balance_manager::generate_proof_as_owner(&mut vault.balance_manager, ctx)
}

/// Places orbital orders on a DeepBook pool
public fun place_orbital_orders<BaseAsset, QuoteAsset, T>(
  cap: &TradingCap,
  vault: &mut OrbitalVault<BaseAsset, QuoteAsset, T>,
  trade_proof: &TradeProof,
  pool: &mut Pool<BaseAsset, QuoteAsset>,
  order_size_lots: u64,
  order_type: u8,
  self_matching_option: u8,
  pay_with_deep: bool,
  expire_timestamp: u64,
  clock: &Clock,
  ctx: &mut TxContext
) {
  assert!(cap.vault_id == object::id(vault), EUnauthorized);
  assert!(object::id(pool) == vault.pool_id, EInvalidPool);
  assert!(expire_timestamp > clock.timestamp_ms(), EExpiredTimestamp);
  assert!(order_size_lots > 0, EInvalidOrderSize);

  let (tick_size, lot_size, min_size) = pool_book_params(pool);
  assert!(tick_size > 0, EInvalidTickSize);

  let min_lots = div_ceil_u64(min_size, lot_size);
  let tick_count = vector::length(&vault.config.ticks);
  assert!(tick_count > 0, EZeroTicks);

  let min_total_lots = (min_lots as u128) * (tick_count as u128);
  assert!((order_size_lots as u128) >= min_total_lots, EOrderSizeTooSmall);

  let mid = mid_price(pool, clock);
  assert!(mid > 0, EInvalidMidPrice);

  let (bid_scale, ask_scale) = compute_skew_scales<BaseAsset, QuoteAsset, T>(vault, mid);

  let sizes = allocate_tick_lots(order_size_lots, min_lots, &vault.config.ticks);

  // Precompute and validate that balances are sufficient
  let mut total_ask_base: u128 = 0;
  let mut total_bid_quote: u128 = 0;

  let mut i = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&vault.config.ticks, i);
    let tick_lots = *vector::borrow(&sizes, i);

    let bid_lots = mul_div_u128(tick_lots as u128, bid_scale as u128, PERCENT as u128);
    let ask_lots = mul_div_u128(tick_lots as u128, ask_scale as u128, PERCENT as u128);

    let bid_price = align_price_down(apply_band_bps(mid, tick.band_bps, true), tick_size);
    let bid_base = (bid_lots as u128) * (lot_size as u128);
    let ask_base = (ask_lots as u128) * (lot_size as u128);

    total_ask_base = total_ask_base + ask_base;
    total_bid_quote = total_bid_quote + (bid_base * (bid_price as u128));

    i = i + 1;
  };

  let base_balance = balance<BaseAsset>(&vault.balance_manager) as u128;
  let quote_balance = balance<QuoteAsset>(&vault.balance_manager) as u128;

  assert!(total_ask_base <= base_balance, EInsufficientBaseAsset);
  assert!(total_bid_quote <= quote_balance, EInsufficientQuoteAsset);

  // Place orders
  let mut j = 0;
  while (j < tick_count) {
    let tick = vector::borrow(&vault.config.ticks, j);
    let tick_lots = *vector::borrow(&sizes, j);

    let bid_lots_u128 = mul_div_u128(tick_lots as u128, bid_scale as u128, PERCENT as u128);
    let ask_lots_u128 = mul_div_u128(tick_lots as u128, ask_scale as u128, PERCENT as u128);

    let bid_lots = bid_lots_u128 as u64;
    let ask_lots = ask_lots_u128 as u64;
    let bid_quantity = bid_lots_u128 * (lot_size as u128);
    let ask_quantity = ask_lots_u128 * (lot_size as u128);

    let bid_price = align_price_down(apply_band_bps(mid, tick.band_bps, true), tick_size);
    let ask_price = align_price_up(apply_band_bps(mid, tick.band_bps, false), tick_size);

    if (bid_lots > 0) {
      place_limit_order<BaseAsset, QuoteAsset>(
        pool,
        &mut vault.balance_manager,
        trade_proof,
        0,
        order_type,
        self_matching_option,
        bid_price,
        bid_quantity as u64,
        true,
        pay_with_deep,
        expire_timestamp,
        clock,
        ctx
      );
    };

    if (ask_lots > 0) {
      place_limit_order<BaseAsset, QuoteAsset>(
        pool,
        &mut vault.balance_manager,
        trade_proof,
        0,
        order_type,
        self_matching_option,
        ask_price,
        ask_quantity as u64,
        false,
        pay_with_deep,
        expire_timestamp,
        clock,
        ctx
      );
    };

    j = j + 1;
  };

  event::emit(OrbitalOrdersEvent {
    vault: object::id(vault),
    user: ctx.sender(),
    mid_price: mid,
    order_size_lots,
    tick_count: tick_count as u64,
    created_at: clock.timestamp_ms(),
    expires_at: expire_timestamp,
  });
}

/// === Views ===

/// Gets total balance of base and quote assets
public fun get_vault_balance<BaseAsset, QuoteAsset, T>(
  vault: &OrbitalVault<BaseAsset, QuoteAsset, T>
): (u64, u64) {
  (vault.balance_manager.balance<BaseAsset>(), vault.balance_manager.balance<QuoteAsset>())
}

/// Gets total value of the vault using Pyth prices
public fun get_total_value<BaseAsset, QuoteAsset, T>(
  vault: &OrbitalVault<BaseAsset, QuoteAsset, T>,
  base_asset_price_info_object: &PriceInfoObject,
  quote_asset_price_info_object: &PriceInfoObject,
  clock: &Clock,
): u256 {
  let (base_price, base_expo) = get_price(vault.base_price_id, base_asset_price_info_object, clock);
  let (quote_price, quote_expo) = get_price(vault.quote_price_id, quote_asset_price_info_object, clock);

  let normalized_base_price = normalize_price(&base_price, &base_expo);
  let normalized_quote_price = normalize_price(&quote_price, &quote_expo);

  let mut total_value: u256 = 0;

  total_value = total_value + (vault.balance_manager.balance<BaseAsset>() as u256) * normalized_base_price;
  total_value = total_value + (vault.balance_manager.balance<QuoteAsset>() as u256) * normalized_quote_price;

  total_value
}

/// === Internal Helpers ===

fun validate_config(config: &OrbitalConfig) {
  let tick_count = vector::length(&config.ticks);
  assert!(tick_count > 0, EZeroTicks);
  assert!(config.max_skew_percent <= MAX_SKEW_PERCENT, EInvalidSkew);

  let mut total_weight: u64 = 0;
  let mut i = 0;
  let mut last_band: u64 = 0;
  while (i < tick_count) {
    let tick = vector::borrow(&config.ticks, i);
    assert!(tick.band_bps > 0, EInvalidBand);
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

fun allocate_tick_lots(
  order_size_lots: u64,
  min_lots_per_tick: u64,
  ticks: &vector<OrbitalTickConfig>
): vector<u64> {
  let tick_count = vector::length(ticks);
  let mut sizes = vector::empty<u64>();

  let mut i = 0;
  let mut allocated_base: u64 = 0;
  while (i < tick_count) {
    vector::push_back(&mut sizes, min_lots_per_tick);
    allocated_base = allocated_base + min_lots_per_tick;
    i = i + 1;
  };

  if (allocated_base == order_size_lots) {
    return sizes
  };

  let remainder = order_size_lots - allocated_base;

  let mut j = 0;
  let mut allocated_extra: u64 = 0;
  while (j < tick_count) {
    let tick = vector::borrow(ticks, j);
    let extra = mul_div_u128(remainder as u128, tick.weight_bps as u128, BPS as u128) as u64;
    let slot = vector::borrow_mut(&mut sizes, j);
    *slot = *slot + extra;
    allocated_extra = allocated_extra + extra;
    j = j + 1;
  };

  if (allocated_extra < remainder) {
    let delta = remainder - allocated_extra;
    let first = vector::borrow_mut(&mut sizes, 0);
    *first = *first + delta;
  };

  sizes
}

#[test_only]
public fun test_validate_config(ticks: vector<OrbitalTickConfig>, max_skew_percent: u64) {
  let config = OrbitalConfig { ticks, max_skew_percent };
  validate_config(&config);
}

#[test_only]
public fun test_allocate_tick_lots(
  order_size_lots: u64,
  min_lots_per_tick: u64,
  ticks: vector<OrbitalTickConfig>
): vector<u64> {
  allocate_tick_lots(order_size_lots, min_lots_per_tick, &ticks)
}

public fun new_tick_config(band_bps: u64, weight_bps: u64): OrbitalTickConfig {
  OrbitalTickConfig { band_bps, weight_bps }
}

#[test_only]
public fun test_seed_balances<BaseAsset, QuoteAsset, T>(
  vault: &mut OrbitalVault<BaseAsset, QuoteAsset, T>,
  base_coin: Coin<BaseAsset>,
  quote_coin: Coin<QuoteAsset>,
  ctx: &mut TxContext
) {
  vault.balance_manager.deposit(base_coin, ctx);
  vault.balance_manager.deposit(quote_coin, ctx);
}

fun compute_skew_scales<BaseAsset, QuoteAsset, T>(
  vault: &OrbitalVault<BaseAsset, QuoteAsset, T>,
  mid: u64
): (u64, u64) {
  let base_balance = balance<BaseAsset>(&vault.balance_manager) as u128;
  let quote_balance = balance<QuoteAsset>(&vault.balance_manager) as u128;

  if (quote_balance == 0) {
    let capped = vault.config.max_skew_percent;
    return (PERCENT - capped, PERCENT + capped)
  };

  let base_in_quote = (base_balance as u128) * (mid as u128);
  let imbalance_ratio = (PERCENT as u128) * base_in_quote / quote_balance;

  if (imbalance_ratio == (PERCENT as u128)) {
    return (PERCENT, PERCENT)
  } else if (imbalance_ratio > (PERCENT as u128)) {
    let skew = min((imbalance_ratio - (PERCENT as u128)) as u64, vault.config.max_skew_percent);
    return (PERCENT - skew, PERCENT + skew)
  } else {
    let skew = min(((PERCENT as u128) - imbalance_ratio) as u64, vault.config.max_skew_percent);
    return (PERCENT + skew, PERCENT - skew)
  }
}

fun apply_band_bps(mid: u64, band_bps: u64, is_bid: bool): u64 {
  let delta = mul_div_u128(mid as u128, band_bps as u128, BPS as u128) as u64;
  if (is_bid) {
    mid - delta
  } else {
    mid + delta
  }
}

fun align_price_down(price: u64, tick_size: u64): u64 {
  price / tick_size * tick_size
}

fun align_price_up(price: u64, tick_size: u64): u64 {
  let rem = price % tick_size;
  if (rem == 0) {
    price
  } else {
    let div = price / tick_size;
    let next = (div as u128) + 1;
    (next * (tick_size as u128)) as u64
  }
}

fun mul_div_u128(a: u128, b: u128, denom: u128): u128 {
  (a * b) / denom
}

fun div_ceil_u64(n: u64, d: u64): u64 {
  if (n % d == 0) {
    n / d
  } else {
    n / d + 1
  }
}

/// === Pricing Helpers (Pyth) ===

/// Gets price of asset
public fun get_price(
  coin_price_id: vector<u8>,
  price_info_object: &PriceInfoObject,
  clock: &Clock
): (i64::I64, i64::I64) {
  let max_age = 60;
  let price_struct = pyth::get_price_no_older_than(price_info_object, clock, max_age);
  let price_info = price_info::get_price_info_from_price_info_object(price_info_object);
  let price_id = price_identifier::get_bytes(&price_info::get_price_identifier(&price_info));

  assert!(price_id == coin_price_id, EInvalidID);

  let price = price::get_price(&price_struct);
  let expo = price::get_expo(&price_struct);

  (price, expo)
}

/// Normalizes the price to 1e8
fun normalize_price(price: &i64::I64, expo: &i64::I64): u256 {
  let price_magnitude = if (price.get_is_negative()) {
    price.get_magnitude_if_negative()
  } else {
    price.get_magnitude_if_positive()
  };

  let expo_magnitude = if (expo.get_is_negative()) {
    expo.get_magnitude_if_negative()
  } else {
    expo.get_magnitude_if_positive()
  };

  let target_expo: u64 = 8;

  let normalized_price = if (expo.get_is_negative()) {
    if (expo_magnitude >= target_expo) {
      let scale_down = std::u64::pow(10, (expo_magnitude - target_expo) as u8);
      (price_magnitude as u256) / (scale_down as u256)
    } else {
      let scale_up = std::u64::pow(10, (target_expo - expo_magnitude) as u8);
      (price_magnitude as u256) * (scale_up as u256)
    }
  } else {
    let scale_up = std::u64::pow(10, (expo_magnitude + target_expo) as u8);
    (price_magnitude as u256) * (scale_up as u256)
  };

  normalized_price
}
