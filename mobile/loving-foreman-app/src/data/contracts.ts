export type LanguageCode = 'en' | 'es';

export type SyncStatus =
  | 'Draft Local'
  | 'Queued'
  | 'Syncing'
  | 'Synced'
  | 'Failed'
  | 'Conflict'
  | 'Needs Review';

export type IssueType =
  | 'Site Not Ready'
  | 'Material Missing'
  | 'Material Damaged'
  | 'Sod Quality Issue'
  | 'Weather'
  | 'Traffic'
  | 'Access Blocked'
  | 'Scope Conflict'
  | 'Customer / Builder Hold'
  | 'Safety Issue'
  | 'Other';

export interface ForemanSession {
  userId: string;
  serviceResourceId: string;
  serviceCrewId?: string;
  truckLabel: string;
  vehicleId?: string;
  language: LanguageCode;
}

export interface MyDaySummary {
  serviceAppointments: ServiceAppointmentSummary[];
  syncStatus: SyncStatus;
  gpsStatus: GpsStatus;
  ripplingStatus: RipplingStatus;
  weather?: WeatherSummary;
}

export interface ServiceAppointmentSummary {
  id: string;
  appointmentNumber: string;
  status: string;
  scheduledStart?: string;
  scheduledEnd?: string;
  routeOrder?: number;
  workOrderId: string;
  workTypeName?: string;
  builderName?: string;
  communityName?: string;
  lotName?: string;
  addressLine?: string;
  marketId?: string;
  marketName?: string;
  crewName?: string;
  goalHours?: number;
  missingDataFlags: string[];
}

export interface WorkOrderDetail {
  id: string;
  workOrderNumber: string;
  subject?: string;
  status: string;
  workTypeName?: string;
  jobType?: string;
  communityName?: string;
  builderName?: string;
  lotName?: string;
  addressLine?: string;
  notes?: string;
  lineItems: WorkOrderLineItem[];
  checklistGroups: ChecklistGroup[];
  photoRequirements: PhotoRequirement[];
  serviceAppointmentId?: string;
  marketId?: string;
  marketName?: string;
  missingDataFlags: string[];
}

export interface WorkOrderLineItem {
  id: string;
  description: string;
  quantity?: number;
  status: 'Not Started' | 'In Progress' | 'Complete' | 'Cannot Complete' | 'Blocked' | 'Needs FM Review';
}

export interface ChecklistGroup {
  id: string;
  name: string;
  items: ChecklistItem[];
}

export interface ChecklistItem {
  id: string;
  label: string;
  required: boolean;
  status: 'Pending' | 'Complete' | 'N/A';
  notes?: string;
}

export interface PhotoRequirement {
  category: PhotoCategory;
  required: boolean;
}

export type PhotoCategory =
  | 'Before Front'
  | 'Before Back'
  | 'Before Side Left'
  | 'Before Side Right'
  | 'Sod Quality'
  | 'Progress'
  | 'Issue'
  | 'Final'
  | 'Material'
  | 'Safety';

export interface GpsStatus {
  truckLabel?: string;
  vehicleId?: string;
  latitude?: number;
  longitude?: number;
  heading?: number;
  speed?: number;
  lastPingAt?: string;
  isStale: boolean;
}

export interface RipplingStatus {
  employeeId?: string;
  clockStatus?: 'Clocked In' | 'Clocked Out' | 'On Break' | 'Unknown';
  totalHoursToday?: number;
  lastSyncAt?: string;
  exceptionState?: string;
}

export interface WeatherSummary {
  summary: string;
  temperatureF?: number;
  alerts: string[];
}

export interface IssueDraft {
  issueType: IssueType;
  notes: string;
  impactedLineItemIds: string[];
  photoQueueIds: string[];
}

export interface ServiceAppointmentDetail {
  id: string;
  appointmentNumber: string;
  status: string;
  scheduledStart?: string;
  scheduledEnd?: string;
  workTypeName?: string;
  workOrderId?: string;
  workOrderNumber?: string;
  builderName?: string;
  communityName?: string;
  lotName?: string;
  marketId?: string;
  marketName?: string;
  addressLine?: string;
  assignedResourceName?: string;
  notes?: string;
  requiredPhotos: PhotoRequirement[];
  checklistGroups: ChecklistGroup[];
  lineItems: WorkOrderLineItem[];
  missingDataFlags: string[];
}
