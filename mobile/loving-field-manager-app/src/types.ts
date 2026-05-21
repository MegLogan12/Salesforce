export type PillTone = "green" | "amber" | "red" | "aqua" | "blue" | "purple" | "gray";

export interface Pill { label: string; tone: PillTone; }
export interface CurrentUser { id: string; name: string; role: string; }
export interface WorkQueueItem { jobId: string; priority: number; }
export interface PriorityItem { id: string; title: string; note: string; status: "Done" | "Open"; pill: string; tone: PillTone; }
export interface Kpi { id: string; label: string; value: string; sub: string; }
export interface FieldValue { label: string; value: string; }
export interface CheckItem { id?: string; title: string; note: string; done: boolean; pill?: string; tone?: PillTone; }
export interface TimelineAction { step: string; tone: PillTone; title: string; note: string; time: string; }
export interface PackageComparisonRow { item: string; package: string; takeoff: string; result: string; tone: PillTone; }

export interface TakeoffLineItem {
  id: string;
  poLineItem: string;
  uom: string;
  poQuantity: number;
  verifiedQuantity: number | null;
  communityPackageQuantity: number;
  tolerance: number;
  status: "Not Verified" | "Match" | "Variance";
  notes?: string;
}

export interface SiteVisitRecord {
  id: string;
  purpose: "Warranty Determination" | "Finished Job Determination" | "Proposal Scope";
  status: "Scheduled" | "In Progress" | "Complete" | "Returned";
  decision: "Warranty" | "Finished Job" | "Proposal Needed" | "Pending";
  checklist: CheckItem[];
  notes: string;
}

export interface HealthCheckRecord {
  id: string;
  dueTime: string;
  crew: string;
  foreman: string;
  status: "Green" | "Red" | "Awaiting Response";
  scopeRemainingPct: number;
  canFixTomorrow: boolean;
  notes: string;
}

export interface TakeoffData {
  statusPill: Pill;
  fields: FieldValue[];
  tasks: CheckItem[];
  packageComparison: PackageComparisonRow[];
  lineItems: TakeoffLineItem[];
  siteReadiness: CheckItem[];
  siteVisits: SiteVisitRecord[];
  matchStatus: "Not Checked" | "Validated" | "Variance";
}
export interface WorkOrderLine { line: string; planned: string; actual: string; goal: string; actualHours: string; status: string; }
export interface WorkOrderData { number: string; status: string; serviceAppointment: string; assignedResource: string; scheduledDate: string; routeSequence: string; territory: string; lineItems: WorkOrderLine[]; scheduleControls: FieldValue[]; healthChecks?: HealthCheckRecord[]; }
export interface AquaCheck { date: string; tech: string; status: string; tone: PillTone; issue: string; }
export interface AquaData { installTicket: string; tech: string; deviceInstalled: string; coverageVerified: string; inventoryRecorded: string; photos: string; checks: AquaCheck[]; gates: CheckItem[]; checkChecklist?: CheckItem[]; pickupChecklist?: CheckItem[]; }
export interface PhotoProof { category: string; caption: string; status: "complete" | "issue" | "add"; uri?: string; uploadedAt?: string; uploadedBy?: string; }
export interface QiCategory { category: string; score: number; finding: string; result: string; theme?: string; }
export interface QiData { overallScore: number | null; status: string; closeoutStatus: string; invoiceStatus: string; categories: QiCategory[]; dueWindow?: string; }
export interface ActivityEvent { id: string; at: string; by: string; message: string; type: "record-update" | "action" | "warning"; }

export interface JobRecord {
  id: string;
  queueTitle: string;
  queueSubtitle: string;
  queuePill: Pill;
  title: string;
  recordKicker: string;
  breadcrumbs: string[];
  meta: string[];
  stageIndex: number;
  stageLabels: string[];
  kpis: Kpi[];
  nextBestActions: TimelineAction[];
  ownership: FieldValue[];
  gateStatus: CheckItem[];
  takeoff: TakeoffData;
  workOrder: WorkOrderData;
  aqua: AquaData;
  photos: PhotoProof[];
  qi: QiData;
  invoicePreview: FieldValue[];
  activity: ActivityEvent[];
}

export interface WorkspaceForms {
  returnReasons: string[];
  returnOwners: string[];
  fjReasons: string[];
  rescheduleReasons: string[];
  aquaIssues: string[];
  aquaPriorities: string[];
  siteVisitPurposes?: string[];
}

export interface FieldManagerWorkspace {
  currentUser: CurrentUser;
  selectedJobId: string;
  workQueue: WorkQueueItem[];
  priorities: PriorityItem[];
  jobs: JobRecord[];
  forms: WorkspaceForms;
}

export interface ActionResult { ok: boolean; message: string; workspace: FieldManagerWorkspace; }
