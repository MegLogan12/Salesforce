// Live Salesforce API client for the Field Manager workspace.
// Uses direct SOQL + REST against the standard FSL objects and the LOVING
// custom objects deployed via LOVING_SF_ProductionInstall_v1.0.
//
// Object map (custom objects available in the org):
//   Finish_Job__c, QI_Inspection__c, QI_Line_Item__c,
//   Time_Entry__c, Aqua_Inventory__c, Schedule_Issue__c
//
// WorkOrder custom fields used here:
//   FM__c, Foreman__c, Goal_Hours__c, Actual_Hours__c,
//   QI_Status__c, QI_Score__c, QI_Submitted__c, QI_Date__c, QI_FM__c,
//   Takeoff_Status__c, Takeoff_Complete__c, Takeoff_Date__c, Takeoff_FM__c,
//   Takeoff_Sod_Sqft__c, Takeoff_Shrubs_1G__c, Takeoff_Shrubs_3G__c, Takeoff_Shrubs_7G__c,
//   Takeoff_Trees_15G__c, Takeoff_Trees_30G__c, Takeoff_Trees_45G__c,
//   Takeoff_Lighting_Units__c, Utilities_Cleared__c,
//   Health_Check_Status__c, Health_Check_Date__c,
//   Site_Readiness_Status__c, Site_Ready_Overall__c,
//   Closeout_Notes__c, Closeout_Photos_Attached__c,
//   Closeout_Quantities_Confirmed__c, Closeout_Submitted_Date__c,
//   Finish_Job_Required__c, Finish_Job_Reason__c, FJ_Count__c,
//   GP_Status__c, Revenue_Amount__c, Gross_Profit__c,
//   Work_Order_Type__c, Lot_Number__c, Lot_Address__c,
//   Community__c, Zone__c, Stop_Sequence__c, PO_Number__c

import type {
  FieldManagerWorkspace, JobRecord, PillTone, PhotoProof,
  Kpi, WorkOrderData, AquaData, QiData,
  FieldValue, CheckItem, HealthCheckRecord, WorkOrderLine as WOLine
} from "../types";
import type { SalesforceSession } from "./auth";

// ─── Internal Salesforce record shapes ───────────────────────────────────────

interface WorkOrderRecord {
  Id: string;
  WorkOrderNumber: string;
  Subject?: string | null;
  Status: string;
  Work_Order_Type__c?: string | null;
  FM__c?: string | null;
  Foreman__c?: string | null;
  Goal_Hours__c?: number | null;
  Actual_Hours__c?: number | null;
  QI_Status__c?: string | null;
  QI_Score__c?: number | null;
  QI_Submitted__c?: boolean | null;
  QI_Date__c?: string | null;
  QI_FM__c?: string | null;
  Takeoff_Status__c?: string | null;
  Takeoff_Complete__c?: boolean | null;
  Takeoff_Date__c?: string | null;
  Takeoff_FM__c?: string | null;
  Takeoff_Sod_Sqft__c?: number | null;
  Takeoff_Shrubs_1G__c?: number | null;
  Takeoff_Shrubs_3G__c?: number | null;
  Takeoff_Shrubs_7G__c?: number | null;
  Takeoff_Trees_15G__c?: number | null;
  Takeoff_Trees_30G__c?: number | null;
  Takeoff_Trees_45G__c?: number | null;
  Takeoff_Lighting_Units__c?: number | null;
  Utilities_Cleared__c?: boolean | null;
  Health_Check_Status__c?: string | null;
  Health_Check_Date__c?: string | null;
  Site_Readiness_Status__c?: string | null;
  Site_Ready_Overall__c?: boolean | null;
  Closeout_Notes__c?: string | null;
  Closeout_Photos_Attached__c?: boolean | null;
  Closeout_Quantities_Confirmed__c?: boolean | null;
  Closeout_Submitted_Date__c?: string | null;
  Finish_Job_Required__c?: boolean | null;
  Finish_Job_Reason__c?: string | null;
  FJ_Count__c?: number | null;
  GP_Status__c?: string | null;
  Revenue_Amount__c?: number | null;
  Gross_Profit__c?: number | null;
  Lot_Number__c?: string | null;
  Lot_Address__c?: string | null;
  Stop_Sequence__c?: number | null;
  PO_Number__c?: string | null;
  Street?: string | null;
  City?: string | null;
  State?: string | null;
  PostalCode?: string | null;
  ServiceTerritoryId?: string | null;
  Account?: { Id?: string; Name?: string; ParentId?: string; Parent?: { Name?: string } } | null;
  Community__r?: { Name?: string } | null;
  ServiceTerritory?: { Name?: string } | null;
}

interface ServiceAppointmentRecord {
  Id: string;
  AppointmentNumber?: string;
  Status?: string;
  SchedStartTime?: string | null;
  SchedEndTime?: string | null;
  AssignedResource?: { ServiceResource?: { Name?: string } } | null;
}

interface WorkOrderLineItemRecord {
  Id: string;
  LineItemNumber?: string | null;
  Description?: string | null;
  Quantity?: number | null;
  QuantityConsumed?: number | null;
  Duration?: number | null;
  DurationInMinutes?: number | null;
  Status?: string | null;
}

interface QiInspectionRecord {
  Id: string;
  Status__c?: string | null;
  Overall_Score__c?: number | null;
  FM_Notes__c?: string | null;
  Inspection_Date__c?: string | null;
  QI_Line_Items?: { records?: QiLineItemRecord[] };
}

interface QiLineItemRecord {
  Id: string;
  Category__c?: string | null;
  Score__c?: number | null;
  Finding__c?: string | null;
  Result__c?: string | null;
}

