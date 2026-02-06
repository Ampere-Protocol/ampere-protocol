/**
 * Swap USDe for USDT in the stablecoin pool
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair } from "./utils";
import { OrbitalPool3Client } from "../src/sdk";

const client = getClient();
const keypair = getKeypair();
const senderAddress = keypair.toSuiAddress();

// Token package
const PACKAGE_ID = "0x23163f1ddc397a0fe40770803292a08b3f7550b68c3c699ac6c0ec1ad0fba804";
const USDC_TYPE = `${PACKAGE_ID}::usdc::USDC`;
const USDT_TYPE = `${PACKAGE_ID}::usdt::USDT`;
const USDE_TYPE = `${PACKAGE_ID}::usde::USDE`;
const LP_TYPE = `${PACKAGE_ID}::lp::LP`;

// Treasury cap
const USDE_TREASURY = "0xafddca07f5b526bc291ccf1cf99658c847716c43782e527cf9f2f23c03b35c3a";

// Pool
const POOL_ID = "0x3eed9e889440ea868516b05cf5d773627f87167720a9136e26ec6244f2ab9e0b";
const POOL_VERSION = 349181315;

// Ampere package
const AMPERE_PACKAGE = "0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf";

console.log("💱 Swapping USDe → USDT");
console.log("═".repeat(60));
console.log("📍 Address:", senderAddress);
console.log("🏊 Pool:", POOL_ID);
console.log("");

// Step 1: Mint USDe tokens
console.log("Step 1: Minting 500 USDe...");
const mintTx = new Transaction();

const [usdeCoin] = mintTx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDE_TYPE],
  arguments: [mintTx.object(USDE_TREASURY), mintTx.pure.u64(500_000_000)], // 500 USDe
});

mintTx.transferObjects([usdeCoin], senderAddress);

const mintResult = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: mintTx,
  options: { showEffects: true, showObjectChanges: true },
});

if (mintResult.effects?.status?.status === "failure") {
  console.log("❌ Minting failed:", mintResult.effects?.status?.error);
  process.exit(1);
}

console.log("✅ Minted 500 USDe");
console.log("Digest:", mintResult.digest);

// Get minted coin ID
const usdeCoinId = mintResult.objectChanges?.find(
  (obj) => obj.type === "created" && obj.objectType?.includes("usde")
)?.objectId;

console.log("USDe Coin:", usdeCoinId);
console.log("");

if (!usdeCoinId) {
  console.log("❌ USDe coin ID not found");
  process.exit(1);
}

// Wait for transaction to finalize
await new Promise(resolve => setTimeout(resolve, 2000));

// Step 2: Perform swap (USDe -> USDT)
console.log("Step 2: Swapping 500 USDe → USDT...");

const sdk = new OrbitalPool3Client({ packageId: AMPERE_PACKAGE });
const swapTx = new Transaction();

// Perform the swap (Token C to Token B)
const usdtOut = sdk.addSwapExactInToTx(swapTx, {
  pool: { objectId: POOL_ID, initialSharedVersion: POOL_VERSION },
  coinIn: usdeCoinId,
  route: "CtoB", // USDe (Token C) to USDT (Token B)
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
console.log("🎉 Successfully swapped USDe for USDT!");
