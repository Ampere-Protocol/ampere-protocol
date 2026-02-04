# Ampere Protocol (Move)

## Abstract
Ampere implements a 3‑asset Orbital AMM in Sui Move, modeled after the Orbital design presented by Paradigm. Orbital extends concentrated liquidity to pools of three or more stablecoins by shaping liquidity around the equal‑price point and enabling multi‑asset trading in a single pool. This repository includes:
- `orbital_pool3`: a user‑facing 3‑asset AMM based on the Orbital sphere invariant.
- `orbital_vault`: a DeepBook market‑making vault for pairwise order placement (optional).

This README describes the concept, the architecture, and the math behind the AMM, and explains why Orbital is more capital‑efficient than existing designs for stablecoin baskets.

## Background and Motivation
Paradigm’s Orbital paper argues that:
- Uniswap v3 pioneered concentrated liquidity but only supports two assets per pool.
- Curve supports multi‑asset stable pools but uses a uniform strategy across LPs.
- Orbital extends customizable concentrated liquidity to 3+ stablecoins with “orbits” around the $1 equal‑price point and supports depeg resilience even when one coin collapses.

Orbital’s goal is to concentrate liquidity where stablecoins actually trade (near parity) while still supporting multi‑asset pools.

## System Architecture
1. **Orbital AMM Layer (`orbital_pool3`)**
   - Implements a 3‑asset pool with direct swaps among A/B/C.
   - Maintains LP shares and reserves.
   - Applies fees to input and updates the invariant after each swap.
2. **DeepBook MM Layer (`orbital_vault`)**
   - Optional market‑making vault for pairwise DeepBook pools (A/B, A/C, B/C).
   - Not part of the swap engine; used to quote external orderbooks.

## Orbital Model (Theory)
### Invariant (Sphere AMM)
Let reserves be normalized to 18 decimals: `x`, `y`, `z`. The invariant is:
```
(R - x)^2 + (R - y)^2 + (R - z)^2 = L^2
```
`R` is a fixed radius, and `L^2` is stored in the pool.

### Exact Input Swap
For input `dx` (net of fees) into `x` and output `dy` from `y`:
```
term_x_new = (R - (x + dx))^2
term_z     = (R - z)^2
term_y_new = L^2 - term_x_new - term_z

y_new = R - sqrt(term_y_new)

dy = y - y_new
```

### Exact Output Swap
For desired output `dy` from `y`:
```
term_y_new = (R - (y - dy))^2
term_z     = (R - z)^2
term_x_new = L^2 - term_y_new - term_z

x_new = R - sqrt(term_x_new)

dx = x_new - x
```

### Fees
Fees are applied to input:
```
fee = amount_in * LP_FEE / FEE_DENOMINATOR
amount_in_net = amount_in - fee
```
For exact‑output swaps, input is grossed up by fee:
```
amount_in = amount_in_raw * FEE_DENOMINATOR / (FEE_DENOMINATOR - LP_FEE) + 1
```

## Implementation Notes
- `orbital_pool3` implements a **multi‑tick Orbital AMM**. Each tick is a weighted slice of liquidity with its own per‑tick invariant, and swaps are routed across ticks by their liquidity weight.
- The full Orbital design includes **boundary‑state transitions** and explicit **torus consolidation** as ticks move between interior and boundary states. This repository does not yet implement those state transitions; it provides weighted multi‑tick routing over per‑tick sphere invariants.

## Ticks (Concept)
Orbital “ticks” are **concentric orbits around the equal‑price point**. In this implementation:
1. Each tick has `band_bps` (distance from parity) and `weight_bps` (share of liquidity).
2. Liquidity deposits are split across ticks by `weight_bps`.
3. Each tick keeps its own reserves and `L^2` invariant.
4. Swaps are **routed across ticks** proportionally to tick liquidity (sum of reserves), so all ticks participate.

This mirrors the Orbital idea of distributing liquidity across multiple orbits around parity, while keeping a simple, deterministic routing rule.

## Why Orbital is Better (for Stablecoin Baskets)
Compared to existing designs:
- **Uniswap v3 (2‑asset only):** Concentrated liquidity is powerful but limited to two tokens. Orbital generalizes concentrated liquidity to 3+ stablecoins by defining tick boundaries as orbits around the equal‑price point.
- **Curve (multi‑asset but uniform):** Curve allows N‑asset stable pools but uses a uniform invariant per pool; LPs cannot customize exposure. Orbital lets LPs choose how tightly they concentrate around parity via different orbital ticks.
- **Depeg resilience:** Orbital ticks can continue trading the remaining stablecoins at fair prices even if one token collapses to zero, because ticks are defined around the equal‑price point rather than a single pair.
- **Capital efficiency:** Liquidity near parity can be concentrated tightly without over‑reserving for large depegs, leading to higher capital efficiency near $1 trading.

## Flows (Alice/Bob)
### Alice Adds Liquidity
1. Alice creates a pool with a tick configuration, for example:
```
ticks = [
  (band_bps = 50,  weight_bps = 6000),
  (band_bps = 100, weight_bps = 4000)
]
```
2. Alice calls `create_pool3` with `ticks` and the LP treasury cap.
3. Alice calls `add_liquidity` with `(Coin<A>, Coin<B>, Coin<C>)`.
4. Liquidity is split across ticks by `weight_bps`, LP shares are minted, and each tick’s `L^2` is updated.

### Bob Swaps
1. Bob wants `B` and sends `Coin<A>` to `swap_a_for_b_exact_in`.
2. The pool routes the swap across ticks by liquidity weight.
3. Each tick computes its own output from its invariant, and the outputs are aggregated.
4. Bob receives `Coin<B>`.

### Alice Withdraws
1. Alice burns LP shares via `remove_liquidity`.
2. She receives proportional amounts of all three assets.

### Alice and Bob (Vault + DeepBook)
1. Alice deploys `orbital_vault` with tick configs for order placement bands.
2. Alice deposits `Coin<Base>` and `Coin<Quote>` into the vault.
3. Bob trades on DeepBook; the vault places orbital‑style limit orders around the mid price.
4. Alice later withdraws LP tokens and receives her share of vault balances.

## API Summary (Orbital AMM)
- `create_pool3`
- `add_liquidity`
- `remove_liquidity`
- `swap_*_exact_in`
- `swap_*_exact_out`
- `quote_*`

## Tests
```
sui move test
```
