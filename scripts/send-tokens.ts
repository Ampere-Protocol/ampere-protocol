/**
 * Mint and send tokens to a specified address
 */

import { Transaction } from "@mysten/sui/transactions";
import { getClient, getKeypair, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const keypair = getKeypair();
const typeArgs = getTypeArgsPool3();

const recipientAddress = "0x18273e6a34af410740f6b38994547642f4a01c35edbd087006e2df3d04603486";
const usdcTreasury = requireEnv("USDC_TREASURY");
const usdtTreasury = requireEnv("USDT_TREASURY");

console.log("💸 Minting and sending tokens");
console.log("═".repeat(60));
console.log("📍 Recipient:", recipientAddress);
console.log("");

// Create transaction
const tx = new Transaction();

// Mint 1,000,000 USDC (1M USDC with 6 decimals)
console.log("Minting 1,000,000 USDC...");
const [usdcCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[0]],
  arguments: [tx.object(usdcTreasury), tx.pure.u64(1_000_000_000_000)], // 1M USDC
});

// Mint 1,000,000 USDT (1M USDT with 6 decimals)
console.log("Minting 1,000,000 USDT...");
const [usdtCoin] = tx.moveCall({
  target: `0x2::coin::mint`,
  typeArguments: [typeArgs[1]],
  arguments: [tx.object(usdtTreasury), tx.pure.u64(1_000_000_000_000)], // 1M USDT
});

// Transfer to recipient
tx.transferObjects([usdcCoin, usdtCoin], recipientAddress);

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
  const tokenName = coin.objectType?.split("::").pop()?.replace(">", "");
  console.log(`  - ${tokenName}: ${coin.objectId}`);
});

console.log("");
console.log("🎉 Successfully sent 1,000,000 USDC and 1,000,000 USDT!");
