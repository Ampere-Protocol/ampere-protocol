import { getClient, getKeypair, getSdk, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const coinIn = requireEnv("COIN_IN");
const route = requireEnv("ROUTE") as "AtoB" | "BtoA" | "AtoC" | "CtoA" | "BtoC" | "CtoB";
const typeArgs = getTypeArgsPool3();

const tx = sdk.pool3.swapExactInTx({
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: true },
  coinIn,
  route,
  typeArgs,
});

const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log(JSON.stringify(result, null, 2));
