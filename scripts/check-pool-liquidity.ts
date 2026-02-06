/**
 * Check liquidity in the stablecoin pool
 */

import { getClient } from "./utils";

const client = getClient();

// Stablecoin pool
const POOL_ID = "0x3eed9e889440ea868516b05cf5d773627f87167720a9136e26ec6244f2ab9e0b";

console.log("🔍 Checking Pool Liquidity");
console.log("═".repeat(60));
console.log("Pool ID:", POOL_ID);
console.log("");

// Fetch pool object
const poolObject = await client.getObject({
  id: POOL_ID,
  options: {
    showContent: true,
    showType: true,
  },
});

if (poolObject.data?.content?.dataType !== "moveObject") {
  console.log("❌ Pool object not found or invalid");
  process.exit(1);
}

const fields = poolObject.data.content.fields as any;

console.log("💰 Pool Reserves:");
console.log("");

// Parse tick data
if (fields.ticks && Array.isArray(fields.ticks)) {
  let totalUSDC = 0n;
  let totalUSDT = 0n;
  let totalUSDe = 0n;

  fields.ticks.forEach((tick: any, index: number) => {
    const reserveA = BigInt(tick.fields.reserve_a || 0);
    const reserveB = BigInt(tick.fields.reserve_b || 0);
    const reserveC = BigInt(tick.fields.reserve_c || 0);

    totalUSDC += reserveA;
    totalUSDT += reserveB;
    totalUSDe += reserveC;

    console.log(`Tick ${index + 1}:`);
    console.log(`  USDC: ${(Number(reserveA) / 1_000_000).toFixed(2)}`);
    console.log(`  USDT: ${(Number(reserveB) / 1_000_000).toFixed(2)}`);
    console.log(`  USDe: ${(Number(reserveC) / 1_000_000).toFixed(2)}`);
    console.log("");
  });

  console.log("━".repeat(60));
  console.log("📊 Total Liquidity:");
  console.log(`  USDC: ${(Number(totalUSDC) / 1_000_000).toFixed(2)}`);
  console.log(`  USDT: ${(Number(totalUSDT) / 1_000_000).toFixed(2)}`);
  console.log(`  USDe: ${(Number(totalUSDe) / 1_000_000).toFixed(2)} ← Token C`);
  console.log("");
  console.log(`💎 USDe (Token C) Liquidity: ${(Number(totalUSDe) / 1_000_000).toFixed(2)} USDe`);
} else {
  console.log("❌ Could not parse tick data");
}
