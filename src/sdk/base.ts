import { Transaction } from "@mysten/sui/transactions";

import type { TransactionFactory } from "./types";
import { DefaultTransactionFactory } from "./tx";

export abstract class BaseMoveClient {
  protected readonly packageId: string;
  protected readonly moduleName: string;
  protected readonly txFactory: TransactionFactory;

  protected constructor(input: {
    packageId: string;
    moduleName: string;
    txFactory?: TransactionFactory;
  }) {
    this.packageId = input.packageId;
    this.moduleName = input.moduleName;
    this.txFactory = input.txFactory ?? new DefaultTransactionFactory();
  }

  protected target(functionName: string): string {
    return `${this.packageId}::${this.moduleName}::${functionName}`;
  }

  protected newTx(): Transaction {
    return this.txFactory.create();
  }
}
