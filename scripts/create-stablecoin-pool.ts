/**
 * Create an OrbitalPool3 with USDC, USDT, and USDe (all stablecoins)
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair } from "./utils";
import { OrbitalPool3Client } from "../src/sdk";

const client = getClient();
const keypair = getKeypair();
const senderAddress = keypair.toSuiAddress();

// New package ID with USDe
const PACKAGE_ID = "0x23163f1ddc397a0fe40770803292a08b3f7550b68c3c699ac6c0ec1ad0fba804";

// Type arguments
const USDC_TYPE = `${PACKAGE_ID}::usdc::USDC`;
const USDT_TYPE = `${PACKAGE_ID}::usdt::USDT`;
const USDE_TYPE = `${PACKAGE_ID}::usde::USDE`;
const LP_TYPE = `${PACKAGE_ID}::lp::LP`;

// Treasury caps (from the publish transaction)
const USDC_TREASURY = "0x63ef50869a1f08bf228a22828733afb79bbfa885e480e0bfe1daa48410d60949";
const USDT_TREASURY = "0xaf8642e2bcd04d95c1d4158990fa1aa0d3ccfe0a57c9d37a2366230d4cf45acb";
const USDE_TREASURY = "0xafddca07f5b526bc291ccf1cf99658c847716c43782e527cf9f2f23c03b35c3a";
const LP_TREASURY_CAP = "0x5791e9693952bb9628faffda2b9e4cf32771afb6494298266e3d378183efcad4";

// Ampere vault package
const AMPERE_VAULT_PACKAGE = "0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf";

console.log("🏊 Creating Stablecoin Pool (USDC-USDT-USDe)");
console.log("═".repeat(60));
console.log("");

// Initialize SDK
const sdk = new OrbitalPool3Client({
  packageId: AMPERE_VAULT_PACKAGE,
});

// Pool configuration - tight spreads for stablecoins
const ticks = [
  { bandBps: 10, weightBps: 5000 },  // 0.1% band, 50% weight
  { bandBps: 25, weightBps: 5000 },  // 0.25% band, 50% weight
];

console.log("Pool Configuration:");
console.log("  Tokens: USDC, USDT, USDe");
console.log("  Decimals: 6, 6, 6");
console.log("");
console.log("Tick Configuration:");
ticks.forEach((tick, i) => {
  console.log(`  Tick ${i + 1}: ${tick.bandBps / 100}% band, ${tick.weightBps / 100}% weight`);
});
console.log("");

// Step 1: Create the pool
const createPoolTx = sdk.createPool3Tx({
  lpTreasuryCap: LP_TREASURY_CAP,
  decimalsA: 6,
  decimalsB: 6,
  decimalsC: 6,
  ticks,
  typeArgs: [USDC_TYPE, USDT_TYPE, USDE_TYPE, LP_TYPE],
});

console.log("Creating pool...");
const poolResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: createPoolTx,
  options: { showEffects: true, showObjectChanges: true },
});

if (poolResult.effects?.status?.status === "failure") {
  console.log("❌ Pool creation failed:", poolResult.effects?.status?.error);
  process.exit(1);
}

// Find the pool object
const poolObject = poolResult.objectChanges?.find(
  (obj) =>
    obj.type === "created" &&
    obj.objectType?.includes("OrbitalPool3") &&
    !obj.objectType?.includes("AdminCap")
);

if (!poolObject || poolObject.type !== "created") {
  console.log("❌ Pool object not found");
  process.exit(1);
}

const poolId = poolObject.objectId;
console.log("✅ Pool created:", poolId);
console.log("");

// Step 2: Add initial liquidity
console.log("Adding initial liquidity...");
const initialAmount = 10_000_000_000; // 10,000 tokens with 6 decimals

const addLiquidityTx = new Transaction();

// Mint tokens
const [usdcCoin] = addLiquidityTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDC_TYPE],
  arguments: [addLiquidityTx.object(USDC_TREASURY), addLiquidityTx.pure.u64(initialAmount)],
});

const [usdtCoin] = addLiquidityTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDT_TYPE],
  arguments: [addLiquidityTx.object(USDT_TREASURY), addLiquidityTx.pure.u64(initialAmount)],
});

const [usdeCoin] = addLiquidityTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDE_TYPE],
  arguments: [addLiquidityTx.object(USDE_TREASURY), addLiquidityTx.pure.u64(initialAmount)],
});

// Add liquidity
const lpTokens = sdk.addAddLiquidityToTx(addLiquidityTx, {
  pool: { objectId: poolId, initialSharedVersion: poolObject.version },
  coinA: usdcCoin,
  coinB: usdtCoin,
  coinC: usdeCoin,
  typeArgs: [USDC_TYPE, USDT_TYPE, USDE_TYPE, LP_TYPE],
});

// Transfer LP tokens
addLiquidityTx.transferObjects([lpTokens], senderAddress);

const liquidityResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: addLiquidityTx,
  options: { showEffects: true, showObjectChanges: true },
});

if (liquidityResult.effects?.status?.status === "failure") {
  console.log("❌ Liquidity addition failed:", liquidityResult.effects?.status?.error);
  process.exit(1);
}

console.log("✅ Liquidity added!");
console.log("");
console.log("━".repeat(60));
console.log("Pool Digest:", poolResult.digest);
console.log("Liquidity Digest:", liquidityResult.digest);
console.log("");

// Find admin cap
const adminCap = poolResult.objectChanges?.find(
  (obj) =>
    obj.type === "created" && obj.objectType?.includes("AdminCap")
);

if (adminCap && adminCap.type === "created") {
  console.log("🔑 Admin Cap:", adminCap.objectId);
}

// Find LP tokens
const lpCoins = liquidityResult.objectChanges?.filter(
  (obj) =>
    obj.type === "created" &&
    obj.objectType?.includes("Coin") &&
    obj.objectType?.includes("LP")
);

console.log("💰 LP Tokens Created:");
lpCoins?.forEach((coin) => {
  if (coin.type === "created") {
    console.log(`  ${coin.objectId}`);
  }
});

console.log("");
console.log("🎉 Stablecoin pool is ready!");
console.log("");
console.log("💡 Pool Details:");
console.log(`  Pool ID: ${poolId}`);
console.log(`  USDC Treasury: ${USDC_TREASURY}`);
console.log(`  USDT Treasury: ${USDT_TREASURY}`);
console.log(`  USDe Treasury: ${USDE_TREASURY}`);
console.log(`  Package ID: ${PACKAGE_ID}`);
