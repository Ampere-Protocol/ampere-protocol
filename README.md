# Ampere Protocol

A concentrated liquidity AMM protocol on Sui with multi-tick orbital pools for optimal capital efficiency.

## 🚀 Overview

Ampere Protocol implements a 3-asset concentrated liquidity pool (OrbitalPool3) that distributes liquidity across multiple price bands (ticks) for improved capital efficiency. Each tick represents a concentrated liquidity range with configurable bands and weights.

### Key Features

- **3-Asset Pools**: Trade between three assets (e.g., USDC/USDT/SUI) in a single pool
- **Multi-Tick Architecture**: Distribute liquidity across multiple price ranges
- **Concentrated Liquidity**: Higher capital efficiency than traditional AMMs
- **TypeScript SDK**: Easy integration with your applications
- **Testnet Deployment**: Live on Sui Testnet

## 📍 Deployed Addresses (Sui Testnet)

### Main Package
```
Ampere Protocol Package: 0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf
Test Tokens Package:     0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7
```

### Deployed Pool
```
Pool ID:                 0x3d696725312d22e0c92305385857a9a8fe25bb85c374babd34d9536af3ca15f2
Initial Shared Version:  349181292
Pool Type:               USDC/USDT/SUI
```

### Treasury Caps
```
USDC Treasury: 0xe031699bcf32c5fd6c80f2911fba491c1b90056c73420fe70eed9405b2023097
USDT Treasury: 0x2a8d421bb9f8b7e281a2d16322b2e1dfa2d286e975b8e30e2159e2a113c94a5e
LP Treasury:   0x66e102ed0de02d1ca7f90540d2554d6bcdfe2b9d56b3760cc1431e4a6a4b848f (wrapped in pool)
```

### Token Types
```
USDC: 0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::usdc::USDC
USDT: 0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::usdt::USDT
SUI:  0x2::sui::SUI
LP:   0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::lp::LP
```

### Pool Configuration
```
Tick 1: 0.5% band (50 bps)  | 60% weight (6000 bps)
Tick 2: 1.0% band (100 bps) | 40% weight (4000 bps)

Decimals:
- USDC: 6
- USDT: 6
- SUI:  9
```

## 🛠️ Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/ampere-protocol.git
cd ampere-protocol

# Install dependencies
bun install

# Set up environment
cp .env.example .env
# Edit .env with your SUI_PRIVATE_KEY
```

## 📚 Quick Start

### 1. Add Liquidity
```bash
bun run scripts/mint-and-add-liquidity-single-tx.ts
```

### 2. Swap Tokens
```bash
bun run scripts/swap-demo.ts
```

### 3. Remove Liquidity
```bash
LP_COIN=<your_lp_token_id> bun run scripts/remove-liquidity-demo.ts
```

### 4. Check Balances
```bash
bun run scripts/check-balances.ts
```

## 🔧 Available Scripts

### Pool Operations
- `create-orbital-pool.ts` - Create a new 3-asset pool
- `add-liquidity.ts` - Add liquidity to existing pool
- `add-liquidity-with-ticks.ts` - Add liquidity with tick info
- `remove-liquidity.ts` - Remove liquidity from pool
- `mint-and-add-liquidity-single-tx.ts` - Mint tokens and add liquidity in one tx

### Trading
- `swap-exact-in.ts` - Swap with exact input amount
- `swap-demo.ts` - Demo swap script (USDC→SUI)
- `quote-exact-in.ts` - Get swap quote without executing

### Utilities
- `check-balances.ts` - View user balances and pool reserves
- `setup-env.sh` - Set up environment variables

## 📖 SDK Usage

```typescript
import { OrbitalSdk, createSdkConfig } from "./src/sdk";
import { Transaction } from "@mysten/sui/transactions";

// Initialize SDK
const sdk = new OrbitalSdk(createSdkConfig({ 
  packageId: "0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf" 
}));

// Add liquidity
const tx = sdk.pool3.addLiquidityTx({
  pool: { 
    objectId: poolId, 
    initialSharedVersion: "349181292", 
    mutable: true 
  },
  coinA: usdcCoinId,
  coinB: usdtCoinId,
  coinC: suiCoinId,
  typeArgs: [USDC_TYPE, USDT_TYPE, SUI_TYPE, LP_TYPE],
});

// Swap tokens
const swapTx = sdk.pool3.swapExactInTx({
  pool: { objectId: poolId, initialSharedVersion: "349181292", mutable: true },
  coinIn: usdcCoinId,
  route: "AtoC", // USDC → SUI
  typeArgs: [USDC_TYPE, USDT_TYPE, SUI_TYPE, LP_TYPE],
});
```

## 🏗️ Architecture

### OrbitalPool3 Structure
```
Pool
├── Tick 1 (Tight concentration)
│   ├── Band: 0.5%
│   ├── Weight: 60%
│   └── Reserves: [USDC, USDT, SUI]
└── Tick 2 (Wider spread)
    ├── Band: 1.0%
    ├── Weight: 40%
    └── Reserves: [USDC, USDT, SUI]
```

### Swap Routes
- `AtoB` - USDC → USDT
- `AtoC` - USDC → SUI
- `BtoA` - USDT → USDC
- `BtoC` - USDT → SUI
- `CtoA` - SUI → USDC
- `CtoB` - SUI → USDT

## 🧪 Testing

```bash
# Run tests
bun test

# Run specific test
bun test tests/sdk/orbitalPool3.test.ts
```

## 📝 Environment Variables

Create a `.env` file with the following:

```bash
# Network
SUI_RPC=https://fullnode.testnet.sui.io:443

# Wallet
SUI_PRIVATE_KEY=your_private_key_here
SENDER=your_address_here

# Deployed Packages
PACKAGE_ID=0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf
TEST_TOKENS_PACKAGE=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7

# Treasury Caps
USDC_TREASURY=0xe031699bcf32c5fd6c80f2911fba491c1b90056c73420fe70eed9405b2023097
USDT_TREASURY=0x2a8d421bb9f8b7e281a2d16322b2e1dfa2d286e975b8e30e2159e2a113c94a5e
LP_TREASURY_CAP=0x66e102ed0de02d1ca7f90540d2554d6bcdfe2b9d56b3760cc1431e4a6a4b848f

# Pool Configuration
POOL_ID=0x3d696725312d22e0c92305385857a9a8fe25bb85c374babd34d9536af3ca15f2
POOL_SHARED_VERSION=349181292

# Type Arguments
TYPE_A=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::usdc::USDC
TYPE_B=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::usdt::USDT
TYPE_C=0x2::sui::SUI
TYPE_LP=0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7::lp::LP

# Decimals
DECIMALS_A=6
DECIMALS_B=6
DECIMALS_C=9
```

## 🔍 Pool Explorer

View the pool on Sui Explorer:
- Pool: https://testnet.suivision.xyz/object/0x3d696725312d22e0c92305385857a9a8fe25bb85c374babd34d9536af3ca15f2
- Package: https://testnet.suivision.xyz/package/0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- Documentation: [SDK.md](./SDK.md)
- Deployment Guide: [DEPLOYMENT.md](./DEPLOYMENT.md)
- Scripts Guide: [scripts/README.md](./scripts/README.md)

## ⚠️ Disclaimer

This is experimental software deployed on testnet. Use at your own risk. Not audited for production use.
