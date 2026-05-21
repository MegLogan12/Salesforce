import type { QueueRepository } from '@/offline/QueueRepository';

export interface SyncEngineDependencies {
  queueRepository: QueueRepository;
}

export class SyncEngine {
  constructor(private readonly deps: SyncEngineDependencies) {}

  async syncPending(): Promise<void> {
    const queue = await this.deps.queueRepository.listPending();
    for (const item of queue) {
      void item;
      // Wire to Salesforce batch sync contract in implementation phase.
    }
  }
}
