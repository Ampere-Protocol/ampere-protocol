// Ampere Protocol SDK Entry Point
// Deployed Package: 0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf
// UpgradeCap: 0x319a7f6156ae0ab386a41bad47c103710f626921d5c68e8ab16c075235cc4e1c

import { OrbitalSdk, createSdkConfig } from "./src/sdk";

// Example configuration with deployed package
const config = createSdkConfig({
  packageId: "0xcea0d7d35eed45dc26fbd3ec0a84378bbd95d83118b501540650e267ad42bfdf",
});

const sdk = new OrbitalSdk(config);

console.log("Ampere Protocol SDK initialized");
console.log("Package ID:", config.packageId);
console.log("Modules:", config.modules);

export { sdk, config };