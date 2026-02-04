/**
 * Check user token balances and pool reserves
 */

import { getClient, getKeypair, requireEnv, getTypeArgsPool3 } from "./utils";

const client = getClient();
const keypair = getKeypair();
const address = keypair.getPublicKey().toSuiAddress();

const poolId = requireEnv("POOL_ID");
const typeArgs = getTypeArgsPool3();

console.log("💼 Checking Balances");
console.log("═".repeat(60));
console.log("📍 Address:", address);
console.log("");

// Get all coins owned by the user
console.log("👤 Your Token Balances:");
console.log("─".repeat(60));

// Get USDC balance
const usdcCoins = await client.getCoins({
  owner: address,
  coinType: typeArgs[0],
});
const usdcTotal = usdcCoins.data.reduce((sum, coin) => sum + BigInt(coin.balance), 0n);
console.log(`💵 USDC: ${Number(usdcTotal) / 1_000_000} USDC (${usdcCoins.data.length} coins)`);

// Get USDT balance
const usdtCoins = await client.getCoins({
  owner: address,
  coinType: typeArgs[1],
});
const usdtTotal = usdtCoins.data.reduce((sum, coin) => sum + BigInt(coin.balance), 0n);
console.log(`💵 USDT: ${Number(usdtTotal) / 1_000_000} USDT (${usdtCoins.data.length} coins)`);

// Get SUI balance
const suiCoins = await client.getCoins({
  owner: address,
  coinType: typeArgs[2],
});
const suiTotal = suiCoins.data.reduce((sum, coin) => sum + BigInt(coin.balance), 0n);
console.log(`💰 SUI:  ${Number(suiTotal) / 1_000_000_000} SUI (${suiCoins.data.length} coins)`);

// Get LP token balance
const lpCoins = await client.getCoins({
  owner: address,
  coinType: typeArgs[3],
});
const lpTotal = lpCoins.data.reduce((sum, coin) => sum + BigInt(coin.balance), 0n);
console.log(`🪙 LP:   ${Number(lpTotal)} LP tokens (${lpCoins.data.length} coins)`);

console.log("");
console.log("🏊 Pool Reserves:");
console.log("─".repeat(60));

// Get pool object
const poolObject = await client.getObject({
  id: poolId,
  options: { showContent: true },
});

console.log("Raw pool data:", JSON.stringify(poolObject.data?.content, null, 2));

if (poolObject.data?.content?.dataType === "moveObject") {
  const fields = poolObject.data.content.fields as any;
  
  console.log(`Pool ID: ${poolId}`);
  console.log(`Pool Type: OrbitalPool3`);
  console.log("");
  
  // Show tick information
  if (fields.ticks && Array.isArray(fields.ticks)) {
    console.log("📊 Tick Reserves:");
    fields.ticks.forEach((tick: any, index: number) => {
      console.log(`  Tick ${index + 1}:`);
      console.log(`    Band: ${tick.band_bps || tick.fields?.band_bps}bps`);
      console.log(`    Weight: ${tick.weight_bps || tick.fields?.weight_bps}bps`);
      
      const tickFields = tick.fields || tick;
      const balanceA = BigInt(tickFields.balance_a || 0);
      const balanceB = BigInt(tickFields.balance_b || 0);
      const balanceC = BigInt(tickFields.balance_c || 0);
      
      console.log(`    USDC: ${Number(balanceA) / 1_000_000} USDC`);
      console.log(`    USDT: ${Number(balanceB) / 1_000_000} USDT`);
      console.log(`    SUI:  ${Number(balanceC) / 1_000_000_000} SUI`);
      console.log(`    L²:   ${tickFields.l_squared}`);
    });
    
    // Calculate totals
    const totalA = fields.ticks.reduce((sum: bigint, t: any) => {
      const tf = t.fields || t;
      return sum + BigInt(tf.balance_a || 0);
    }, 0n);
    const totalB = fields.ticks.reduce((sum: bigint, t: any) => {
      const tf = t.fields || t;
      return sum + BigInt(tf.balance_b || 0);
    }, 0n);
    const totalC = fields.ticks.reduce((sum: bigint, t: any) => {
      const tf = t.fields || t;
      return sum + BigInt(tf.balance_c || 0);
    }, 0n);
    
    console.log("");
    console.log("📈 Total Pool Reserves:");
    console.log(`    USDC: ${Number(totalA) / 1_000_000} USDC`);
    console.log(`    USDT: ${Number(totalB) / 1_000_000} USDT`);
    console.log(`    SUI:  ${Number(totalC) / 1_000_000_000} SUI`);
  }
  
  console.log("");
  console.log("🔒 Locked LP Balance:", fields.locked_lp_balance || "0");
}

console.log("");
console.log("✅ Balance check complete!");
