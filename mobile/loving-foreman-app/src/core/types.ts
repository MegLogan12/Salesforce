import type { SyncStatus } from '@/data/contracts';
import type { OfflineQueueItem } from '@/offline/types';

export type ScreenName =
  | 'language'
  | 'signIn'
  | 'myDay'
  | 'fieldManagerMock'
  | 'serviceAppointmentDetail'
  | 'workOrderDetail'
  | 'preShiftChecks'
  | 'routeNavigation'
  | 'arrival'
  | 'activeJob'
  | 'flagIssue'
  | 'closeout'
  | 'syncQueue'
  | 'settings';

export interface AuthSessionState {
  mode: 'debugToken' | 'oauth' | 'blocked';
  instanceUrl?: string;
  accessToken?: string;
  username?: string;
  userId?: string;
  orgId?: string;
  blocker?: string;
}

export interface ResourceSelection {
  serviceResourceId: string;
  serviceResourceName: string;
  relatedUserId?: string;
}

export interface AppSnapshot {
  language: 'en' | 'es';
  currentRole?: 'foreman' | 'fieldManager';
  selectedDate: string;
  selectedResource?: ResourceSelection;
  queue: OfflineQueueItem[];
  currentScreen: ScreenName;
  currentServiceAppointmentId?: string;
  currentWorkOrderId?: string;
  lastSyncAt?: string;
  lastSyncStatus?: SyncStatus;
}
