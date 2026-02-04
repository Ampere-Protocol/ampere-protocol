import { OrbitalPool3Client } from "./orbitalPool3";
import { OrbitalVaultClient } from "./orbitalVault";
import type { OrbitalSdkConfig, TransactionFactory } from "./types";

export { createSdkConfig, DEFAULT_MODULES } from "./config";
export { BaseMoveClient } from "./base";
export { DefaultTransactionFactory, createTransaction } from "./tx";
export {
  SUI_CLOCK_OBJECT_ID,
  isSharedOwner,
  resolveSharedObjectRef,
  sharedObjectArg,
  sharedObjectRefFromOwner,
  sharedObjectRefFromResponse,
} from "./shared";
export { OrbitalPool3Client } from "./orbitalPool3";
export { OrbitalVaultClient } from "./orbitalVault";
export type {
  OrbitalSdkConfig,
  OrbitalSdkModules,
  OrbitalTickConfigInput,
  OwnedObjectInput,
  Pool3TypeArgs,
  SharedObjectInput,
  SharedObjectRef,
  SwapRoute,
  TransactionFactory,
  VaultTypeArgs,
} from "./types";

export class OrbitalSdk {
  readonly pool3: OrbitalPool3Client;
  readonly vault: OrbitalVaultClient;

  constructor(config: OrbitalSdkConfig, txFactory?: TransactionFactory) {
    this.pool3 = new OrbitalPool3Client({
      packageId: config.packageId,
      moduleName: config.modules.orbitalPool3,
      txFactory,
    });
    this.vault = new OrbitalVaultClient({
      packageId: config.packageId,
      moduleName: config.modules.orbitalVault,
      txFactory,
    });
  }
}
