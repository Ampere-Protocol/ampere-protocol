import type { Transaction, TransactionObjectArgument } from "@mysten/sui/transactions";

export type ObjectId = string;
export type SuiAddress = string;

export interface SharedObjectRef {
  objectId: ObjectId;
  initialSharedVersion: string | number;
  mutable: boolean;
}

export type SharedObjectInput = ObjectId | SharedObjectRef;

export type OwnedObjectInput = ObjectId | TransactionObjectArgument;

export interface OrbitalSdkModules {
  orbitalPool3: string;
  orbitalVault: string;
}

export interface OrbitalSdkConfig {
  packageId: ObjectId;
  modules: OrbitalSdkModules;
}

export interface TransactionFactory {
  create(): Transaction;
}

export interface OrbitalTickConfigInput {
  bandBps: number;
  weightBps: number;
}

export type Pool3TypeArgs = readonly [string, string, string, string];
export type VaultTypeArgs = readonly [string, string, string];

export type SwapRoute = "AtoB" | "BtoA" | "AtoC" | "CtoA" | "BtoC" | "CtoB";
