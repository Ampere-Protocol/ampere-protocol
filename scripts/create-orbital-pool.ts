import { getClient, getDecimals, getKeypair, getSdk, getTicks, getTypeArgsPool3, requireEnv } from "./utils";

const client = getClient();
const keypair = getKeypair();
const sdk = getSdk();

const lpTreasuryCap = requireEnv("LP_TREASURY_CAP");
const { a, b, c } = getDecimals();
const ticks = getTicks();
const typeArgs = getTypeArgsPool3();

const tx = sdk.pool3.createPool3Tx({
  lpTreasuryCap,
  decimalsA: a,
  decimalsB: b,
  decimalsC: c,
  ticks,
  typeArgs,
});

const result = await client.signAndExecuteTransaction({
  signer: keypair,
  transaction: tx,
  options: { showEffects: true, showObjectChanges: true },
});

console.log(JSON.stringify(result, null, 2));
