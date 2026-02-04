import { describe, expect, it } from "bun:test";
import { Inputs } from "@mysten/sui/transactions";

import { OrbitalPool3Client } from "../../src/sdk/orbitalPool3";

describe("OrbitalPool3Client", () => {
  const client = new OrbitalPool3Client({ packageId: "0xabc" });
  const sharedPool = { objectId: "0x2", initialSharedVersion: "1", mutable: true };
  const typeArgs = [
    "0x2::a::A",
    "0x2::b::B",
    "0x2::c::C",
    "0x2::lp::LP",
  ] as const;

  it("builds add liquidity move call", () => {
    const tx = client.addLiquidityTx({
      pool: sharedPool,
      coinA: "0x3",
      coinB: "0x4",
      coinC: "0x5",
      typeArgs,
    });

    const [command] = tx.getData().commands;
    expect(command?.$kind).toBe("MoveCall");
    expect(command?.MoveCall.function).toBe("add_liquidity");
    expect(command?.MoveCall.typeArguments).toEqual([...typeArgs]);
    expect(command?.MoveCall.arguments?.length).toBe(4);
  });

  it("routes swaps to the correct function", () => {
    const tx = client.swapExactInTx({
      pool: sharedPool,
      coinIn: "0x3",
      route: "CtoB",
      typeArgs,
    });

    const [command] = tx.getData().commands;
    expect(command?.MoveCall.function).toBe("swap_c_for_b_exact_in");
  });

  it("uses immutable shared refs for quotes", () => {
    const tx = client.buildQuoteExactInTx({
      pool: sharedPool,
      amountIn: 100,
      route: "AtoB",
      typeArgs,
    });

    const [input] = tx.getData().inputs;
    const shared = Inputs.SharedObjectRef({
      objectId: sharedPool.objectId,
      initialSharedVersion: sharedPool.initialSharedVersion,
      mutable: false,
    });
    expect(input).toEqual(shared);
  });
});
