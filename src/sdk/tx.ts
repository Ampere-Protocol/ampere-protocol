import { Transaction } from "@mysten/sui/transactions";

import type { TransactionFactory } from "./types";

export class DefaultTransactionFactory implements TransactionFactory {
  create(): Transaction {
    return new Transaction();
  }
}

export function createTransaction(): Transaction {
  return new Transaction();
}
