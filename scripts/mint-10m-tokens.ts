/**
 * Mint 10M of each token (USDC, USDT, USDe) to a specified address
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair } from "./utils";

const client = getClient();
const keypair = getKeypair();

const recipientAddress = "0x18273e6a34af410740f6b38994547642f4a01c35edbd087006e2df3d04603486";

// New package with all tokens
const PACKAGE_ID = "0x23163f1ddc397a0fe40770803292a08b3f7550b68c3c699ac6c0ec1ad0fba804";
const USDC_TYPE = `${PACKAGE_ID}::usdc::USDC`;
const USDT_TYPE = `${PACKAGE_ID}::usdt::USDT`;
const USDE_TYPE = `${PACKAGE_ID}::usde::USDE`;

// Treasury caps
const USDC_TREASURY = "0x63ef50869a1f08bf228a22828733afb79bbfa885e480e0bfe1daa48410d60949";
const USDT_TREASURY = "0xaf8642e2bcd04d95c1d4158990fa1aa0d3ccfe0a57c9d37a2366230d4cf45acb";
const USDE_TREASURY = "0xafddca07f5b526bc291ccf1cf99658c847716c43782e527cf9f2f23c03b35c3a";

console.log("💸 Minting 10M tokens each");
console.log("═".repeat(60));
console.log("📍 Recipient:", recipientAddress);
console.log("📦 Package:", PACKAGE_ID);
console.log("");

// Create transaction
const tx = new Transaction();

// Mint 10,000,000 USDC (10M with 6 decimals)
console.log("Minting 10,000,000 USDC...");
const [usdcCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDC_TYPE],
  arguments: [tx.object(USDC_TREASURY), tx.pure.u64(10_000_000_000_000)],
});

// Mint 10,000,000 USDT (10M with 6 decimals)
console.log("Minting 10,000,000 USDT...");
const [usdtCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDT_TYPE],
  arguments: [tx.object(USDT_TREASURY), tx.pure.u64(10_000_000_000_000)],
});

// Mint 10,000,000 USDe (10M with 6 decimals)
console.log("Minting 10,000,000 USDe...");
const [usdeCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDE_TYPE],
  arguments: [tx.object(USDE_TREASURY), tx.pure.u64(10_000_000_000_000)],
});

// Transfer to recipient
tx.transferObjects([usdcCoin, usdtCoin, usdeCoin], recipientAddress);

console.log("Executing transaction...");
const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log("");
console.log("✅ Tokens sent!");
console.log("━".repeat(60));
console.log("Status:", result.effects?.status?.status);
console.log("Digest:", result.digest);

if (result.effects?.status?.status === "failure") {
  console.log("Error:", result.effects?.status?.error);
  process.exit(1);
}

console.log("");
console.log("💰 Tokens created:");
const createdCoins = result.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("Coin")
);
createdCoins?.forEach((coin) => {
  if (coin.type === "created") {
    const tokenName = coin.objectType?.split("::").pop()?.replace(">", "");
    console.log(`  - ${tokenName}: ${coin.objectId}`);
  }
});

console.log("");
console.log("🎉 Successfully sent 10M USDC, 10M USDT, and 10M USDe!");
