/**
 * Mint test tokens and add liquidity to the pool - All in one transaction
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
const usdtTreasury = requireEnv("USDT_TREASURY");
const typeArgs = getTypeArgsPool3();

console.log("🪙 Minting tokens and adding liquidity (single transaction)");
console.log("═".repeat(60));
console.log("📍 Address:", address);
console.log("🏊 Pool:", poolId);
console.log("");

// Create one transaction that does everything
const tx = new Transaction();

// Mint USDC
console.log("Building transaction...");
const [usdcCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[0]],
  arguments: [tx.object(usdcTreasury), tx.pure.u64(1_000_000)],
});

// Mint USDT
const [usdtCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[1]],
  arguments: [tx.object(usdtTreasury), tx.pure.u64(1_000_000)],
});

// Split SUI from gas
const [suiCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(1_000_000_000)]);

// Add liquidity using the minted/split coins
const lpCoinResult = sdk.pool3.addAddLiquidityToTx(tx, {
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  coinA: usdcCoin,
  coinB: usdtCoin,
  coinC: suiCoin,
  typeArgs,
});

// Transfer the LP tokens to the sender
tx.transferObjects([lpCoinResult], address);

console.log("Executing transaction...");
const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("");
console.log("✅ Success!");
console.log("━".repeat(60));
console.log("Status:", result.effects?.status?.status);
console.log("Digest:", result.digest);

if (result.effects?.status?.status === "failure") {
  console.log("Error:", result.effects?.status?.error);
  console.log("\nFull effects:", JSON.stringify(result.effects, null, 2));
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
console.log("🎉 Pool now has liquidity and is ready for swaps!");
