import { Transaction, type TransactionObjectArgument } from "@mysten/sui/transactions";

import { BaseMoveClient } from "./base";
import { sharedObjectArg } from "./shared";
import type {
  OrbitalTickConfigInput,
  OwnedObjectInput,
  Pool3TypeArgs,
  SharedObjectInput,
  SwapRoute,
  TransactionFactory,
} from "./types";

const EXACT_IN_FUNCTIONS: Record<SwapRoute, string> = {
  AtoB: "swap_a_for_b_exact_in",
  BtoA: "swap_b_for_a_exact_in",
  AtoC: "swap_a_for_c_exact_in",
  CtoA: "swap_c_for_a_exact_in",
  BtoC: "swap_b_for_c_exact_in",
  CtoB: "swap_c_for_b_exact_in",
};

const EXACT_OUT_FUNCTIONS: Record<SwapRoute, string> = {
  AtoB: "swap_a_for_b_exact_out",
  BtoA: "swap_b_for_a_exact_out",
  AtoC: "swap_a_for_c_exact_out",
  CtoA: "swap_c_for_a_exact_out",
  BtoC: "swap_b_for_c_exact_out",
  CtoB: "swap_c_for_b_exact_out",
};

export class OrbitalPool3Client extends BaseMoveClient {
  constructor(input: {
    packageId: string;
    moduleName?: string;
    txFactory?: TransactionFactory;
  }) {
    super({
      packageId: input.packageId,
      moduleName: input.moduleName ?? "orbital_pool3",
      txFactory: input.txFactory,
    });
  }

  createPool3Tx(input: {
    lpTreasuryCap: OwnedObjectInput;
    decimalsA: number;
    decimalsB: number;
    decimalsC: number;
    ticks: OrbitalTickConfigInput[];
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addCreatePool3ToTx(tx, input);
    return tx;
  }

  addCreatePool3ToTx(
    tx: Transaction,
    input: {
      lpTreasuryCap: OwnedObjectInput;
      decimalsA: number;
      decimalsB: number;
      decimalsC: number;
      ticks: OrbitalTickConfigInput[];
      typeArgs: Pool3TypeArgs;
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
      target: this.target("create_pool3"),
      typeArguments: [...input.typeArgs],
      arguments: [
        tx.object(input.lpTreasuryCap),
        tx.pure.u8(input.decimalsA),
        tx.pure.u8(input.decimalsB),
        tx.pure.u8(input.decimalsC),
        ticksVector,
      ],
    });
  }

  addLiquidityTx(input: {
    pool: SharedObjectInput;
    coinA: OwnedObjectInput;
    coinB: OwnedObjectInput;
    coinC: OwnedObjectInput;
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addAddLiquidityToTx(tx, input);
    return tx;
  }

  addAddLiquidityToTx(
    tx: Transaction,
    input: {
      pool: SharedObjectInput;
      coinA: OwnedObjectInput;
      coinB: OwnedObjectInput;
      coinC: OwnedObjectInput;
      typeArgs: Pool3TypeArgs;
    },
  ) {
    return tx.moveCall({
      target: this.target("add_liquidity"),
      typeArguments: [...input.typeArgs],
      arguments: [
        sharedObjectArg(tx, input.pool, true),
        tx.object(input.coinA),
        tx.object(input.coinB),
        tx.object(input.coinC),
      ],
    });
  }

  removeLiquidityTx(input: {
    pool: SharedObjectInput;
    lpCoin: OwnedObjectInput;
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addRemoveLiquidityToTx(tx, input);
    return tx;
  }

  addRemoveLiquidityToTx(
    tx: Transaction,
    input: { pool: SharedObjectInput; lpCoin: OwnedObjectInput; typeArgs: Pool3TypeArgs },
  ) {
    return tx.moveCall({
      target: this.target("remove_liquidity"),
      typeArguments: [...input.typeArgs],
      arguments: [sharedObjectArg(tx, input.pool, true), tx.object(input.lpCoin)],
    });
  }

  swapExactInTx(input: {
    pool: SharedObjectInput;
    coinIn: OwnedObjectInput;
    route: SwapRoute;
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addSwapExactInToTx(tx, input);
    return tx;
  }

  addSwapExactInToTx(
    tx: Transaction,
    input: { pool: SharedObjectInput; coinIn: OwnedObjectInput; route: SwapRoute; typeArgs: Pool3TypeArgs },
  ): TransactionObjectArgument {
    return tx.moveCall({
      target: this.target(EXACT_IN_FUNCTIONS[input.route]),
      typeArguments: [...input.typeArgs],
      arguments: [sharedObjectArg(tx, input.pool, true), tx.object(input.coinIn)],
    });
  }

  swapExactOutTx(input: {
    pool: SharedObjectInput;
    coinIn: OwnedObjectInput;
    amountOut: bigint | number | string;
    route: SwapRoute;
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addSwapExactOutToTx(tx, input);
    return tx;
  }

  addSwapExactOutToTx(
    tx: Transaction,
    input: {
      pool: SharedObjectInput;
      coinIn: OwnedObjectInput;
      amountOut: bigint | number | string;
      route: SwapRoute;
      typeArgs: Pool3TypeArgs;
    },
  ) {
    return tx.moveCall({
      target: this.target(EXACT_OUT_FUNCTIONS[input.route]),
      typeArguments: [...input.typeArgs],
      arguments: [
        sharedObjectArg(tx, input.pool, true),
        tx.object(input.coinIn),
        tx.pure.u64(input.amountOut),
      ],
    });
  }

  buildQuoteExactInTx(input: {
    pool: SharedObjectInput;
    amountIn: bigint | number | string;
    route: "AtoB";
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addQuoteExactInToTx(tx, input);
    return tx;
  }

  addQuoteExactInToTx(
    tx: Transaction,
    input: { pool: SharedObjectInput; amountIn: bigint | number | string; route: "AtoB"; typeArgs: Pool3TypeArgs },
  ) {
    return tx.moveCall({
      target: this.target("quote_a_for_b_exact_in"),
      typeArguments: [...input.typeArgs],
      arguments: [sharedObjectArg(tx, input.pool, false), tx.pure.u64(input.amountIn)],
    });
  }

  buildQuoteExactOutTx(input: {
    pool: SharedObjectInput;
    amountOut: bigint | number | string;
    route: "AtoB";
    typeArgs: Pool3TypeArgs;
  }): Transaction {
    const tx = this.newTx();
    this.addQuoteExactOutToTx(tx, input);
    return tx;
  }

  addQuoteExactOutToTx(
    tx: Transaction,
    input: {
      pool: SharedObjectInput;
      amountOut: bigint | number | string;
      route: "AtoB";
      typeArgs: Pool3TypeArgs;
    },
  ) {
    return tx.moveCall({
      target: this.target("quote_a_for_b_exact_out"),
      typeArguments: [...input.typeArgs],
      arguments: [sharedObjectArg(tx, input.pool, false), tx.pure.u64(input.amountOut)],
    });
  }
}
