import { getClient, getSdk, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const sdk = getSdk();

const poolId = requireEnv("POOL_ID");
const poolSharedVersion = requireEnv("POOL_SHARED_VERSION");
const amountIn = requireEnv("AMOUNT_IN");
const typeArgs = getTypeArgsPool3();

const tx = sdk.pool3.buildQuoteExactInTx({
  pool: { objectId: poolId, initialSharedVersion: poolSharedVersion, mutable: false },
  amountIn,
  route: "AtoB",
  typeArgs,
});

const result = await client.devInspectTransactionBlock({
  sender: requireEnv("SENDER"),
  transactionBlock: tx,
});

console.log(JSON.stringify(result, null, 2));
