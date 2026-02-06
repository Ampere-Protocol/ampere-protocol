import { getClient } from "./utils";

const client = getClient();
const poolId = "0x3eed9e889440ea868516b05cf5d773627f87167720a9136e26ec6244f2ab9e0b";

const result = await client.getObject({
  id: poolId,
  options: { showOwner: true, showContent: true },
});

console.log("Pool Owner:", JSON.stringify(result.data?.owner, null, 2));