interface FinishJobRecord {
  Id: string;
  Status__c?: string | null;
  Reason__c?: string | null;
  Scope_Description__c?: string | null;
}

interface AquaInventoryRecord {
  Id: string;
  Status__c?: string | null;
  Tech_Name__c?: string | null;
  Device_Installed__c?: boolean | null;
  Coverage_Verified__c?: boolean | null;
  Inventory_Notes__c?: string | null;
  Photo_Proof__c?: boolean | null;
  Last_Check_Date__c?: string | null;
  Issue_Type__c?: string | null;
}

interface ContentDocumentLinkRecord {
  ContentDocument?: {
    Title?: string | null;
    ContentSize?: number | null;
    LatestPublishedVersion?: { VersionData?: string; Description?: string | null };
  };
}

interface SoqlResponse<T> {
  records: T[];
  totalSize: number;
  done: boolean;
  nextRecordsUrl?: string;
}

interface CreateResponse { id: string; success: boolean; errors: unknown[] }

// ─── Stage index mapping ──────────────────────────────────────────────────────

function stageIndexFromWoStatus(status: string): number {
  const map: Record<string, number> = {
    'New': 0, 'NFI': 0, 'PO Review': 0,
    'Takeoff Complete': 1,
    'Ready to Schedule': 2,
    'Scheduled': 3,
    'In Progress': 4, 'Field Complete': 4,
    'QI Review': 5, 'QI Pending': 5,
    'Pending Closeout': 6, 'Closeout': 6,
    'Invoiced': 7, 'Closed': 7, 'Approved': 6
  };
  return map[status] ?? 0;
}

function pillToneFromQiStatus(status: string | null | undefined): PillTone {
  if (!status) return 'gray';
  if (status === 'Passed') return 'green';
  if (status === 'Held' || status === 'Failed') return 'red';
  return 'amber';
}

function pillToneFromHealthStatus(status: string | null | undefined): PillTone {
  if (status === 'Green') return 'green';
  if (status === 'Red') return 'red';
  return 'amber';
}

function takeoffMeasurementsSummary(wo: WorkOrderRecord): string {
  const parts: string[] = [];
  if (wo.Takeoff_Sod_Sqft__c) parts.push(`Sod ${wo.Takeoff_Sod_Sqft__c.toLocaleString()} SF`);
  const trees = (wo.Takeoff_Trees_15G__c ?? 0) + (wo.Takeoff_Trees_30G__c ?? 0) + (wo.Takeoff_Trees_45G__c ?? 0);
  if (trees) parts.push(`${trees} trees`);
  const shrubs = (wo.Takeoff_Shrubs_1G__c ?? 0) + (wo.Takeoff_Shrubs_3G__c ?? 0) + (wo.Takeoff_Shrubs_7G__c ?? 0);
  if (shrubs) parts.push(`${shrubs} shrubs`);
  if (wo.Takeoff_Lighting_Units__c) parts.push(`${wo.Takeoff_Lighting_Units__c} lighting`);
  return parts.join(', ') || 'Not measured';
}

function buildAddress(wo: WorkOrderRecord): string {
  const parts = [wo.Street, wo.City, wo.State, wo.PostalCode].filter(Boolean);
  return parts.length ? parts.join(', ') : (wo.Lot_Address__c ?? '');
}

// ─── DTO builder ──────────────────────────────────────────────────────────────

