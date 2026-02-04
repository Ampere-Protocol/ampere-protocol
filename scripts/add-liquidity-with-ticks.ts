/**
 * Add liquidity with custom tick configuration
 * Shows current pool ticks and adds liquidity distributed across them
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair, getSdk, getTypeArgsPool3, requireEnv, getTicks } from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();
const address = keypair.getPublicKey().toSuiAddress();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const usdcTreasury = requireEnv("USDC_TREASURY");
const usdtTreasury = requireEnv("USDT_TREASURY");
const typeArgs = getTypeArgsPool3();

console.log("🎯 Adding liquidity across pool ticks");
console.log("═".repeat(60));
console.log("📍 Address:", address);
console.log("🏊 Pool:", poolId);
console.log("");

// Show current tick configuration
const ticks = getTicks();
console.log("📊 Pool Tick Configuration:");
ticks.forEach((tick, i) => {
  console.log(`  Tick ${i + 1}:`);
  console.log(`    Band: ${tick.bandBps / 100}% (${tick.bandBps} bps)`);
  console.log(`    Weight: ${tick.weightBps / 100}% (${tick.weightBps} bps)`);
});
console.log("");
console.log("ℹ️  Liquidity is distributed across ticks according to their weights");
console.log("");

// Create transaction to mint and add liquidity
const tx = new Transaction();

// Mint tokens with larger amounts for better distribution
console.log("Minting tokens...");
const [usdcCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[0]],
  arguments: [tx.object(usdcTreasury), tx.pure.u64(2_000_000)], // 2 USDC
});

const [usdtCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[1]],
  arguments: [tx.object(usdtTreasury), tx.pure.u64(2_000_000)], // 2 USDT
});

const [suiCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(200_000_000)]); // 0.2 SUI

// Add liquidity - it will be distributed across ticks
console.log("Adding liquidity across all ticks...");
const lpCoinResult = sdk.pool3.addAddLiquidityToTx(tx, {
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  coinA: usdcCoin,
  coinB: usdtCoin,
  coinC: suiCoin,
  typeArgs,
});

tx.transferObjects([lpCoinResult], address);

console.log("Executing transaction...");
const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("");
console.log("✅ Liquidity added!");
console.log("━".repeat(60));
console.log("Status:", result.effects?.status?.status);
console.log("Digest:", result.digest);

if (result.effects?.status?.status === "failure") {
  console.log("Error:", result.effects?.status?.error);
  process.exit(1);
}

console.log("");
console.log("💰 LP Tokens received:");
const lpTokens = result.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("::lp::LP")
);
lpTokens?.forEach((token) => {
  console.log("  -", token.objectId);
});

console.log("");
console.log("📝 Notes:");
console.log("  • Liquidity is automatically distributed across ticks by weight");
console.log("  • Tick 1 (50 bps band) receives 60% of liquidity");
console.log("  • Tick 2 (100 bps band) receives 40% of liquidity");
console.log("  • Each tick maintains its own reserves for the price range");
console.log("");
console.log("🎉 Pool liquidity updated!");
