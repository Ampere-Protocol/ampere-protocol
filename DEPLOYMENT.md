# Ampere Protocol Deployment Information

## Network
**Sui Testnet**

## Deployment Transaction
- **Transaction Digest**: `EDUHudPVDUoGUSRTBbqroi4kKtNAGnkymFpb5ybkQ7kX`
- **Timestamp**: February 4, 2026
- **Epoch**: 1000

## Contract Addresses

### Main Package
- **Package ID**: `0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf`
- **Version**: 1
- **Digest**: `9M3gxjviGj958Z2dnpDW5uRMpYKDa3ZAgEsMbWJLMCyK`

### Modules Published
1. `mm_vault` - Market Maker Vault
2. `orbital_pool3` - 3-Asset Orbital AMM Pool
3. `orbital_vault` - DeepBook Market Making Vault with Orbital Orders

### Administrative Objects
- **UpgradeCap ID**: `0x319a7f6156ae0ab386a41bad47c103710f626921d5c68e8ab16c075235cc4e1c`
  - Owner: `0x944a3184437489e4700b007296ac54a6f948bef38e18fabf76c745e8beb09490`
  - Version: 349181288

## Dependencies

### On-chain Dependencies
- MoveStdlib: `0x0000000000000000000000000000000000000000000000000000000000000001`
- Sui Framework: `0x0000000000000000000000000000000000000000000000000000000000000002`
- Pyth Oracle: `0xabf837e98c26087cba0883c0a7a28326b1fa3c5e1e2c5abdb486f9e8f594c837`
- Wormhole: `0xf47329f4344f3bf0f8e436e2f7b485466cff300f12a166563995d3888c296a94`
- DeepBook: `0x984757fc7c0e6dd5f15c2c66e881dd6e5aca98b725f3dbd83c445e057ebb790a`
- Token: `0x36dbef866a1d62bf7328989a10fb2f07d769f4ee587c0de4a0a256e57e0a58a8`

### Git Dependencies
- **DeepBook**: https://github.com/MystenLabs/deepbookv3.git (deepbook3.1)
- **Pyth**: https://github.com/pyth-network/pyth-crosschain.git (sui-contract-testnet)
- **Wormhole**: https://github.com/wormhole-foundation/wormhole.git (sui/mainnet)

## Gas Costs
- **Storage Cost**: 210.26 MIST
- **Computation Cost**: 3.86 MIST
- **Total Cost**: 213.14 MIST

## SDK Integration

To use this deployment in your application:

```typescript
import { OrbitalSdk, AMPERE_ADDRESSES } from "./src/sdk";

const sdk = new OrbitalSdk({
  packageId: AMPERE_ADDRESSES.PACKAGE_ID,
});
```

Or use the pre-configured default:

```typescript
import { OrbitalSdk, DEFAULT_CONFIG } from "./src/sdk";

const sdk = new OrbitalSdk(DEFAULT_CONFIG);
```

## Explorer Links

- **Package**: https://suiscan.xyz/testnet/object/0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf
- **Transaction**: https://suiscan.xyz/testnet/tx/EDUHudPVDUoGUSRTBbqroi4kKtNAGnkymFpb5ybkQ7kX

## Verification

To verify the package matches the source:

```bash
cd ampere_vault
sui move build
# Compare the package digest with: 9M3gxjviGj958Z2dnpDW5uRMpYKDa3ZAgEsMbWJLMCyK
```
