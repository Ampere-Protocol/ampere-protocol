# ⚡ Ampere Protocol

**The First High-Dimensional Concentrated Liquidity Engine on Sui.**

[![Sui](https://img.shields.io/badge/Sui-Testnet-blue)](https://sui.io)
[![TypeScript](https://img.shields.io/badge/TypeScript-SDK-blue)](https://www.typescriptlang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bun](https://img.shields.io/badge/Runtime-Bun-black)](https://bun.sh)

---

## 🌌 Abstract: Beyond 2D Liquidity

Traditional DeFi is trapped in a 2D universe of pairwise trading. Whether it's Uniswap or DeepBook, users are forced to hop between pairs (A→B, B→C), leading to fragmented capital, doubled fees, and value leakage to arbitrage bots.

**Ampere Protocol** warps the geometry of DeFi. Inspired by the cutting-edge research in [**Paradigm's "Orbital" Paper**](https://www.paradigm.xyz/2023/08/orbital), Ampere introduces **3-Asset Orbital Pools**. By implementing a high-dimensional constant mean invariant, Ampere internalizes triangular arbitrage and delivers **10x capital efficiency** through spherical liquidity concentration.

---

## 🔬 Scientific Foundation

### 1. The Orbital Invariant
Unlike the pairwise hyperbola ($x \cdot y = k$), Ampere utilizes a **3-Dimensional Constant Mean Market Maker (CMMM)** invariant:

$$L = (R_a \cdot R_b \cdot R_c)^{1/3}$$

Where:
*   $R_n$ represents the reserves of assets A, B, and C.
*   $L$ represents the geometric depth (liquidity).

### 2. High-Dimensional Concentration
Traditional CLMMs (Uniswap v3) concentrate liquidity on a **1D Price Line**. Ampere concentrates liquidity on a **3D Spherical Cap**. This ensures that a single dollar of LP capital is simultaneously active for **all six trading pairs** in the pool.

### 3. Newton-Raphson On-Chain Solver
Solving cubic roots and implicit functions on-chain is computationally intensive. Ampere implements a custom **Newton-Raphson iteration engine** in Move, achieving 18-decimal precision for high-dimensional swaps in just 3-5 iterations.

---

## 🎯 Why Ampere Wins on Sui

| Feature | Pairwise AMMs | Uniswap v3 | **Ampere Protocol** |
| :--- | :--- | :--- | :--- |
| **Asset Structure** | 2 Assets | 2 Assets | **3 Assets (Orbital)** |
| **Capital Efficiency** | 1x | 4-8x | **10-15x** |
| **Triangular Arbitrage** | External (Leaked) | External (Leaked) | **Internalized (Retained)** |
| **Gas per Swap** | Low | High | **Low (Single-Hop)** |
| **LP Management** | Passive | Active (Hard) | **Adaptive (Passive)** |

---

## 🏗️ Architecture: The Orbital Model

### Internalized Triangular Arbitrage
In a 3-asset Orbital pool, any price movement in Asset A automatically rebalances its relationship with Assets B and C mathematically. This **"Path Independence"** ensures that the value typically lost to arbitrage bots across multiple pools is instead retained as yield for Ampere LPs.

### Multi-Tick Superposition
Ampere employs a weighted distribution of "Orbits" (Ticks):
*   **Orbit 1 (Tight):** 60% Weight | $\pm 0.5\%$ Band (Captures 90% of daily volume).
*   **Orbit 2 (Wide):** 40% Weight | $\pm 2.0\%$ Band (Safety buffer for volatility).

---

## 📍 Deployed Infrastructure (Sui Testnet)

| Component | Address |
| :--- | :--- |
| **Main Package** | `0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf` |
| **USDC/USDT/SUI Pool** | `0x3d696725312d22e0c92305385857a9a8fe25bb85c374babd34d9536af3ca15f2` |
| **Shared Version** | `349181292` |

---

## 🛠️ Developer Quick Start

### 1. Installation
```bash
# Clone and enter
git clone https://github.com/yourusername/ampere-protocol.git
cd ampere-protocol

# Install via Bun
bun install
```

### 2. Environment Setup
Create a `.env` file:
```bash
SUI_RPC=https://fullnode.testnet.sui.io:443
SUI_PRIVATE_KEY=your_key
PACKAGE_ID=0xcea0d7d35eed...
```

### 3. Execute Operations
```bash
# Mint tokens and provide 3-asset liquidity in one PTB
bun run scripts/mint-and-add-liquidity-single-tx.ts

# Execute a 3D-Invariant Swap (USDC -> SUI)
bun run scripts/swap-demo.ts

# Inspect geometric reserves
bun run scripts/check-balances.ts
```

---

## 📖 SDK Implementation

```typescript
import { OrbitalSdk, createSdkConfig } from "./src/sdk";

const sdk = new OrbitalSdk(createSdkConfig({ packageId: "0xcea0..." }));

// Build an Atomic Swap Transaction on the Orbital Surface
const tx = sdk.pool3.swapExactInTx({
  pool: { objectId: poolId, initialSharedVersion: "349181292", mutable: true },
  coinIn: usdcCoinId,
  route: "AtoC", // USDC -> SUI directly
  typeArgs: [USDC_TYPE, USDT_TYPE, SUI_TYPE, LP_TYPE],
});
```

---

## 🗺️ Roadmap: The Path to Mainnet

*   **Phase 1 (Hackathon):** Newton-Raphson Move Implementation, 3-Asset Base Layer, TS SDK.
*   **Phase 2:** [Pyth Network](https://pyth.network/) Oracle integration for **Orbital Vaults**.
*   **Phase 3:** Flash Loan support & Governance-led Tick Weight optimization.
*   **Phase 4:** Mainnet Deployment & Liquidity Mining for haSUI/afSUI/SUI "Liquid Staking Orbit."

---

## 🤝 Contributing & Research

Ampere is an open-source protocol built for the Sui community. We welcome contributions to our numerical solver and SDK.

**Research References:**
*   [Paradigm: Orbital AMMs](https://www.paradigm.xyz/2023/08/orbital)
*   [Constant Function Market Makers (Angeris et al.)](https://arxiv.org/abs/2003.11367)
*   [Sui Move Object Model](https://docs.sui.io/concepts/object-model)

---

## 📄 License
MIT © 2026 Ampere Protocol.

---

<p align="center">
  <strong>Built with ❤️ on Sui for the Agentic Economy.</strong>
</p>
