/**
 * Remove liquidity from the pool
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair, getSdk, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();
const address = keypair.getPublicKey().toSuiAddress();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const lpCoin = requireEnv("LP_COIN");
const typeArgs = getTypeArgsPool3();

console.log("💧 Removing liquidity from pool");
console.log("═".repeat(60));
console.log("📍 Address:", address);
console.log("🏊 Pool:", poolId);
console.log("🪙 LP Token:", lpCoin);
console.log("");

// Create transaction
const tx = new Transaction();

// Remove liquidity - this returns [coinA, coinB, coinC]
console.log("Removing liquidity...");
const [coinA, coinB, coinC] = sdk.pool3.addRemoveLiquidityToTx(tx, {
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  lpCoin,
  typeArgs,
});

// Transfer all received coins back to sender
tx.transferObjects([coinA, coinB, coinC], address);

console.log("Executing transaction...");
const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("");
console.log("✅ Liquidity removed!");
console.log("━".repeat(60));
console.log("Status:", result.effects?.status?.status);
console.log("Digest:", result.digest);

if (result.effects?.status?.status === "failure") {
  console.log("Error:", result.effects?.status?.error);
  process.exit(1);
}

console.log("");
console.log("💰 Received back:");
const receivedCoins = result.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("Coin")
);
receivedCoins?.forEach((coin) => {
  const tokenName = coin.objectType?.split("::").pop()?.replace(">", "");
  console.log(`  - ${tokenName}: ${coin.objectId}`);
});

console.log("");
console.log("🎉 Successfully withdrew liquidity!");