function buildJobRecord(
  wo: WorkOrderRecord,
  sa: ServiceAppointmentRecord | undefined,
  lineItems: WorkOrderLineItemRecord[],
  qi: QiInspectionRecord | undefined,
  finishJobs: FinishJobRecord[],
  aqua: AquaInventoryRecord | undefined,
  photos: ContentDocumentLinkRecord[]
): JobRecord {
  const stageIndex = stageIndexFromWoStatus(wo.Status);
  const lotLabel = wo.Lot_Number__c ?? 'Unknown Lot';
  const community = wo.Community__r?.Name ?? 'Unknown Community';
  const parentName = wo.Account?.Parent?.Name ?? wo.Account?.Name ?? 'Unknown Builder';
  const divisionName = wo.Account?.Name ?? 'Unknown Division';
  const territory = wo.ServiceTerritory?.Name ?? wo.ServiceTerritoryId ?? '';
  const address = buildAddress(wo);

  const qiStatus = wo.QI_Status__c ?? (qi?.Status__c) ?? 'Not Ready';
  const qiScore = wo.QI_Score__c ?? qi?.Overall_Score__c ?? null;
  const healthStatus = wo.Health_Check_Status__c ?? 'Green';
  const takeoffStatus = wo.Takeoff_Status__c ?? (wo.Takeoff_Complete__c ? 'Complete' : 'Pending');
  const siteReadinessStatus = wo.Site_Ready_Overall__c ? 'Ready' : (wo.Site_Readiness_Status__c ?? 'Not Checked');
  const photoCount = photos.filter(p => p.ContentDocument?.Title).length;
  const fjCount = finishJobs.length;

  const kpis: Kpi[] = [
    {
      id: 'health', label: 'Job Health',
      value: healthStatus,
      sub: healthStatus === 'Green' ? 'On track' : healthStatus === 'Red' ? 'Needs FM action' : 'Review needed'
    },
    {
      id: 'takeoff', label: 'Takeoff Match',
      value: takeoffStatus,
      sub: 'PO, field verified, and package comparison'
    },
    {
      id: 'siteReadiness', label: 'Site Readiness',
      value: siteReadinessStatus,
      sub: '48-hour pre-start checklist'
    },
    {
      id: 'photos', label: 'Photo Gate',
      value: photoCount > 0 ? `${photoCount} uploaded` : 'No photos',
      sub: photoCount >= 6 ? 'Required categories received' : 'Review required'
    },
    {
      id: 'hours', label: 'Goal vs Actual',
      value: `${wo.Goal_Hours__c ?? 0} / ${wo.Actual_Hours__c ?? 0}`,
      sub: wo.Actual_Hours__c && wo.Goal_Hours__c
        ? ((wo.Actual_Hours__c - wo.Goal_Hours__c) > 0 ? '+' : '') + (wo.Actual_Hours__c - wo.Goal_Hours__c).toFixed(1) + ' hrs'
        : 'Not recorded'
    },
    {
      id: 'aqua', label: 'Aqua',
      value: aqua ? (aqua.Device_Installed__c ? (aqua.Issue_Type__c ? 'Issue' : 'Active') : 'Pending') : 'N/A',
      sub: aqua?.Issue_Type__c ?? (aqua ? 'Install ticket' : 'Not included')
    },
    {
      id: 'qi', label: 'QI',
      value: qiScore ? qiScore.toString() : (qiStatus === 'Not Ready' ? 'Not Ready' : qiStatus),
      sub: qiStatus === 'Passed' ? 'FM review complete' : 'FM review required before closeout'
    },
    {
      id: 'invoice', label: 'Invoice',
      value: stageIndex >= 7 ? 'Created' : (qiStatus === 'Passed' && !fjCount ? 'Ready' : 'Blocked'),
      sub: stageIndex >= 7 ? `Invoice to ${divisionName}` : 'Waits for FM closeout approval'
    }
  ];

  const takeoffFields: FieldValue[] = [
    { label: 'Takeoff Status', value: takeoffStatus },
    { label: '811 Utility Mark', value: wo.Utilities_Cleared__c ? 'Complete' : 'Pending' },
    { label: 'Site Readiness', value: siteReadinessStatus },
    { label: 'Measurements', value: takeoffMeasurementsSummary(wo) },
    { label: 'Photos', value: photoCount ? `${photoCount} photos received` : 'None received' },
    { label: 'Package Match', value: takeoffStatus === 'Complete' || wo.Takeoff_Complete__c ? 'Validated' : 'Pending CSM review' },
    { label: 'PO Number', value: wo.PO_Number__c ?? 'Not set' }
  ];

  const takeoffTasks: CheckItem[] = [
    {
      id: '811',
      title: 'Complete 811 Utility Call',
      note: 'Utility locate call completed and documented before scheduling',
      done: wo.Utilities_Cleared__c ?? false,
      pill: wo.Utilities_Cleared__c ? 'Done' : 'Open',
      tone: wo.Utilities_Cleared__c ? 'green' : 'amber'
    },
    {
      id: 'takeoff-measurements',
      title: 'Site measurements',
      note: 'Quantities entered',
      done: !!(wo.Takeoff_Sod_Sqft__c),
      pill: wo.Takeoff_Sod_Sqft__c ? 'Done' : 'Open',
      tone: wo.Takeoff_Sod_Sqft__c ? 'green' : 'amber'
    },
    {
      id: 'takeoff-photos',
      title: 'Takeoff photos',
      note: 'Site overview and measurement proof',
      done: photoCount >= 1,
      pill: photoCount >= 1 ? 'Done' : 'Open',
      tone: photoCount >= 1 ? 'green' : 'amber'
    }
  ];

  const siteReadiness: CheckItem[] = [
    {
      id: 'sr-grading', title: 'Grading complete',
      note: 'Lot is not rutted, too wet, blocked, or unsafe',
      done: wo.Site_Ready_Overall__c ?? false,
      pill: wo.Site_Ready_Overall__c ? 'Done' : 'Open',
      tone: wo.Site_Ready_Overall__c ? 'green' : 'amber'
    },
    {
      id: 'sr-access', title: 'Access and staging clear',
      note: 'Crew can access driveway, yard, and material staging area',
      done: wo.Site_Ready_Overall__c ?? false,
      pill: wo.Site_Ready_Overall__c ? 'Done' : 'Open',
      tone: wo.Site_Ready_Overall__c ? 'green' : 'amber'
    },
    {
      id: 'sr-utilities', title: 'Utilities marked and visible',
      note: '811 marks still visible before crew arrives',
      done: wo.Utilities_Cleared__c ?? false,
      pill: wo.Utilities_Cleared__c ? 'Done' : 'Open',
      tone: wo.Utilities_Cleared__c ? 'green' : 'amber'
    },
    {
      id: 'sr-builder', title: 'Builder conflicts checked',
      note: 'No active trades blocking landscape install',
      done: wo.Site_Ready_Overall__c ?? false,
      pill: wo.Site_Ready_Overall__c ? 'Done' : 'Open',
      tone: wo.Site_Ready_Overall__c ? 'green' : 'amber'
    }
  ];

  const gateStatus: CheckItem[] = [
    { title: 'PO reviewed', note: 'CSM approved package match', done: stageIndex >= 1, pill: stageIndex >= 1 ? 'Done' : 'Open', tone: stageIndex >= 1 ? 'green' : 'amber' },
    { title: 'Takeoff complete', note: '811, measurements, photos', done: wo.Takeoff_Complete__c ?? stageIndex >= 2, pill: (wo.Takeoff_Complete__c ?? stageIndex >= 2) ? 'Done' : 'Open', tone: (wo.Takeoff_Complete__c ?? stageIndex >= 2) ? 'green' : 'amber' },
    { title: 'Field complete', note: 'Foreman submitted closeout', done: stageIndex >= 4, pill: stageIndex >= 4 ? 'Done' : 'Locked', tone: stageIndex >= 4 ? 'green' : 'gray' },
    { title: 'FM QI approval', note: 'Required before invoice', done: qiStatus === 'Passed', pill: qiStatus === 'Passed' ? 'Done' : (qiStatus === 'Held' ? 'Held' : 'Open'), tone: qiStatus === 'Passed' ? 'green' : (qiStatus === 'Held' ? 'red' : 'amber') }
  ];

  const healthChecks: HealthCheckRecord[] = [{
    id: `hc-${wo.Id}`,
    dueTime: '2:00 PM',
    crew: sa?.AssignedResource?.ServiceResource?.Name ?? 'Assigned Crew',
    foreman: wo.Foreman__c ?? 'Assigned Foreman',
    status: (healthStatus as 'Green' | 'Red' | 'Awaiting Response'),
    scopeRemainingPct: wo.Actual_Hours__c && wo.Goal_Hours__c
      ? Math.max(0, Math.round((1 - wo.Actual_Hours__c / wo.Goal_Hours__c) * 100))
      : 0,
    canFixTomorrow: fjCount > 0,
    notes: wo.Health_Check_Date__c ? `Health check recorded ${wo.Health_Check_Date__c}` : 'No health check submitted yet'
  }];

  const workOrderLines: WOLine[] = lineItems.map(li => ({
    line: li.Description ?? li.LineItemNumber ?? 'Line item',
    planned: li.Quantity ? `${li.Quantity.toLocaleString()} EA` : '–',
    actual: li.QuantityConsumed ? `${li.QuantityConsumed.toLocaleString()} EA` : '0',
    goal: li.Duration ? (li.Duration / 60).toFixed(1) : (li.DurationInMinutes ? (li.DurationInMinutes / 60).toFixed(1) : '–'),
    actualHours: '–',
    status: li.Status ?? 'Open'
  }));

  const workOrderData: WorkOrderData = {
    number: wo.WorkOrderNumber,
    status: wo.Status,
    serviceAppointment: sa ? `${sa.AppointmentNumber ?? 'SA'}, ${sa.Status ?? 'Scheduled'}` : 'Not created',
    assignedResource: sa?.AssignedResource?.ServiceResource?.Name ?? 'Unassigned',
    scheduledDate: sa?.SchedStartTime ? new Date(sa.SchedStartTime).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }) : 'Not scheduled',
    routeSequence: wo.Stop_Sequence__c ? `Stop ${wo.Stop_Sequence__c}` : 'None',
    territory,
    lineItems: workOrderLines,
    scheduleControls: [
      { label: 'PO Number', value: wo.PO_Number__c ?? 'Not set' },
      { label: 'Site Ready', value: siteReadinessStatus },
      { label: 'Goal Hours', value: `${wo.Goal_Hours__c ?? 0} hr` },
      { label: 'Territory', value: territory }
    ],
    healthChecks
  };

  const qiCategories = qi?.QI_Line_Items?.records?.map(item => ({
    category: item.Category__c ?? 'Category',
    score: item.Score__c ?? 0,
    finding: item.Finding__c ?? '',
    result: item.Result__c ?? (item.Score__c && item.Score__c >= 7 ? 'Pass' : 'Hold'),
    theme: item.Category__c ?? ''
  })) ?? [];

  const qiData: QiData = {
    overallScore: qiScore,
    status: qiStatus === 'Passed' ? 'Passed' : qiStatus === 'Held' ? 'Held' : (qi ? qi.Status__c ?? 'Pending' : 'Not Ready'),
    closeoutStatus: qiStatus === 'Passed' ? 'Ready' : 'Waiting',
    invoiceStatus: stageIndex >= 7 ? 'Ready' : 'Locked',
    categories: qiCategories,
    dueWindow: '24-48 hours after Foreman marks Field Complete'
  };

  const aquaData: AquaData = aqua ? {
    installTicket: `AIT-${aqua.Id.slice(-6)}`,
    tech: aqua.Tech_Name__c ?? 'Unassigned',
    deviceInstalled: aqua.Device_Installed__c ? 'Yes' : 'No',
    coverageVerified: aqua.Coverage_Verified__c ? 'Yes' : 'No',
    inventoryRecorded: aqua.Inventory_Notes__c ?? 'No',
    photos: aqua.Photo_Proof__c ? 'Received' : 'None',
    checks: aqua.Last_Check_Date__c ? [{
      date: aqua.Last_Check_Date__c,
      tech: aqua.Tech_Name__c ?? 'Tech',
      status: aqua.Issue_Type__c ? 'Same-Day Repair' : 'Scheduled',
      tone: aqua.Issue_Type__c ? 'red' : 'blue',
      issue: aqua.Issue_Type__c ?? 'None'
    }] : [],
    gates: [
      { title: 'Device installed', note: 'Controller and timer installed', done: aqua.Device_Installed__c ?? false },
      { title: 'Coverage verified', note: 'All zones observed', done: aqua.Coverage_Verified__c ?? false },
      { title: 'Inventory recorded', note: 'On-site inventory assigned to lot', done: !!(aqua.Inventory_Notes__c) },
      { title: 'Photos complete', note: 'Controller, water source, system running', done: aqua.Photo_Proof__c ?? false }
    ],
    checkChecklist: [],
    pickupChecklist: []
  } : {
    installTicket: 'N/A', tech: 'N/A', deviceInstalled: 'N/A',
    coverageVerified: 'N/A', inventoryRecorded: 'N/A', photos: 'N/A',
    checks: [], gates: [], checkChecklist: [], pickupChecklist: []
  };

  const builtPhotos: PhotoProof[] = photos
    .filter(p => p.ContentDocument?.Title)
    .map(p => ({
      category: p.ContentDocument?.Title ?? 'Photo',
      caption: p.ContentDocument?.LatestPublishedVersion?.Description ?? 'Uploaded',
      status: 'complete' as const
    }));
  builtPhotos.push({ category: 'Add Photo', caption: 'Upload or mobile camera', status: 'add' });

  const invoicePreview: FieldValue[] = [
    { label: 'Bill To', value: divisionName },
    { label: 'Parent', value: `${parentName} roll-up only` },
    { label: 'Revenue', value: wo.Revenue_Amount__c ? `$${wo.Revenue_Amount__c.toLocaleString()}` : 'TBD' },
    { label: 'GP Status', value: wo.GP_Status__c ?? (wo.Gross_Profit__c ? 'Green' : 'N/A') }
  ];

  const stageLabels = ['PO Reviewed', 'Takeoff Complete', 'Ready to Schedule', 'Scheduled', 'Field Complete', 'QI Review', 'Closeout', 'Invoice'];

  return {
    id: wo.Id,
    queueTitle: `${lotLabel}, ${community}`,
    queueSubtitle: `${wo.Work_Order_Type__c ?? 'Production Install'}, ${wo.Status}`,
    queuePill: {
      label: qiStatus === 'Passed' ? 'Ready' : (wo.Finish_Job_Required__c ? 'FJ Required' : (wo.QI_Status__c === 'Held' ? 'QI Held' : 'In Progress')),
      tone: qiStatus === 'Passed' ? 'green' : (wo.QI_Status__c === 'Held' ? 'red' : 'aqua')
    },
    title: `${lotLabel}, ${community} | ${wo.Work_Order_Type__c ?? 'Production Install'}`,
    recordKicker: 'Field Manager Execution View',
    breadcrumbs: [
      `Parent: ${parentName}`,
      `Division: ${divisionName}`,
      `Community: ${community}`,
      `Lot: ${lotLabel}`,
      `WorkOrder: ${wo.WorkOrderNumber}`
    ],
    meta: [
      address,
      `Package: ${community} Standard`,
      `FM: ${wo.FM__c ?? 'Unassigned'}`,
      `Foreman: ${wo.Foreman__c ?? 'Unassigned'}`,
      `Service Territory: ${territory}`
    ],
    stageIndex,
    stageLabels,
    kpis,
    nextBestActions: buildNextBestActions(wo, qiStatus, fjCount, stageIndex),
    ownership: [
      { label: 'Parent', value: `${parentName}, roll-up only` },
      { label: 'Division', value: `${divisionName}, BMG and services` },
      { label: 'Community', value: `${community}, packages and service rules` },
      { label: 'Lot', value: `${lotLabel}, execution history` },
      { label: 'Work Execution', value: 'Standard WorkOrder and Field Service' },
      { label: 'Billing', value: `Invoice to ${divisionName}` }
    ],
    gateStatus,
    takeoff: {
      statusPill: {
        label: takeoffStatus,
        tone: (wo.Takeoff_Complete__c ? 'green' : (wo.Takeoff_Status__c === 'NFI' ? 'amber' : 'gray'))
      },
      fields: takeoffFields,
      tasks: takeoffTasks,
      packageComparison: [],
      lineItems: [],
      siteReadiness,
      siteVisits: [],
      matchStatus: wo.Takeoff_Complete__c ? 'Validated' : 'Not Checked'
    },
    workOrder: workOrderData,
    aqua: aquaData,
    photos: builtPhotos,
    qi: qiData,
    invoicePreview,
    activity: []
  };
}

