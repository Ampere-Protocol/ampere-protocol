/**
 * Mint tokens to our address and test swap in stablecoin pool
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair } from "./utils";
import { OrbitalPool3Client } from "../src/sdk";

const client = getClient();
const keypair = getKeypair();
const senderAddress = keypair.toSuiAddress();

// New package with USDe
const PACKAGE_ID = "0x23163f1ddc397a0fe40770803292a08b3f7550b68c3c699ac6c0ec1ad0fba804";
const USDC_TYPE = `${PACKAGE_ID}::usdc::USDC`;
const USDT_TYPE = `${PACKAGE_ID}::usdt::USDT`;
const USDE_TYPE = `${PACKAGE_ID}::usde::USDE`;
const LP_TYPE = `${PACKAGE_ID}::lp::LP`;

// Treasury caps
const USDC_TREASURY = "0x63ef50869a1f08bf228a22828733afb79bbfa885e480e0bfe1daa48410d60949";
const USDT_TREASURY = "0xaf8642e2bcd04d95c1d4158990fa1aa0d3ccfe0a57c9d37a2366230d4cf45acb";
const USDE_TREASURY = "0xafddca07f5b526bc291ccf1cf99658c847716c43782e527cf9f2f23c03b35c3a";

// Pool ID
const POOL_ID = "0x3eed9e889440ea868516b05cf5d773627f87167720a9136e26ec6244f2ab9e0b";
const POOL_VERSION = 349181315;

// Ampere package
const AMPERE_PACKAGE = "0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf";

console.log("🏊 Testing Stablecoin Pool Swap");
console.log("═".repeat(60));
console.log("📍 Address:", senderAddress);
console.log("🏊 Pool:", POOL_ID);
console.log("");

// Step 1: Mint tokens to our address
console.log("Step 1: Minting tokens to our address...");
const mintTx = new Transaction();

// Mint 1000 USDC
const [usdcCoin] = mintTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDC_TYPE],
  arguments: [mintTx.object(USDC_TREASURY), mintTx.pure.u64(1000_000_000)], // 1000 USDC
});

// Mint 500 USDT
const [usdtCoin] = mintTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDT_TYPE],
  arguments: [mintTx.object(USDT_TREASURY), mintTx.pure.u64(500_000_000)], // 500 USDT
});

// Mint 500 USDe
const [usdeCoin] = mintTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDE_TYPE],
  arguments: [mintTx.object(USDE_TREASURY), mintTx.pure.u64(500_000_000)], // 500 USDe
});

mintTx.transferObjects([usdcCoin, usdtCoin, usdeCoin], senderAddress);

console.log("Minting 1000 USDC, 500 USDT, 500 USDe...");
const mintResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: mintTx,
  options: { showEffects: true, showObjectChanges: true },
});

if (mintResult.effects?.status?.status === "failure") {
  console.log("❌ Minting failed:", mintResult.effects?.status?.error);
  process.exit(1);
}

console.log("✅ Tokens minted!");
console.log("Digest:", mintResult.digest);

// Wait for transaction to finalize
console.log("Waiting for transaction to finalize...");
await new Promise(resolve => setTimeout(resolve, 2000));

// Get minted coin IDs
const mintedCoins = mintResult.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("Coin")
);

const usdcCoinId = mintedCoins?.find((c) => c.type === "created" && c.objectType?.includes("usdc"))?.objectId;
const usdtCoinId = mintedCoins?.find((c) => c.type === "created" && c.objectType?.includes("usdt"))?.objectId;
const usdeCoinId = mintedCoins?.find((c) => c.type === "created" && c.objectType?.includes("usde"))?.objectId;

console.log("");
console.log("💰 Minted Coins:");
console.log("  USDC:", usdcCoinId);
console.log("  USDT:", usdtCoinId);
console.log("  USDe:", usdeCoinId);
console.log("");

// Step 2: Add liquidity to activate the pool
console.log("Step 2: Adding liquidity to pool...");
const sdk = new OrbitalPool3Client({ packageId: AMPERE_PACKAGE });

const addLiqTx = new Transaction();

// Mint more tokens for liquidity
const [liqUSDC] = addLiqTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDC_TYPE],
  arguments: [addLiqTx.object(USDC_TREASURY), addLiqTx.pure.u64(5000_000_000)], // 5000 USDC
});

const [liqUSDT] = addLiqTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDT_TYPE],
  arguments: [addLiqTx.object(USDT_TREASURY), addLiqTx.pure.u64(5000_000_000)], // 5000 USDT
});

const [liqUSDe] = addLiqTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDE_TYPE],
  arguments: [addLiqTx.object(USDE_TREASURY), addLiqTx.pure.u64(5000_000_000)], // 5000 USDe
});

const lpTokens = sdk.addAddLiquidityToTx(addLiqTx, {
  pool: { objectId: POOL_ID, initialSharedVersion: POOL_VERSION },
  coinA: liqUSDC,
  coinB: liqUSDT,
  coinC: liqUSDe,
  typeArgs: [USDC_TYPE, USDT_TYPE, USDE_TYPE, LP_TYPE],
});

addLiqTx.transferObjects([lpTokens], senderAddress);

console.log("Adding 5000 of each token...");
const liqResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: addLiqTx,
  options: { showEffects: true, showObjectChanges: true },
});

if (liqResult.effects?.status?.status === "failure") {
  console.log("❌ Add liquidity failed:", liqResult.effects?.status?.error);
  process.exit(1);
}

console.log("✅ Liquidity added!");
console.log("Digest:", liqResult.digest);
console.log("");

// Step 3: Perform swap (USDC -> USDT)
console.log("Step 3: Testing swap (100 USDC → USDT)...");

if (!usdcCoinId) {
  console.log("❌ USDC coin ID not found");
  process.exit(1);
}

// Create a new transaction for the swap
const swapTx = new Transaction();

// Perform the swap
const usdtOut = sdk.addSwapExactInToTx(swapTx, {
  pool: { objectId: POOL_ID, initialSharedVersion: POOL_VERSION },
  coinIn: usdcCoinId,
  route: "AtoB", // USDC to USDT
  typeArgs: [USDC_TYPE, USDT_TYPE, USDE_TYPE, LP_TYPE],
});

// Transfer the output USDT back to sender
swapTx.transferObjects([usdtOut], senderAddress);

const swapResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: swapTx,
  options: { showEffects: true, showObjectChanges: true, showBalanceChanges: true },
});

console.log("");
console.log("✅ Swap Complete!");
console.log("━".repeat(60));
console.log("Status:", swapResult.effects?.status?.status);
console.log("Digest:", swapResult.digest);

if (swapResult.effects?.status?.status === "failure") {
  console.log("❌ Error:", swapResult.effects?.status?.error);
  process.exit(1);
}

console.log("");
console.log("💱 Balance Changes:");
swapResult.balanceChanges?.forEach((change) => {
  const tokenName = change.coinType.split("::").pop();
  const amount = Number(change.amount) / 1_000_000;
  console.log(`  ${tokenName}: ${amount > 0 ? '+' : ''}${amount.toFixed(2)}`);
});

console.log("");
console.log("🎉 Swap test successful!");
