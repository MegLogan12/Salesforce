export type Scene =
  | 'pin'
  | 'login'
  | 'myDay'
  | 'morning'
  | 'drive'
  | 'arriving'
  | 'active'
  | 'measuring'
  | 'lunch'
  | 'flag'
  | 'closeout'
  | 'eod';

export type Lang = 'en' | 'es';

export interface SfFieldManager {
  id: string;
  name: string;
  phone: string;
  email: string;
  region: string;
}

export type DeliveryProduct = 'Sod' | 'Mulch';
export type DeliveryUnit = 'pallets' | 'cu yd' | 'bags';

export interface SfDeliveryLine {
  id: string;
  product: DeliveryProduct;
  species?: string;
  unit: DeliveryUnit;
  expectedQty: number;
  vendor: string;
  poNumber: string;
  scheduledIso: string;
}

export interface SfWorkOrder {
  id: string;
  woNumber: string;
  subject: string;
  workOrderType: 'Sod Install' | 'Sod Repair' | 'Fertilization' | 'Mowing' | 'Tree';
  subStatus: 'Pre-Install' | 'In Progress' | 'Awaiting QI' | 'Complete' | 'On Hold';
  sodSpecies: string;
  sodSqft: number;
  goalHours: number;
  fieldManager: SfFieldManager;
  address: string;
  deliveries: SfDeliveryLine[];
}

export interface SfServiceAppointment {
  id: string;
  parentWorkOrderId: string;
  scheduledStartIso: string;
  scheduledEndIso: string;
  status: 'Scheduled' | 'Dispatched' | 'In Progress' | 'Completed';
  resourceName: string;
}

export interface SfChecklistItem {
  id: string;
  label: string;
  required: boolean;
  done: boolean;
  category: 'vehicle' | 'loaded' | 'closeout';
}

export type CrewStatus = 'Confirmed' | 'Clocked In' | 'On Break' | 'Clocked Out';

export interface SfCrewMember {
  id: string;
  name: string;
  status: CrewStatus;
}

export interface SfDirectionStep {
  icon: string;
  instruction: string;
  distance: string;
}

export interface SfCapturedPhoto {
  id: string;
  uri: string;
  category:
    | 'before'
    | 'progress'
    | 'hero-after'
    | 'after'
    | 'flag'
    | 'delivery-qc'
    | 'excess';
  capturedAt: string;
  deliveryLineId?: string;
}

export interface SfFlagReport {
  speciesDiscovered: string;
  extraSqft: number | null;
  photoUri?: string;
  submitted: boolean;
}

export type DeliveryQcVerdict = 'pending' | 'green' | 'red';

export interface SfDeliveryQcResult {
  deliveryLineId: string;
  verdict: DeliveryQcVerdict;
  verifiedQty: number | null;
  issueNote: string;
  photoId?: string;
  submittedAt?: string;
  locked: boolean;
}

export interface SfPinAuth {
  expectedPin: string;
  foremanId: string;
  attemptsRemaining: number;
  locked: boolean;
}

export interface SfInventoryItem {
  id: string;
  label: string;
  unit: string;
  loaded: number;
  used: number | null;
  returned: number | null;
}

export interface SfInventoryReport {
  items: SfInventoryItem[];
  hasExcess: boolean | null;
  excessDetails: string;
  excessPhotoCaptured: boolean;
  hasMissing: boolean | null;
  missingDetails: string;
  submitted: boolean;
}

export interface SfHousekeepingItem {
  id: string;
  label: string;
  done: boolean;
  required: boolean;
}

export interface SfMeasurement {
  id: string;
  label: string;
  lengthFt: number | null;
  widthFt: number | null;
  notes: string;
}

export interface ForemanDay {
  dateIso: string;
  foremanName: string;
  depot: string;
  crew: SfCrewMember[];
  workOrders: SfWorkOrder[];
  serviceAppointments: SfServiceAppointment[];
  vehicleChecklist: SfChecklistItem[];
  loadedChecklist: SfChecklistItem[];
  closeoutChecklist: SfChecklistItem[];
  housekeeping: SfHousekeepingItem[];
  directions: SfDirectionStep[];
  selectedWorkOrderId: string | null;
  clockedInAt: string | null;
  clockedOutAt: string | null;
  arrivedAt: string | null;
  jobStartedAt: string | null;
  lunchStartAt: string | null;
  photos: SfCapturedPhoto[];
  flag: SfFlagReport;
  deliveryQc: SfDeliveryQcResult[];
  inventory: SfInventoryReport;
  measurements: SfMeasurement[];
}

export interface ForemanState {
  pinAuth: SfPinAuth;
  pinEntered: string;
  authenticated: boolean;
  lang: Lang;
  scene: Scene;
  day: ForemanDay;
  syncedAtIso: string;
}
