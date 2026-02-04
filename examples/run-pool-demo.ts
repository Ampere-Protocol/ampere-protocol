/**
 * Orbital Pool 3 - Complete Demo
 * Creates a 3-asset pool, adds liquidity, and performs swaps
 */

import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { decodeSuiPrivateKey } from "@mysten/sui.js/cryptography";
import { OrbitalSdk, DEFAULT_CONFIG } from "../src/sdk";

// Deployed addresses
const AMPERE_PACKAGE = "0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf";
const TEST_TOKENS_PACKAGE = "0x29dcaea77cd8bb362a5d57249ed1b967f59215d0f5de809236615668365329c7";

// Treasury caps (from test tokens deployment)
const LP_TREASURY_CAP = "0x66e102ed0de02d1ca7f90540d2554d6bcdfe2b9d56b3760cc1431e4a6a4b848f";
const USDC_TREASURY_CAP = "0xe031699bcf32c5fd6c80f2911fba491c1b90056c73420fe70eed9405b2023097";
const USDT_TREASURY_CAP = "0x2a8d421bb9f8b7e281a2d16322b2e1dfa2d286e975b8e30e2159e2a113c94a5e";

// Type arguments
const TYPE_SUI = "0x2::sui::SUI";
const TYPE_USDC = `${TEST_TOKENS_PACKAGE}::usdc::USDC`;
const TYPE_USDT = `${TEST_TOKENS_PACKAGE}::usdt::USDT`;
const TYPE_LP = `${TEST_TOKENS_PACKAGE}::lp::LP`;

// Initialize
const client = new SuiClient({ url: getFullnodeUrl("testnet") });
const sdk = new OrbitalSdk(DEFAULT_CONFIG);

const PRIVATE_KEY = process.env.SUI_PRIVATE_KEY;

if (!PRIVATE_KEY) {
  console.error("❌ Set SUI_PRIVATE_KEY environment variable");
  console.log("  export SUI_PRIVATE_KEY='suiprivkey1...'");
  process.exit(1);
}

let keypair: Ed25519Keypair;
if (PRIVATE_KEY.startsWith('suiprivkey1')) {
  const decoded = decodeSuiPrivateKey(PRIVATE_KEY);
  keypair = Ed25519Keypair.fromSecretKey(decoded.secretKey);
} else {
  keypair = Ed25519Keypair.fromSecretKey(Buffer.from(PRIVATE_KEY, "hex"));
}

const address = keypair.getPublicKey().toSuiAddress();

console.log("🏊 Orbital Pool 3 Demo");
console.log("═".repeat(60));
console.log("📍 Wallet:", address);
console.log("📦 Package:", AMPERE_PACKAGE);
console.log("");

/**
 * Step 1: Create Orbital Pool with tick configuration
 */
async function createPool() {
  console.log("🏊 Step 1: Creating Orbital Pool...");
  
  const tx = new TransactionBlock();
  
  // Define tick configuration: band_bps (10000 = 100%) and weight_bps (distribution)
  const tickConfigs = [
    { band_bps: 1000, weight_bps: 3333 },   // 10% band, 33.33% weight
    { band_bps: 2000, weight_bps: 3333 },   // 20% band, 33.33% weight
    { band_bps: 5000, weight_bps: 3334 }    // 50% band, 33.34% weight
  ];
  
  console.log("   Tick configuration:");
  tickConfigs.forEach((tick, i) => {
    console.log(`     [${i}] Band: ${tick.band_bps}bps (${tick.band_bps/100}%), Weight: ${tick.weight_bps}bps`);
  });
  
  // Decimals for each asset
  const decimalsSUI = 9;
  const decimalsUSDC = 6;
  const decimalsUSDT = 6;
  
  // Create BCS for OrbitalTickConfig
  const OrbitalTickConfigBCS = bcs.struct('OrbitalTickConfig', {
    band_bps: bcs.u64(),
    weight_bps: bcs.u64()
  });
  
  const ticksVectorBCS = bcs.vector(OrbitalTickConfigBCS);
  const ticksData = ticksVectorBCS.serialize(
    tickConfigs.map(t => ({ 
      band_bps: t.band_bps, 
      weight_bps: t.weight_bps 
    }))
  ).toBytes();
  
  // Call create_pool3
  tx.moveCall({
    target: `${AMPERE_PACKAGE}::orbital_pool3::create_pool3`,
    typeArguments: [TYPE_SUI, TYPE_USDC, TYPE_USDT, TYPE_LP],
    arguments: [
      tx.object(LP_TREASURY_CAP),
      tx.pure(bcs.u8().serialize(decimalsSUI).toBytes()),
      tx.pure(bcs.u8().serialize(decimalsUSDC).toBytes()),
      tx.pure(bcs.u8().serialize(decimalsUSDT).toBytes()),
      tx.pure(ticksData),
    ],
  });
  
  const result = await client.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer: keypair,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  
  // Find the created pool
  const poolObject = result.objectChanges?.find(
    (obj) => obj.type === "created" && obj.objectType?.includes("Pool")
  );
  
  console.log("✅ Pool created!");
  console.log("   Digest:", result.digest);
  console.log("   Pool ID:", poolObject?.objectId);
  console.log("");
  
  return poolObject?.objectId;
}

/**
 * Step 2: Add liquidity to the pool
 */
