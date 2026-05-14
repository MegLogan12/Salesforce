import type { OfflineQueueItem } from '@/offline/types';

export interface QueueRepository {
  listPending(): Promise<OfflineQueueItem[]>;
  save(item: OfflineQueueItem): Promise<void>;
  update(item: OfflineQueueItem): Promise<void>;
  getById(localId: string): Promise<OfflineQueueItem | null>;
}
