import type { SyncStatus } from '@/data/contracts';

export interface OfflineQueueItem {
  localId: string;
  salesforceRecordId?: string;
  objectApiName: string;
  actionType: string;
  payload: Record<string, unknown>;
  localCreatedAt: string;
  localUpdatedAt: string;
  userId: string;
  serviceResourceId: string;
  serviceAppointmentId?: string;
  workOrderId?: string;
  locationLatitude?: number;
  locationLongitude?: number;
  photoLocalUri?: string;
  retryCount: number;
  syncStatus: SyncStatus;
  errorMessage?: string;
  conflictState?: string;
}
