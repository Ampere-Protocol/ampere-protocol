import { getClient, getKeypair, getSdk, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const lpCoin = requireEnv("LP_COIN");
const typeArgs = getTypeArgsPool3();

const tx = sdk.pool3.removeLiquidityTx({
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  lpCoin,
  typeArgs,
});

const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log(JSON.stringify(result, null, 2));
