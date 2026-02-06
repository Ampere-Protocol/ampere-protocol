/**
 * Mint and send USDe tokens to a specified address
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair } from "./utils";

const client = getClient();
const keypair = getKeypair();

const recipientAddress = "0x18273e6a34af410740f6b38994547642f4a01c35edbd087006e2df3d04603486";
const PACKAGE_ID = "0x23163f1ddc397a0fe40770803292a08b3f7550b68c3c699ac6c0ec1ad0fba804";
const USDE_TYPE = `${PACKAGE_ID}::usde::USDE`;
const usdeTreasury = "0xafddca07f5b526bc291ccf1cf99658c847716c43782e527cf9f2f23c03b35c3a";

console.log("💸 Minting and sending USDe tokens");
console.log("═".repeat(60));
console.log("📍 Recipient:", recipientAddress);
console.log("");

// Create transaction
const tx = new Transaction();

// Mint 1,000,000 USDe (1M USDe with 6 decimals)
console.log("Minting 1,000,000 USDe...");
const [usdeCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [USDE_TYPE],
  arguments: [tx.object(usdeTreasury), tx.pure.u64(1_000_000_000_000)], // 1M USDe
});

// Transfer to recipient
tx.transferObjects([usdeCoin], recipientAddress);

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
console.log("💰 USDe created:");
const createdCoins = result.objectChanges?.filter(
  (obj) => obj.type === "created" && obj.objectType?.includes("Coin")
);
createdCoins?.forEach((coin) => {
  if (coin.type === "created") {
    console.log(`  ${coin.objectId}`);
  }
});

console.log("");
console.log("🎉 Successfully sent 1,000,000 USDe!");
