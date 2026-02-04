import { describe, expect, it } from "bun:test";
import { fromBase64 } from "@mysten/bcs";
import { bcs } from "@mysten/sui/bcs";

import { OrbitalVaultClient } from "../../src/sdk/orbitalVault";

describe("OrbitalVaultClient", () => {
  const client = new OrbitalVaultClient({ packageId: "0xabc" });
  const sharedVault = { objectId: "0x9", initialSharedVersion: "1", mutable: true };
  const sharedPool = { objectId: "0x8", initialSharedVersion: "2", mutable: true };
  const sharedClock = { objectId: "0x6", initialSharedVersion: "1", mutable: false };
  const typeArgs = ["0x2::a::A", "0x2::b::B", "0x2::lp::LP"] as const;

  it("encodes tick configs as BCS vector", () => {
    const tx = client.updateConfigTx({
      cap: "0x1",
      vault: sharedVault,
      ticks: [
        { bandBps: 100, weightBps: 5000 },
        { bandBps: 200, weightBps: 5000 },
      ],
      maxSkewPercent: 25,
      typeArgs,
    });

    const inputs = tx.getData().inputs;
    const tickInput = inputs[2];
    if (!tickInput || tickInput.$kind !== "Pure") {
      throw new Error("Missing pure tick input");
    }

    const Tick = bcs.struct("OrbitalTickConfig", {
      band_bps: bcs.u64(),
      weight_bps: bcs.u64(),
    });
    const TickVec = bcs.vector(Tick);

    const bytes = fromBase64(tickInput.Pure.bytes);
    const decoded = TickVec.parse(bytes);

    expect(decoded).toEqual([
      { band_bps: "100", weight_bps: "5000" },
      { band_bps: "200", weight_bps: "5000" },
    ]);
  });

  it("builds place orders tx with proof dependency", () => {
    const tx = client.placeOrbitalOrdersWithProofTx({
      cap: "0x1",
      vault: sharedVault,
      pool: sharedPool,
      orderSizeLots: 1000,
      orderType: 0,
      selfMatchingOption: 0,
      payWithDeep: false,
      expireTimestamp: 1234,
      clock: sharedClock,
      typeArgs,
    });

    const commands = tx.getData().commands;
    expect(commands.length).toBe(2);
    expect(commands[0]?.MoveCall.function).toBe("generate_trade_proof");
    expect(commands[1]?.MoveCall.function).toBe("place_orbital_orders");

    const proofArg = commands[1]?.MoveCall.arguments?.[2] as { $kind?: string; Result?: number } | undefined;
    expect(proofArg?.$kind).toBe("Result");
    expect(proofArg?.Result).toBe(0);
  });
});
