# Scripts

These scripts use the SDK to create and interact with Orbital pools.

## Quick Start

1. **Set up your environment:**
   ```bash
   cd scripts
   ./setup-env.sh
   source .env
   ```

2. **Mint test tokens:**
   ```bash
   bun run ../examples/mint-tokens.ts
   ```

3. **Add liquidity to the pool:**
   ```bash
   COIN_A=<usdc_coin_id> COIN_B=<usdt_coin_id> COIN_C=<sui_coin_id> \
   bun run scripts/add-liquidity.ts
   ```

4. **Perform a swap:**
   ```bash
   COIN_IN=<coin_id> ROUTE=AtoB \
   bun run scripts/swap-exact-in.ts
   ```

## Current Pool

**Pool ID:** `0x3d696725312d22e0c92305385857a9a8fe25bb85c374babd34d9536af3ca15f2`
**Shared Version:** `349181292`
**Pool Type:** USDC/USDT/SUI with LP token

## Required Env Vars
- `SUI_RPC`
- `SUI_PRIVATE_KEY`
- `PACKAGE_ID`
- `TYPE_A`
- `TYPE_B`
- `TYPE_C`
- `TYPE_LP`
- `DECIMALS_A`
- `DECIMALS_B`
- `DECIMALS_C`

Optional:
- `TICKS_JSON` (defaults to two ticks: `50/6000`, `100/4000`)

## Create Pool
```
LP_TREASURY_CAP=0x... \
SUI_RPC=... PACKAGE_ID=... SUI_PRIVATE_KEY=... \
TYPE_A=... TYPE_B=... TYPE_C=... TYPE_LP=... \
DECIMALS_A=6 DECIMALS_B=6 DECIMALS_C=9 \
bun run scripts/create-orbital-pool.ts
```

## Add Liquidity
```
POOL_ID=0x... POOL_SHARED_VERSION=1 \
COIN_A=0x... COIN_B=0x... COIN_C=0x... \
SUI_RPC=... PACKAGE_ID=... SUI_PRIVATE_KEY=... \
TYPE_A=... TYPE_B=... TYPE_C=... TYPE_LP=... \
bun run scripts/add-liquidity.ts
```

## Swap Exact In
```
POOL_ID=0x... POOL_SHARED_VERSION=1 \
COIN_IN=0x... ROUTE=AtoB \
SUI_RPC=... PACKAGE_ID=... SUI_PRIVATE_KEY=... \
TYPE_A=... TYPE_B=... TYPE_C=... TYPE_LP=... \
bun run scripts/swap-exact-in.ts
```

## Quote Exact In (A->B)
```
POOL_ID=0x... POOL_SHARED_VERSION=1 \
AMOUNT_IN=1000000 SENDER=0x... \
SUI_RPC=... PACKAGE_ID=... \
TYPE_A=... TYPE_B=... TYPE_C=... TYPE_LP=... \
bun run scripts/quote-exact-in.ts
```
