/**
 * Mint test tokens and add liquidity to the pool
 * This is a complete workflow for testing the pool
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

console.log("🪙 Minting test tokens and adding liquidity");
console.log("═".repeat(60));
console.log("📍 Address:", address);
console.log("🏊 Pool:", poolId);
console.log("");

// Step 1: Mint USDC
console.log("1️⃣  Minting USDC...");
const mintUsdcTx = new Transaction();
const [usdcCoin] = mintUsdcTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[0]], // USDC type
  arguments: [
    mintUsdcTx.object(usdcTreasury),
    mintUsdcTx.pure.u64(1_000_000), // 1 USDC (6 decimals)
  ],
});
mintUsdcTx.transferObjects([usdcCoin], address);

const usdcResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: mintUsdcTx,
  options: { showEffects: true, showObjectChanges: true },
});

const usdcCoinId = usdcResult.objectChanges?.find(
  (obj) => obj.type === "created" && obj.objectType?.includes("usdc::USDC")
)?.objectId;

if (!usdcCoinId) {
  throw new Error("Failed to mint USDC");
}
console.log("✅ USDC minted:", usdcCoinId);

// Step 2: Mint USDT
console.log("2️⃣  Minting USDT...");
const mintUsdtTx = new Transaction();
const [usdtCoin] = mintUsdtTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[1]], // USDT type
  arguments: [
    mintUsdtTx.object(usdtTreasury),
    mintUsdtTx.pure.u64(1_000_000), // 1 USDT (6 decimals)
  ],
});
mintUsdtTx.transferObjects([usdtCoin], address);

const usdtResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: mintUsdtTx,
  options: { showEffects: true, showObjectChanges: true },
});

const usdtCoinId = usdtResult.objectChanges?.find(
  (obj) => obj.type === "created" && obj.objectType?.includes("usdt::USDT")
)?.objectId;

if (!usdtCoinId) {
  throw new Error("Failed to mint USDT");
}
console.log("✅ USDT minted:", usdtCoinId);

// Step 3: Split SUI
console.log("3️⃣  Preparing SUI...");
const splitSuiTx = new Transaction();
const [suiCoin] = splitSuiTx.splitCoins(splitSuiTx.gas, [splitSuiTx.pure.u64(1_000_000_000)]); // 1 SUI
splitSuiTx.transferObjects([suiCoin], address);

const suiResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: splitSuiTx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("SUI tx result:", JSON.stringify(suiResult.objectChanges, null, 2));

const suiCoinId = suiResult.objectChanges?.find(
  (obj) => (obj.type === "created" || obj.type === "mutated") && obj.objectType === "0x2::coin::Coin<0x2::sui::SUI>"
)?.objectId;

if (!suiCoinId) {
  throw new Error("Failed to split SUI");
}
console.log("✅ SUI prepared:", suiCoinId);

// Step 4: Add liquidity
console.log("4️⃣  Adding liquidity to pool...");
const addLiquidityTx = sdk.pool3.addLiquidityTx({
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  coinA: usdcCoinId,
  coinB: usdtCoinId,
  coinC: suiCoinId,
  typeArgs,
});

const liquidityResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: addLiquidityTx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("✅ Liquidity added!");
console.log("");
console.log("📊 Transaction Results:");
console.log("━".repeat(60));
console.log("Status:", liquidityResult.effects?.status?.status);
console.log("Digest:", liquidityResult.digest);
console.log("");
console.log("💰 LP Tokens:");
const lpTokens = liquidityResult.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("::lp::LP")
);
lpTokens?.forEach((token) => {
  console.log("  -", token.objectId);
});
console.log("");
console.log("✨ Success! Pool now has liquidity.");
