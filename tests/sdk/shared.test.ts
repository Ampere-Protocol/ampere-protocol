import { describe, expect, it } from "bun:test";

import { sharedObjectRefFromResponse } from "../../src/sdk/shared";

describe("sharedObjectRefFromResponse", () => {
  it("returns a shared object ref with mutable default", () => {
    const ref = sharedObjectRefFromResponse({
      data: {
        objectId: "0x123",
        owner: {
          Shared: { initial_shared_version: "42" },
        },
      },
    });

    expect(ref.objectId).toBe("0x123");
    expect(ref.initialSharedVersion).toBe("42");
    expect(ref.mutable).toBe(true);
  });

  it("throws when object is not shared", () => {
    expect(() =>
      sharedObjectRefFromResponse({
        data: {
          objectId: "0x123",
          owner: { AddressOwner: "0xabc" },
        },
      }),
    ).toThrow("Object is not shared");
  });
});
