/**
 * Ampere Protocol - Deployed Contract Addresses
 * Network: Sui Testnet
 * Deployment Date: February 4, 2026
 * Transaction: EDUHudPVDUoGUSRTBbqroi4kKtNAGnkymFpb5ybkQ7kX
 */

export const AMPERE_ADDRESSES = {
  // Main package address
  PACKAGE_ID: "0x7496a7cdab854070ee2952bc53f05277bafc6b4934691411ac4fe11df8ac3e13 ",
  
  // UpgradeCap for package upgrades
  UPGRADE_CAP: "0x319a7f6156ae0ab386a41bad47c103710f626921d5c68e8ab16c075235cc4e1c",
  
  // Module names
  MODULES: {
    MM_VAULT: "mm_vault",
    ORBITAL_POOL3: "orbital_pool3",
    ORBITAL_VAULT: "orbital_vault",
  },
} as const;

/**
 * Sui system addresses
 */
export const SUI_SYSTEM = {
  CLOCK: "0x0000000000000000000000000000000000000000000000000000000000000006",
} as const;

/**
 * Helper function to get full module identifier
 */
export function getModuleId(moduleName: keyof typeof AMPERE_ADDRESSES.MODULES): string {
  return `${AMPERE_ADDRESSES.PACKAGE_ID}::${AMPERE_ADDRESSES.MODULES[moduleName]}`;
}

/**
 * Export default configuration
 */
export const DEFAULT_CONFIG = {
  packageId: AMPERE_ADDRESSES.PACKAGE_ID,
  modules: {
    orbitalPool3: AMPERE_ADDRESSES.MODULES.ORBITAL_POOL3,
    orbitalVault: AMPERE_ADDRESSES.MODULES.ORBITAL_VAULT,
  },
} as const;
