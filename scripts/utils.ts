import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";

import { createSdkConfig, OrbitalSdk, type OrbitalTickConfigInput } from "../src/sdk";

export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing env var: ${name}`);
  }
  return value;
}

export function getClient(): SuiJsonRpcClient {
  const url = requireEnv("SUI_RPC");
  return new SuiJsonRpcClient({ url, network: "custom" });
}

export function getKeypair(): Ed25519Keypair {
  const secret = requireEnv("SUI_PRIVATE_KEY");
  return Ed25519Keypair.fromSecretKey(secret);
}

export function getSdk(): OrbitalSdk {
  const packageId = requireEnv("PACKAGE_ID");
  return new OrbitalSdk(createSdkConfig({ packageId }));
}

export function getTicks(): OrbitalTickConfigInput[] {
  const raw = process.env.TICKS_JSON;
  if (!raw) {
    return [
      { bandBps: 50, weightBps: 6000 },
      { bandBps: 100, weightBps: 4000 },
    ];
  }
  const parsed = JSON.parse(raw) as OrbitalTickConfigInput[];
  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error("TICKS_JSON must be a non-empty array");
  }
  return parsed;
}

export function getTypeArgsPool3(): readonly [string, string, string, string] {
  const typeA = requireEnv("TYPE_A");
  const typeB = requireEnv("TYPE_B");
  const typeC = requireEnv("TYPE_C");
  const typeLP = requireEnv("TYPE_LP");
  return [typeA, typeB, typeC, typeLP] as const;
}

export function getDecimals(): { a: number; b: number; c: number } {
  const a = Number.parseInt(requireEnv("DECIMALS_A"), 10);
  const b = Number.parseInt(requireEnv("DECIMALS_B"), 10);
  const c = Number.parseInt(requireEnv("DECIMALS_C"), 10);
  return { a, b, c };
}