function buildNextBestActions(wo: WorkOrderRecord, qiStatus: string, fjCount: number, stageIndex: number) {
  if (wo.Finish_Job_Required__c && fjCount === 0) {
    return [{ step: '1', tone: 'red' as PillTone, title: 'Create Finished Job', note: `Reason: ${wo.Finish_Job_Reason__c ?? 'Scope incomplete'}`, time: 'Now' }];
  }
  if (stageIndex === 5 && qiStatus !== 'Passed') {
    return [
      { step: '1', tone: 'aqua' as PillTone, title: 'Complete QI scoring', note: 'Score sod install, plant install, cleanup, site condition, and Aqua if applicable.', time: '7 min' },
      { step: '2', tone: 'gray' as PillTone, title: 'Approve closeout or create Finished Job', note: 'If all gates pass, approve closeout. If not, create a child Finished Job.', time: 'Decision' }
    ];
  }
  if (qiStatus === 'Passed' && stageIndex < 7) {
    return [{ step: '1', tone: 'green' as PillTone, title: 'Approve closeout', note: 'All gates are complete and QI has passed.', time: 'Now' }];
  }
  return [{ step: '1', tone: 'gray' as PillTone, title: 'Review record', note: `WorkOrder is ${wo.Status}`, time: '–' }];
}