async function addLiquidity(poolId: string) {
  console.log("💧 Step 2: Adding Liquidity...");
  
  // Get coin objects from wallet
  const coins = await client.getCoins({ owner: address });
  const usdcCoin = coins.data.find((c) => c.coinType === TYPE_USDC);
  const usdtCoin = coins.data.find((c) => c.coinType === TYPE_USDT);
  
  if (!usdcCoin || !usdtCoin) {
    throw new Error("No USDC/USDT found. Run mint-tokens.ts first.");
  }
  
  console.log("   Found coins:");
  console.log("     USDC:", usdcCoin.coinObjectId);
  console.log("     USDT:", usdtCoin.coinObjectId);
  
  const tx = new TransactionBlock();
  
  // Split SUI for liquidity (0.5 SUI for testing)
  const [suiCoin] = tx.splitCoins(tx.gas, [500_000_000]);
  
  // Add liquidity
  const [lpCoin] = tx.moveCall({
    target: `${AMPERE_PACKAGE}::orbital_pool3::add_liquidity`,
    typeArguments: [TYPE_SUI, TYPE_USDC, TYPE_USDT, TYPE_LP],
    arguments: [
      tx.object(poolId),
      suiCoin,
      tx.object(usdcCoin.coinObjectId),
      tx.object(usdtCoin.coinObjectId),
      tx.pure(0, "u64"), // min LP out
    ],
  });
  
  // Transfer LP tokens to sender
  tx.transferObjects([lpCoin], address);
  
  const result = await client.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer: keypair,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  
  console.log("✅ Liquidity added!");
  console.log("   Digest:", result.digest);
  console.log("   SUI: 0.5");
  console.log("   USDC: 1000.0");
  console.log("   USDT: 1000.0");
  console.log("");
  
  return result;
}

/**
 * Step 3: Get pool state (read-only)
 */
async function getPoolState(poolId: string) {
  console.log("📊 Step 3: Reading Pool State...");
  
  const pool = await client.getObject({
    id: poolId,
    options: { showContent: true },
  });
  
  if (pool.data?.content?.dataType === "moveObject") {
    const fields = pool.data.content.fields as any;
    console.log("   Pool state:");
    console.log("     Tick count:", fields.ticks?.length || 0);
    console.log("");
  }
  
  return pool;
}

/**
 * Step 4: Perform swaps
 */
async function performSwap(poolId: string, route: "AtoB" | "BtoC" | "CtoA", amountIn: number) {
  console.log(`🔄 Step 4: Swapping (${route})...`);
  
  const tx = new TransactionBlock();
  
  let coinIn;
  let routeValue: number;
  
  if (route === "AtoB") {
    // SUI -> USDC
    [coinIn] = tx.splitCoins(tx.gas, [amountIn]);
    routeValue = 0;
    console.log(`   Swapping ${amountIn / 1e9} SUI -> USDC`);
  } else if (route === "BtoC") {
    // USDC -> USDT
    const coins = await client.getCoins({ owner: address, coinType: TYPE_USDC });
    if (!coins.data[0]) throw new Error("No USDC");
    coinIn = tx.object(coins.data[0].coinObjectId);
    routeValue = 1;
    console.log(`   Swapping ${amountIn / 1e6} USDC -> USDT`);
  } else {
    // USDT -> SUI
    const coins = await client.getCoins({ owner: address, coinType: TYPE_USDT });
    if (!coins.data[0]) throw new Error("No USDT");
    coinIn = tx.object(coins.data[0].coinObjectId);
    routeValue = 2;
    console.log(`   Swapping ${amountIn / 1e6} USDT -> SUI`);
  }
  
  // Perform swap
  const [coinOut] = tx.moveCall({
    target: `${AMPERE_PACKAGE}::orbital_pool3::swap_exact_in`,
    typeArguments: [TYPE_SUI, TYPE_USDC, TYPE_USDT, TYPE_LP],
    arguments: [
      tx.object(poolId),
      coinIn,
      tx.pure(0, "u64"), // min out
      tx.pure(routeValue, "u8"),
    ],
  });
  
  // Transfer output to sender
  tx.transferObjects([coinOut], address);
  
  const result = await client.signAndExecuteTransactionBlock({
    transactionBlock: tx,
    signer: keypair,
    options: {
      showEffects: true,
      showBalanceChanges: true,
    },
  });
  
  console.log("✅ Swap executed!");
  console.log("   Digest:", result.digest);
  
  if (result.balanceChanges) {
    console.log("   Balance changes:");
    result.balanceChanges.forEach((change: any) => {
      const amount = Number(change.amount) / (change.coinType === TYPE_SUI ? 1e9 : 1e6);
      const symbol = change.coinType.split("::").pop();
      console.log(`     ${symbol}: ${amount > 0 ? '+' : ''}${amount.toFixed(6)}`);
    });
  }
  console.log("");
  
  return result;
}

/**
 * Main execution
 */
async function main() {
  try {
    // Check balance
    const balance = await client.getBalance({ owner: address });
    console.log(`💰 SUI Balance: ${Number(balance.totalBalance) / 1e9} SUI\n`);
    
    if (Number(balance.totalBalance) < 0.6e9) {
      console.log("⚠️  Need at least 0.6 SUI (0.5 for liquidity + 0.1 for gas)");
      return;
    }
    
    // Step 1: Create pool
    const poolId = await createPool();
    
    if (!poolId) {
      console.log("❌ Failed to create pool");
      return;
    }
    
    // Step 2: Add liquidity
    await addLiquidity(poolId);
    
    // Step 3: Get pool state
    await getPoolState(poolId);
    
    // Step 4: Perform swaps
    await performSwap(poolId, "AtoB", 100_000_000); // 0.1 SUI
    await performSwap(poolId, "BtoC", 10_000000);   // 10 USDC
    await performSwap(poolId, "CtoA", 5_000000);    // 5 USDT
    
    console.log("🎉 Pool demo completed successfully!");
    console.log("═".repeat(60));
    console.log(`\n📋 Pool ID: ${poolId}`);
    console.log(`🔗 Explorer: https://suiscan.xyz/testnet/object/${poolId}\n`);
    
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

// Run
main();
