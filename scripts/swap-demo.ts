/**
 * Mint a coin and swap it for another token
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair, getSdk, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();
const address = keypair.getPublicKey().toSuiAddress();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const usdcTreasury = requireEnv("USDC_TREASURY");
const typeArgs = getTypeArgsPool3();

console.log("💱 Swapping USDC for SUI");
console.log("═".repeat(60));
console.log("📍 Address:", address);
console.log("🏊 Pool:", poolId);
console.log("");

// Create transaction
const tx = new Transaction();

// Mint 0.5 USDC to swap
console.log("Minting 0.5 USDC...");
const [usdcCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[0]],
  arguments: [tx.object(usdcTreasury), tx.pure.u64(500_000)], // 0.5 USDC
});

// Swap USDC for SUI (route AtoC)
console.log("Swapping USDC → SUI...");
const swapResult = sdk.pool3.addSwapExactInToTx(tx, {
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  coinIn: usdcCoin,
  route: "AtoC",
  typeArgs,
});

// Transfer the received USDT to sender
tx.transferObjects([swapResult], address);

console.log("Executing transaction...");
const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("");
console.log("✅ Swap completed!");
console.log("━".repeat(60));
console.log("Status:", result.effects?.status?.status);
console.log("Digest:", result.digest);

if (result.effects?.status?.status === "failure") {
  console.log("Error:", result.effects?.status?.error);
  process.exit(1);
}

console.log("");
console.log("💰 Output coins:");
const outputCoins = result.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("Coin")
);
outputCoins?.forEach((coin) => {
  console.log(`  - ${coin.objectType?.split("::").pop()}: ${coin.objectId}`);
});

console.log("");
console.log("🎉 Swap successful!");