// ─── SalesforceFieldManagerApi ────────────────────────────────────────────────

export class SalesforceFieldManagerApi {
  readonly instanceUrl: string;
  private readonly accessToken: string;
  private readonly userId: string;

  constructor(session: SalesforceSession) {
    this.instanceUrl = session.instanceUrl;
    this.accessToken = session.accessToken;
    this.userId = session.userId;
  }

  // ─── Workspace loader ──────────────────────────────────────────────────────

  async loadWorkspace(): Promise<FieldManagerWorkspace> {
    const workOrders = await this.queryWorkOrders();
    if (!workOrders.length) {
      return this.emptyWorkspace();
    }
    const jobs = await Promise.all(workOrders.map(wo => this.buildJobForWorkOrder(wo)));
    const workspace: FieldManagerWorkspace = {
      currentUser: { id: this.userId, name: 'Field Manager', role: 'Field Manager' },
      selectedJobId: jobs[0]?.id ?? '',
      workQueue: jobs.map((j, i) => ({ jobId: j.id, priority: i + 1 })),
      priorities: [],
      jobs,
      forms: {
        returnReasons: ['Missing required photo', 'Scope incomplete', 'Closeout notes incomplete', 'QI issue', 'Aqua issue'],
        returnOwners: ['Foreman', 'Aqua Tech', 'CSM', 'Scheduler'],
        fjReasons: ['Incomplete Scope', 'QI Red', 'Missing Material', 'Cleanup Required'],
        rescheduleReasons: ['Site Not Ready', 'Weather Hold', 'Access Issue', 'Material Issue', 'Builder Request'],
        aquaIssues: ['Dry Spot', 'Broken Head', 'Timer Issue', 'Device Missing', 'Runoff'],
        aquaPriorities: ['Same-Day', 'Next Route', 'Monitor'],
        siteVisitPurposes: ['Warranty Determination', 'Finished Job Determination', 'Proposal Scope']
      }
    };
    return workspace;
  }

