import {
  getClient,
  getKeypair,
  getSdk,
  getTypeArgsPool3,
  requireEnv,
} from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const coinA = requireEnv("COIN_A");
const coinB = requireEnv("COIN_B");
const coinC = requireEnv("COIN_C");
const typeArgs = getTypeArgsPool3();

const tx = sdk.pool3.addLiquidityTx({
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  coinA,
  coinB,
  coinC,
  typeArgs,
});

const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log(JSON.stringify(result, null, 2));
