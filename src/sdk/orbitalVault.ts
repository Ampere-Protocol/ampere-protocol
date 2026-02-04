import { Transaction, type TransactionArgument } from "@mysten/sui/transactions";

import { BaseMoveClient } from "./base";
import { sharedObjectArg } from "./shared";
import type {
  OrbitalTickConfigInput,
  OwnedObjectInput,
  SharedObjectInput,
  TransactionFactory,
  VaultTypeArgs,
} from "./types";

export class OrbitalVaultClient extends BaseMoveClient {
  constructor(input: {
    packageId: string;
    moduleName?: string;
    txFactory?: TransactionFactory;
  }) {
    super({
      packageId: input.packageId,
      moduleName: input.moduleName ?? "orbital_vault",
      txFactory: input.txFactory,
    });
  }

  createVaultTx(input: {
    lpTreasuryCap: OwnedObjectInput;
    basePriceId: Iterable<number> & { length: number };
    quotePriceId: Iterable<number> & { length: number };
    poolId: string;
    ticks: OrbitalTickConfigInput[];
    maxSkewPercent: bigint | number | string;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addCreateVaultToTx(tx, input);
    return tx;
  }

  addCreateVaultToTx(
    tx: Transaction,
    input: {
      lpTreasuryCap: OwnedObjectInput;
      basePriceId: Iterable<number> & { length: number };
      quotePriceId: Iterable<number> & { length: number };
      poolId: string;
      ticks: OrbitalTickConfigInput[];
      maxSkewPercent: bigint | number | string;
      typeArgs: VaultTypeArgs;
    },
  ) {
    // Create OrbitalTickConfig objects on-chain
    const tickConfigs = input.ticks.map((tick) => {
      return tx.moveCall({
        target: this.target("new_tick_config"),
        arguments: [
          tx.pure.u64(tick.bandBps),
          tx.pure.u64(tick.weightBps),
        ],
      });
    });

    // Create a vector of OrbitalTickConfig objects
    const ticksVector = tx.makeMoveVec({
      type: `${this.packageId}::${this.moduleName}::OrbitalTickConfig`,
      elements: tickConfigs,
    });

    return tx.moveCall({
      target: this.target("create_orbital_vault"),
      typeArguments: [...input.typeArgs],
      arguments: [
        tx.object(input.lpTreasuryCap),
        tx.pure.vector("u8", input.basePriceId),
        tx.pure.vector("u8", input.quotePriceId),
        tx.pure.id(input.poolId),
        ticksVector,
        tx.pure.u64(input.maxSkewPercent),
      ],
    });
  }

  updateConfigTx(input: {
    cap: OwnedObjectInput;
    vault: SharedObjectInput;
    ticks: OrbitalTickConfigInput[];
    maxSkewPercent: bigint | number | string;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addUpdateConfigToTx(tx, input);
    return tx;
  }

  addUpdateConfigToTx(
    tx: Transaction,
    input: {
      cap: OwnedObjectInput;
      vault: SharedObjectInput;
      ticks: OrbitalTickConfigInput[];
      maxSkewPercent: bigint | number | string;
      typeArgs: VaultTypeArgs;
    },
  ) {
    // Create OrbitalTickConfig objects on-chain
    const tickConfigs = input.ticks.map((tick) => {
      return tx.moveCall({
        target: this.target("new_tick_config"),
        arguments: [
          tx.pure.u64(tick.bandBps),
          tx.pure.u64(tick.weightBps),
        ],
      });
    });

    // Create a vector of OrbitalTickConfig objects
    const ticksVector = tx.makeMoveVec({
      type: `${this.packageId}::${this.moduleName}::OrbitalTickConfig`,
      elements: tickConfigs,
    });

    return tx.moveCall({
      target: this.target("update_config"),
      typeArguments: [...input.typeArgs],
      arguments: [
        tx.object(input.cap),
        sharedObjectArg(tx, input.vault, true),
        ticksVector,
        tx.pure.u64(input.maxSkewPercent),
      ],
    });
  }

  depositTx(input: {
    vault: SharedObjectInput;
    baseCoin: OwnedObjectInput;
    quoteCoin: OwnedObjectInput;
    basePriceInfo: SharedObjectInput;
    quotePriceInfo: SharedObjectInput;
    clock: SharedObjectInput;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addDepositToTx(tx, input);
    return tx;
  }

  addDepositToTx(
    tx: Transaction,
    input: {
      vault: SharedObjectInput;
      baseCoin: OwnedObjectInput;
      quoteCoin: OwnedObjectInput;
      basePriceInfo: SharedObjectInput;
      quotePriceInfo: SharedObjectInput;
      clock: SharedObjectInput;
      typeArgs: VaultTypeArgs;
    },
  ) {
    return tx.moveCall({
      target: this.target("deposit"),
      typeArguments: [...input.typeArgs],
      arguments: [
        sharedObjectArg(tx, input.vault, true),
        tx.object(input.baseCoin),
        tx.object(input.quoteCoin),
        sharedObjectArg(tx, input.basePriceInfo, false),
        sharedObjectArg(tx, input.quotePriceInfo, false),
        sharedObjectArg(tx, input.clock, false),
      ],
    });
  }

  withdrawTx(input: {
    vault: SharedObjectInput;
    lpCoin: OwnedObjectInput;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addWithdrawToTx(tx, input);
    return tx;
  }

  addWithdrawToTx(
    tx: Transaction,
    input: { vault: SharedObjectInput; lpCoin: OwnedObjectInput; typeArgs: VaultTypeArgs },
  ) {
    return tx.moveCall({
      target: this.target("withdraw"),
      typeArguments: [...input.typeArgs],
      arguments: [sharedObjectArg(tx, input.vault, true), tx.object(input.lpCoin)],
    });
  }

  generateTradeProofTx(input: {
    cap: OwnedObjectInput;
    vault: SharedObjectInput;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addGenerateTradeProofToTx(tx, input);
    return tx;
  }

  addGenerateTradeProofToTx(
    tx: Transaction,
    input: { cap: OwnedObjectInput; vault: SharedObjectInput; typeArgs: VaultTypeArgs },
  ) {
    return tx.moveCall({
      target: this.target("generate_trade_proof"),
      typeArguments: [...input.typeArgs],
      arguments: [tx.object(input.cap), sharedObjectArg(tx, input.vault, true)],
    });
  }

  placeOrbitalOrdersTx(input: {
    cap: OwnedObjectInput;
    vault: SharedObjectInput;
    tradeProof: TransactionArgument;
    pool: SharedObjectInput;
    orderSizeLots: bigint | number | string;
    orderType: number;
    selfMatchingOption: number;
    payWithDeep: boolean;
    expireTimestamp: bigint | number | string;
    clock: SharedObjectInput;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addPlaceOrbitalOrdersToTx(tx, input);
    return tx;
  }

  addPlaceOrbitalOrdersToTx(
    tx: Transaction,
    input: {
      cap: OwnedObjectInput;
      vault: SharedObjectInput;
      tradeProof: TransactionArgument;
      pool: SharedObjectInput;
      orderSizeLots: bigint | number | string;
      orderType: number;
      selfMatchingOption: number;
      payWithDeep: boolean;
      expireTimestamp: bigint | number | string;
      clock: SharedObjectInput;
      typeArgs: VaultTypeArgs;
    },
  ) {
    return tx.moveCall({
      target: this.target("place_orbital_orders"),
      typeArguments: [...input.typeArgs],
      arguments: [
        tx.object(input.cap),
        sharedObjectArg(tx, input.vault, true),
        input.tradeProof,
        sharedObjectArg(tx, input.pool, true),
        tx.pure.u64(input.orderSizeLots),
        tx.pure.u8(input.orderType),
        tx.pure.u8(input.selfMatchingOption),
        tx.pure.bool(input.payWithDeep),
        tx.pure.u64(input.expireTimestamp),
        sharedObjectArg(tx, input.clock, false),
      ],
    });
  }

  placeOrbitalOrdersWithProofTx(input: {
    cap: OwnedObjectInput;
    vault: SharedObjectInput;
    pool: SharedObjectInput;
    orderSizeLots: bigint | number | string;
    orderType: number;
    selfMatchingOption: number;
    payWithDeep: boolean;
    expireTimestamp: bigint | number | string;
    clock: SharedObjectInput;
    typeArgs: VaultTypeArgs;
  }): Transaction {
    const tx = this.newTx();
    const proof = this.addGenerateTradeProofToTx(tx, {
      cap: input.cap,
      vault: input.vault,
      typeArgs: input.typeArgs,
    });
    this.addPlaceOrbitalOrdersToTx(tx, {
      ...input,
      tradeProof: proof,
    });
    return tx;
  }
}