  private async queryWorkOrders(): Promise<WorkOrderRecord[]> {
    const soql = `
      SELECT Id, WorkOrderNumber, Subject, Status, Work_Order_Type__c,
             FM__c, Foreman__c, Goal_Hours__c, Actual_Hours__c,
             QI_Status__c, QI_Score__c, QI_Submitted__c, QI_Date__c, QI_FM__c,
             Takeoff_Status__c, Takeoff_Complete__c, Takeoff_Date__c, Takeoff_FM__c,
             Takeoff_Sod_Sqft__c, Takeoff_Shrubs_1G__c, Takeoff_Shrubs_3G__c,
             Takeoff_Shrubs_7G__c, Takeoff_Trees_15G__c, Takeoff_Trees_30G__c,
             Takeoff_Trees_45G__c, Takeoff_Lighting_Units__c, Utilities_Cleared__c,
             Health_Check_Status__c, Health_Check_Date__c,
             Site_Readiness_Status__c, Site_Ready_Overall__c,
             Closeout_Notes__c, Closeout_Photos_Attached__c,
             Closeout_Quantities_Confirmed__c, Closeout_Submitted_Date__c,
             Finish_Job_Required__c, Finish_Job_Reason__c, FJ_Count__c,
             GP_Status__c, Revenue_Amount__c, Gross_Profit__c,
             Lot_Number__c, Lot_Address__c, Stop_Sequence__c, PO_Number__c,
             Street, City, State, PostalCode, ServiceTerritoryId,
             Account.Id, Account.Name, Account.ParentId, Account.Parent.Name,
             Community__r.Name, ServiceTerritory.Name
      FROM WorkOrder
      WHERE FM__c = '${this.userId}'
        AND Status NOT IN ('Cancelled', 'Invoiced', 'Closed')
      ORDER BY Stop_Sequence__c ASC NULLS LAST, CreatedDate DESC
      LIMIT 50
    `.trim().replace(/\s+/g, ' ');
    return this.query<WorkOrderRecord>(soql);
  }

  private async buildJobForWorkOrder(wo: WorkOrderRecord): Promise<JobRecord> {
    const [sa, lineItems, qi, finishJobs, aqua, photos] = await Promise.all([
      this.queryLatestServiceAppointment(wo.Id),
      this.queryLineItems(wo.Id),
      this.queryQiInspection(wo.Id),
      this.queryFinishJobs(wo.Id),
      this.queryAquaInventory(wo.Id),
      this.queryPhotos(wo.Id)
    ]);
    return buildJobRecord(wo, sa, lineItems, qi, finishJobs, aqua, photos);
  }

  private async queryLatestServiceAppointment(workOrderId: string): Promise<ServiceAppointmentRecord | undefined> {
    const results = await this.query<ServiceAppointmentRecord>(
      `SELECT Id, AppointmentNumber, Status, SchedStartTime, SchedEndTime,
              AssignedResource.ServiceResource.Name
       FROM ServiceAppointment
       WHERE ParentRecordId = '${workOrderId}'
       ORDER BY SchedStartTime DESC NULLS LAST
       LIMIT 1`
    );
    return results[0];
  }

  private async queryLineItems(workOrderId: string): Promise<WorkOrderLineItemRecord[]> {
    return this.query<WorkOrderLineItemRecord>(
      `SELECT Id, LineItemNumber, Description, Quantity, QuantityConsumed, Duration, DurationInMinutes, Status
       FROM WorkOrderLineItem
       WHERE WorkOrderId = '${workOrderId}'
       ORDER BY LineItemNumber ASC NULLS LAST`
    );
  }

  private async queryQiInspection(workOrderId: string): Promise<QiInspectionRecord | undefined> {
    const results = await this.query<QiInspectionRecord>(
      `SELECT Id, Status__c, Overall_Score__c, FM_Notes__c, Inspection_Date__c,
              (SELECT Id, Category__c, Score__c, Finding__c, Result__c FROM QI_Line_Items__r)
       FROM QI_Inspection__c
       WHERE Work_Order__c = '${workOrderId}'
       ORDER BY CreatedDate DESC
       LIMIT 1`
    );
    return results[0];
  }

  private async queryFinishJobs(workOrderId: string): Promise<FinishJobRecord[]> {
    return this.query<FinishJobRecord>(
      `SELECT Id, Status__c, Reason__c, Scope_Description__c
       FROM Finish_Job__c
       WHERE Parent_Work_Order__c = '${workOrderId}'
       ORDER BY CreatedDate DESC`
    );
  }

