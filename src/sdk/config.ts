import type { OrbitalSdkConfig, OrbitalSdkModules } from "./types";

export const DEFAULT_MODULES: OrbitalSdkModules = {
  orbitalPool3: "orbital_pool3",
  orbitalVault: "orbital_vault",
};

export function createSdkConfig(input: {
  packageId: string;
  modules?: Partial<OrbitalSdkModules>;
}): OrbitalSdkConfig {
  return {
    packageId: input.packageId,
    modules: {
      orbitalPool3: input.modules?.orbitalPool3 ?? DEFAULT_MODULES.orbitalPool3,
      orbitalVault: input.modules?.orbitalVault ?? DEFAULT_MODULES.orbitalVault,
    },
  };
}
