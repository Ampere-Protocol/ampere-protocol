# Ampere Orbital SDK

This SDK provides typed transaction builders for the Move modules in `ampere_vault`. It is designed for app integration on Sui using dependency injection, small composable builders, and explicit shared-object handling.

**Scope**
This SDK targets two modules:
- `orbital_pool3`: a 3-asset Orbital AMM.
- `orbital_vault`: a DeepBook market-making vault that places orbital-style limit orders.

## Integration Pipeline

1. Configure network and package.
Use a stable config that includes the published Move package ID and module names.

2. Resolve shared objects.
Fetch shared refs for:
- Orbital pool or vault objects.
- DeepBook pool object.
- Pyth price info objects.
- Sui clock object `0x6`.

3. Initialize the SDK.
Create the SDK once and reuse it across the app.

4. Build transactions.
Use the SDK methods to build a `Transaction`. Compose multi-step flows in one transaction for atomicity.

5. Preflight.
Use `devInspectTransactionBlock` for read-only quotes or dry runs. Validate slippage, balances, and timestamps.

6. Sign and execute.
Submit with wallet signing or sponsor-based execution depending on your app flow.

## Example Flow: App Startup

1. Load config from environment.
2. Instantiate `SuiClient`.
3. Resolve shared refs.
4. Instantiate `OrbitalSdk`.

## Example Flow: Swap on OrbitalPool3

1. User selects route and amount.
2. Fetch shared pool ref once.
3. Build swap transaction with `swapExactInTx` or `swapExactOutTx`.
4. Sign and execute.

## Example Flow: Place Orbital Orders on DeepBook

1. Ensure the user owns `TradingCap`.
2. Build a combined transaction with `placeOrbitalOrdersWithProofTx`.
3. Provide `expireTimestamp` based on the current clock.
4. Sign and execute.

## SOLID Design Notes

- Single Responsibility: `OrbitalPool3Client` and `OrbitalVaultClient` only build transactions for their module.
- Open/Closed: You can inject a custom `TransactionFactory` for specialized signing flows.
- Liskov Substitution: Both clients use the same `BaseMoveClient` interface and patterns.
- Interface Segregation: Shared-object resolution is separate from transaction building.
- Dependency Inversion: Transaction factories and shared object resolvers are injected.

## Public API Quickstart

```ts
import { OrbitalSdk, createSdkConfig } from "./src/sdk";

const config = createSdkConfig({
  packageId: "0xYOUR_PACKAGE_ID",
});

const sdk = new OrbitalSdk(config);

const tx = sdk.pool3.swapExactInTx({
  pool: { objectId: "0xPOOL", initialSharedVersion: "1", mutable: true },
  coinIn: "0xCOIN",
  route: "AtoB",
  typeArgs: [
    "0x2::sui::SUI",
    "0xYOUR::usdc::USDC",
    "0xYOUR::usdt::USDT",
    "0xYOUR::lp::ORB_LP",
  ],
});
```

## Testing

Run the SDK tests with:

```bash
bun test
```