  private async queryAquaInventory(workOrderId: string): Promise<AquaInventoryRecord | undefined> {
    const results = await this.query<AquaInventoryRecord>(
      `SELECT Id, Status__c, Tech_Name__c, Device_Installed__c, Coverage_Verified__c,
              Inventory_Notes__c, Photo_Proof__c, Last_Check_Date__c, Issue_Type__c
       FROM Aqua_Inventory__c
       WHERE Work_Order__c = '${workOrderId}'
       ORDER BY CreatedDate DESC
       LIMIT 1`
    );
    return results[0];
  }

  private async queryPhotos(workOrderId: string): Promise<ContentDocumentLinkRecord[]> {
    return this.query<ContentDocumentLinkRecord>(
      `SELECT ContentDocument.Title, ContentDocument.ContentSize,
              ContentDocument.LatestPublishedVersion.Description
       FROM ContentDocumentLink
       WHERE LinkedEntityId = '${workOrderId}'
       ORDER BY SystemModstamp DESC
       LIMIT 20`
    );
  }

  private emptyWorkspace(): FieldManagerWorkspace {
    return {
      currentUser: { id: this.userId, name: 'Field Manager', role: 'Field Manager' },
      selectedJobId: '',
      workQueue: [],
      priorities: [{ id: 'no-work', title: 'No active WorkOrders found', note: `WorkOrders with FM__c = ${this.userId} and Status ≠ Closed/Invoiced/Cancelled`, status: 'Open', pill: 'Check Setup', tone: 'amber' }],
      jobs: [],
      forms: {
        returnReasons: [], returnOwners: [], fjReasons: [],
        rescheduleReasons: [], aquaIssues: [], aquaPriorities: []
      }
    };
  }

  // ─── Domain action writes ──────────────────────────────────────────────────

  async validateTakeoff(workOrderId: string): Promise<{ id: string }> {
    await this.patch('WorkOrder', workOrderId, {
      Takeoff_Status__c: 'Complete',
      Takeoff_Complete__c: true,
      Takeoff_Date__c: new Date().toISOString().slice(0, 10),
      Status: 'Ready to Schedule'
    });
    return { id: workOrderId };
  }

  async submitQI(workOrderId: string, scores: Record<string, number>, notes: string): Promise<{ id: string; qiId: string }> {
    const avg = Object.values(scores).length
      ? Number((Object.values(scores).reduce((s, v) => s + v, 0) / Object.values(scores).length).toFixed(1))
      : 0;
    const passed = avg >= 7;
    // Create QI_Inspection__c
    const qiId = await this.create('QI_Inspection__c', {
      Work_Order__c: workOrderId,
      Status__c: passed ? 'Passed' : 'Held',
      Overall_Score__c: avg,
      FM_Notes__c: notes,
      Inspection_Date__c: new Date().toISOString().slice(0, 10)
    });
    // Update WorkOrder QI fields
    await this.patch('WorkOrder', workOrderId, {
      QI_Status__c: passed ? 'Passed' : 'Held',
      QI_Score__c: avg,
      QI_Submitted__c: true,
      QI_Date__c: new Date().toISOString().slice(0, 10),
      Status: passed ? 'Pending Closeout' : 'QI Review'
    });
    return { id: workOrderId, qiId };
  }

  async createFinishJob(workOrderId: string, reason: string, scope: string): Promise<{ id: string; fjId: string }> {
    const fjId = await this.create('Finish_Job__c', {
      Parent_Work_Order__c: workOrderId,
      Reason__c: reason,
      Scope_Description__c: scope,
      Status__c: 'Open',
      Billing_Type__c: 'No Charge'
    });
    await this.patch('WorkOrder', workOrderId, {
      Finish_Job_Required__c: true,
      Finish_Job_Reason__c: reason
    });
    return { id: workOrderId, fjId };
  }

  async approveCloseout(workOrderId: string, notes: string): Promise<{ id: string }> {
    await this.patch('WorkOrder', workOrderId, {
      Status: 'Closed',
      Closeout_Notes__c: notes,
      Closeout_Quantities_Confirmed__c: true,
      Closeout_Photos_Attached__c: true,
      Closeout_Submitted_Date__c: new Date().toISOString().slice(0, 10),
      Approval_Date__c: new Date().toISOString().slice(0, 10)
    });
    return { id: workOrderId };
  }

  async dispatchAquaRepair(workOrderId: string, issueType: string, priority: string, tech: string, inventory: string, notes: string): Promise<{ id: string; issueId: string }> {
    const issueId = await this.create('Schedule_Issue__c', {
      Issue_Type__c: 'Aqua',
      Severity__c: priority === 'Same-Day' ? 'High' : 'Medium',
      Status__c: 'Open',
      Summary__c: `Aqua ${priority} repair: ${issueType}`,
      Resolution_Notes__c: `Tech: ${tech}. Inventory: ${inventory}. ${notes}`,
      Standard_Work_Order__c: workOrderId
    });
    await this.patch('WorkOrder', workOrderId, {
      Health_Check_Status__c: priority === 'Same-Day' ? 'Red' : 'Yellow'
    });
    return { id: workOrderId, issueId };
  }

  async returnWork(workOrderId: string, owner: string, reason: string, instructions: string): Promise<{ id: string; taskId: string }> {
    const taskId = await this.create('Task', {
      Subject: `Return to ${owner}: ${reason}`,
      Description: instructions,
      Status: 'Not Started',
      Priority: 'High',
      WhatId: workOrderId
    });
    await this.patch('WorkOrder', workOrderId, {
      Status: 'NFI',
      Need_Further_Info_Notes__c: `Returned to ${owner}: ${reason}. ${instructions}`
    });
    return { id: workOrderId, taskId };
  }

