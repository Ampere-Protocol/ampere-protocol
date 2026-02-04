import { Inputs, type Transaction, type TransactionObjectArgument } from "@mysten/sui/transactions";

import type { SharedObjectInput, SharedObjectRef } from "./types";

export const SUI_CLOCK_OBJECT_ID = "0x6";

type SharedOwner = { Shared: { initial_shared_version: string } };

export interface SharedObjectResolverClient {
  getObject(args: { id: string; options?: { showOwner?: boolean } }): Promise<{
    data?: {
      objectId: string;
      owner?: unknown;
    } | null;
    error?: unknown;
  }>;
}

export function isSharedOwner(owner: unknown): owner is SharedOwner {
  return (
    typeof owner === "object" &&
    owner !== null &&
    "Shared" in owner &&
    typeof (owner as SharedOwner).Shared?.initial_shared_version === "string"
  );
}

export function sharedObjectRefFromResponse(
  response: { data?: { objectId: string; owner?: unknown } | null },
  mutable = true,
): SharedObjectRef {
  if (!response.data) {
    throw new Error("Shared object not found in response");
  }
  return sharedObjectRefFromOwner(response.data.objectId, response.data.owner, mutable);
}

export function sharedObjectRefFromOwner(
  objectId: string,
  owner: unknown,
  mutable = true,
): SharedObjectRef {
  if (!isSharedOwner(owner)) {
    throw new Error("Object is not shared");
  }
  return {
    objectId,
    initialSharedVersion: owner.Shared.initial_shared_version,
    mutable,
  };
}

export async function resolveSharedObjectRef(
  client: SharedObjectResolverClient,
  objectId: string,
  mutable = true,
): Promise<SharedObjectRef> {
  const response = await client.getObject({
    id: objectId,
    options: { showOwner: true },
  });
  return sharedObjectRefFromResponse(response, mutable);
}

export function sharedObjectArg(
  tx: Transaction,
  input: SharedObjectInput,
  mutableOverride?: boolean,
): TransactionObjectArgument {
  if (typeof input === "string") {
    return tx.object(input);
  }
  const mutable = mutableOverride ?? input.mutable;
  return tx.object(
    Inputs.SharedObjectRef({
      objectId: input.objectId,
      initialSharedVersion: input.initialSharedVersion,
      mutable,
    }),
  );
}
