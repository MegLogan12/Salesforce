import AsyncStorage from '@react-native-async-storage/async-storage';
import type { QueueRepository } from '@/offline/QueueRepository';
import type { OfflineQueueItem } from '@/offline/types';

const KEY = 'loving-foreman-alpha-queue-v1';

export class AsyncQueueRepository implements QueueRepository {
  async listPending(): Promise<OfflineQueueItem[]> {
    return this.readAll();
  }

  async save(item: OfflineQueueItem): Promise<void> {
    const items = await this.readAll();
    items.unshift(item);
    await this.writeAll(items);
  }

  async update(item: OfflineQueueItem): Promise<void> {
    const items = await this.readAll();
    const next = items.map((row) => (row.localId === item.localId ? item : row));
    await this.writeAll(next);
  }

  async getById(localId: string): Promise<OfflineQueueItem | null> {
    const items = await this.readAll();
    return items.find((row) => row.localId === localId) ?? null;
  }

  private async readAll(): Promise<OfflineQueueItem[]> {
    const raw = await AsyncStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as OfflineQueueItem[]) : [];
  }

  private async writeAll(items: OfflineQueueItem[]): Promise<void> {
    await AsyncStorage.setItem(KEY, JSON.stringify(items));
  }
}