  async requestReschedule(workOrderId: string, reason: string, requestedDate: string, notes: string): Promise<{ id: string; taskId: string }> {
    const taskId = await this.create('Task', {
      Subject: `Reschedule request: ${reason}`,
      Description: `Requested date: ${requestedDate}. ${notes}`,
      Status: 'Not Started',
      Priority: 'Normal',
      WhatId: workOrderId
    });
    return { id: workOrderId, taskId };
  }

  async flagIssue(workOrderId: string, serviceAppointmentId: string, issueType: string, severity: string, summary: string, notes: string): Promise<{ issueId: string }> {
    const issueId = await this.create('Schedule_Issue__c', {
      Issue_Type__c: issueType,
      Severity__c: severity,
      Status__c: 'Open',
      Summary__c: summary,
      Resolution_Notes__c: notes,
      Standard_Work_Order__c: workOrderId,
      Service_Appointment__c: serviceAppointmentId || undefined
    });
    return { issueId };
  }

  async acceptPhotoPackage(workOrderId: string): Promise<{ id: string }> {
    await this.patch('WorkOrder', workOrderId, { Closeout_Photos_Attached__c: true });
    return { id: workOrderId };
  }

  async uploadPhoto(entityId: string, title: string, description: string, base64Data: string): Promise<{ contentVersionId: string }> {
    const contentVersionId = await this.create('ContentVersion', {
      Title: title,
      PathOnClient: `${title.replace(/\s+/g, '_')}.jpg`,
      VersionData: base64Data.replace(/^data:[^;]+;base64,/, ''),
      FirstPublishLocationId: entityId,
      Description: description
    });
    return { contentVersionId };
  }

  async submitHealthCheck(workOrderId: string, status: 'Green' | 'Red', scopePct: number, notes: string): Promise<{ id: string }> {
    await this.patch('WorkOrder', workOrderId, {
      Health_Check_Status__c: status,
      Health_Check_Date__c: new Date().toISOString().slice(0, 10),
      Red_Flag_Notes__c: status === 'Red' ? notes : null
    });
    return { id: workOrderId };
  }

  async updateTakeoffMeasurements(workOrderId: string, measurements: Partial<{
    sodSqft: number; shrubs1g: number; shrubs3g: number; shrubs7g: number;
    trees15g: number; trees30g: number; trees45g: number; lightingUnits: number;
  }>): Promise<{ id: string }> {
    const payload: Record<string, unknown> = {};
    if (measurements.sodSqft !== undefined) payload.Takeoff_Sod_Sqft__c = measurements.sodSqft;
    if (measurements.shrubs1g !== undefined) payload.Takeoff_Shrubs_1G__c = measurements.shrubs1g;
    if (measurements.shrubs3g !== undefined) payload.Takeoff_Shrubs_3G__c = measurements.shrubs3g;
    if (measurements.shrubs7g !== undefined) payload.Takeoff_Shrubs_7G__c = measurements.shrubs7g;
    if (measurements.trees15g !== undefined) payload.Takeoff_Trees_15G__c = measurements.trees15g;
    if (measurements.trees30g !== undefined) payload.Takeoff_Trees_30G__c = measurements.trees30g;
    if (measurements.trees45g !== undefined) payload.Takeoff_Trees_45G__c = measurements.trees45g;
    if (measurements.lightingUnits !== undefined) payload.Takeoff_Lighting_Units__c = measurements.lightingUnits;
    await this.patch('WorkOrder', workOrderId, payload);
    return { id: workOrderId };
  }

  async getUserDisplayName(): Promise<string> {
    const info = await this.get<{ name: string; preferred_username: string }>('/services/oauth2/userinfo');
    return info.name ?? info.preferred_username ?? 'Field Manager';
  }

  // ─── HTTP primitives ──────────────────────────────────────────────────────

  private async query<T>(soql: string): Promise<T[]> {
    const encoded = encodeURIComponent(soql);
    const response = await this.get<SoqlResponse<T>>(`/services/data/v62.0/query?q=${encoded}`);
    return response.records;
  }

  private async get<T>(path: string): Promise<T> {
    const response = await fetch(`${this.instanceUrl}${path}`, {
      headers: { Authorization: `Bearer ${this.accessToken}` }
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`BLOCKED: GET ${path} returned ${response.status}. OWNER: Salesforce org admin. ACTION REQUIRED: Check permissions for FM user on ${path}. Detail: ${text}`);
    }
    return response.json() as Promise<T>;
  }

  private async create(objectApiName: string, body: Record<string, unknown>): Promise<string> {
    const response = await fetch(`${this.instanceUrl}/services/data/v62.0/sobjects/${objectApiName}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`BLOCKED: Create ${objectApiName} failed ${response.status}. OWNER: Salesforce admin. ACTION REQUIRED: Grant LOVING_Field_Manager_App_User create permission on ${objectApiName}. Detail: ${text}`);
    }
    const result = await response.json() as CreateResponse;
    return result.id;
  }

  private async patch(objectApiName: string, recordId: string, body: Record<string, unknown>): Promise<void> {
    const response = await fetch(`${this.instanceUrl}/services/data/v62.0/sobjects/${objectApiName}/${recordId}`, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`BLOCKED: Update ${objectApiName}/${recordId} failed ${response.status}. OWNER: Salesforce admin. ACTION REQUIRED: Grant LOVING_Field_Manager_App_User edit permission on ${objectApiName} fields. Detail: ${text}`);
    }
  }
}
