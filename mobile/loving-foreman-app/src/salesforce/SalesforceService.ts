import { buildAddress, encodeSoql, endOfDayIso, startOfDayIso } from '@/salesforce/helpers';
import type {
  ChecklistGroup,
  MyDaySummary,
  PhotoRequirement,
  PhotoCategory,
  RipplingStatus,
  ServiceAppointmentDetail,
  ServiceAppointmentSummary,
  WorkOrderDetail,
  WorkOrderLineItem
} from '@/data/contracts';

export interface SalesforceSession {
  instanceUrl: string;
  accessToken: string;
}

interface QueryResponse<T> {
  records: T[];
}

interface ServiceResourceRecord {
  Id: string;
  Name: string;
  RelatedRecordId?: string | null;
  IsActive: boolean;
}

interface AssignedResourceRecord {
  Id: string;
  ServiceAppointmentId: string;
  ServiceResourceId: string;
}

interface ServiceAppointmentRecord {
  Id: string;
  AppointmentNumber?: string;
  Status?: string;
  ParentRecordId?: string;
  WorkTypeId?: string | null;
  SchedStartTime?: string | null;
  SchedEndTime?: string | null;
}

interface WorkOrderRecord {
  Id: string;
  WorkOrderNumber?: string;
  Subject?: string;
  Status?: string;
  WorkTypeId?: string | null;
  Description?: string | null;
  Job_Type__c?: string | null;
  Street?: string | null;
  City?: string | null;
  State?: string | null;
  PostalCode?: string | null;
  Lot_Number__c?: string | null;
  ServiceTerritoryId?: string | null;
  Account?: { Name?: string | null } | null;
  Community__r?: { Name?: string | null } | null;
  ServiceTerritory?: { Name?: string | null } | null;
}

interface WorkTypeRecord {
  Id: string;
  Name?: string;
  EstimatedDuration?: number | null;
  DurationType?: string | null;
}

interface WorkOrderLineItemRecord {
  Id: string;
  Description?: string | null;
  LineItemNumber?: string | null;
}

interface UserInfoResponse {
  user_id: string;
  organization_id: string;
  preferred_username: string;
}

interface DescribeResponse {
  fields: Array<{
    name: string;
    picklistValues?: Array<{ value: string; active: boolean }>;
  }>;
}

interface ScheduleIssueCreatePayload {
  Issue_Type__c: string;
  Severity__c: string;
  Status__c: string;
  Summary__c: string;
  Resolution_Notes__c: string;
  Market__c?: string;
  Standard_Work_Order__c?: string;
  Service_Appointment__c?: string;
}

interface FieldChecklistRecord {
  Id: string;
  Offline_Local_Id__c?: string | null;
}

interface FieldChecklistCreatePayload {
  Service_Appointment__c?: string;
  Work_Order__c?: string;
  Service_Resource__c?: string;
  Checklist_Type__c: string;
  Status__c: string;
  Offline_Local_Id__c: string;
  Started_At__c?: string;
  Completed_At__c?: string;
  Completed_By__c?: string;
  Notes__c?: string;
}

interface FieldChecklistItemCreatePayload {
  Field_Checklist__c: string;
  Item_Label__c: string;
  Status__c: string;
  Completed_By__c?: string;
  Completed_At__c?: string;
  Notes__c?: string;
  Offline_Local_Id__c: string;
  Sort_Order__c?: number;
}

interface FieldChecklistItemRecord {
  Id: string;
  Offline_Local_Id__c?: string | null;
}

export class SalesforceService {
  constructor(private readonly session: SalesforceSession) {}

  async getUserInfo(): Promise<UserInfoResponse> {
    return this.getAbsolute<UserInfoResponse>('https://login.salesforce.com/services/oauth2/userinfo');
  }

  async getActiveServiceResources(): Promise<ServiceResourceRecord[]> {
    const soql =
      "SELECT Id, Name, RelatedRecordId, IsActive FROM ServiceResource WHERE IsActive = true ORDER BY Name LIMIT 200";
    return this.query<ServiceResourceRecord>(soql);
  }

  async getServiceAppointmentStatusOptions(): Promise<string[]> {
    return this.describePicklist('ServiceAppointment', 'Status');
  }

  async getWorkOrderStatusOptions(): Promise<string[]> {
    return this.describePicklist('WorkOrder', 'Status');
  }

  async getMyDay(serviceResourceId: string, date: string): Promise<MyDaySummary> {
    const start = startOfDayIso(date);
    const end = endOfDayIso(date);
    const assigned = await this.query<AssignedResourceRecord>(
      `SELECT Id, ServiceAppointmentId, ServiceResourceId
       FROM AssignedResource
       WHERE ServiceResourceId = '${serviceResourceId}'
       AND ServiceAppointment.SchedStartTime >= ${start}
       AND ServiceAppointment.SchedStartTime < ${end}
       ORDER BY ServiceAppointment.SchedStartTime ASC`
    );

    const appointmentIds = assigned.map((row) => row.ServiceAppointmentId);
    if (appointmentIds.length === 0) {
      return {
        serviceAppointments: [],
        syncStatus: 'Synced',
        gpsStatus: { isStale: true },
        ripplingStatus: this.unavailableRippling(),
        weather: undefined
      };
    }

    const appointments = await this.query<ServiceAppointmentRecord>(
      `SELECT Id, AppointmentNumber, Status, ParentRecordId, WorkTypeId, SchedStartTime, SchedEndTime
       FROM ServiceAppointment
       WHERE Id IN (${appointmentIds.map((id) => `'${id}'`).join(',')})
       ORDER BY SchedStartTime ASC`
    );

    const workOrderIds = appointments.map((row) => row.ParentRecordId).filter(Boolean) as string[];
    const workOrders = workOrderIds.length
      ? await this.query<WorkOrderRecord>(
          `SELECT Id, WorkOrderNumber, Subject, Status, WorkTypeId, Description, Job_Type__c,
                  Street, City, State, PostalCode, Lot_Number__c, ServiceTerritoryId,
                  ServiceTerritory.Name, Account.Name, Community__r.Name
           FROM WorkOrder
           WHERE Id IN (${workOrderIds.map((id) => `'${id}'`).join(',')})`
        )
      : [];

    const workTypeIds = new Set<string>();
    for (const appt of appointments) {
      if (appt.WorkTypeId) workTypeIds.add(appt.WorkTypeId);
    }
    for (const workOrder of workOrders) {
      if (workOrder.WorkTypeId) workTypeIds.add(workOrder.WorkTypeId);
    }

    const workTypes = workTypeIds.size
      ? await this.query<WorkTypeRecord>(
          `SELECT Id, Name, EstimatedDuration, DurationType
           FROM WorkType
           WHERE Id IN (${Array.from(workTypeIds).map((id) => `'${id}'`).join(',')})`
        )
      : [];

    const workOrderById = new Map(workOrders.map((row) => [row.Id, row]));
    const workTypeById = new Map(workTypes.map((row) => [row.Id, row]));

    const serviceAppointments: ServiceAppointmentSummary[] = appointments.map((appt) => {
      const workOrder = appt.ParentRecordId ? workOrderById.get(appt.ParentRecordId) : undefined;
      const workType = (appt.WorkTypeId && workTypeById.get(appt.WorkTypeId))
        || (workOrder?.WorkTypeId ? workTypeById.get(workOrder.WorkTypeId) : undefined);
      const missingDataFlags: string[] = [];
      const addressLine = buildAddress([
        workOrder?.Street,
        workOrder?.City,
        workOrder?.State,
        workOrder?.PostalCode
      ]);

      if (!workOrder?.Lot_Number__c) missingDataFlags.push('Missing Lot');
      if (!workOrder?.Community__r?.Name) missingDataFlags.push('Missing Community');
      if (!addressLine) missingDataFlags.push('Missing Address');
      if (!workType?.Name) missingDataFlags.push('Missing Work Type');

      return {
        id: appt.Id,
        appointmentNumber: appt.AppointmentNumber ?? 'Missing Data',
        status: appt.Status ?? 'Missing Data',
        scheduledStart: appt.SchedStartTime ?? undefined,
        scheduledEnd: appt.SchedEndTime ?? undefined,
        workOrderId: workOrder?.Id ?? '',
        workTypeName: workType?.Name ?? undefined,
        builderName: workOrder?.Account?.Name ?? undefined,
        communityName: workOrder?.Community__r?.Name ?? undefined,
        lotName: workOrder?.Lot_Number__c ?? undefined,
        addressLine,
        marketId: workOrder?.ServiceTerritoryId ?? undefined,
        marketName: workOrder?.ServiceTerritory?.Name ?? undefined,
        crewName: undefined,
        goalHours:
          workType?.EstimatedDuration && workType.DurationType
            ? workType.DurationType === 'Hours'
              ? workType.EstimatedDuration
              : workType.EstimatedDuration / 60
            : undefined,
        missingDataFlags
      };
    });

    return {
      serviceAppointments,
      syncStatus: 'Synced',
      gpsStatus: { isStale: true },
      ripplingStatus: this.unavailableRippling()
    };
  }

  async getServiceAppointmentDetail(serviceAppointmentId: string): Promise<ServiceAppointmentDetail> {
    const appointments = await this.query<ServiceAppointmentRecord>(
      `SELECT Id, AppointmentNumber, Status, ParentRecordId, WorkTypeId, SchedStartTime, SchedEndTime
       FROM ServiceAppointment
       WHERE Id = '${serviceAppointmentId}'
       LIMIT 1`
    );
    const appointment = appointments[0];
    if (!appointment) {
      throw new Error(`ServiceAppointment ${serviceAppointmentId} not found.`);
    }

    const workOrder = appointment.ParentRecordId
      ? await this.getWorkOrderRecord(appointment.ParentRecordId)
      : undefined;
    const workOrderDetail = workOrder ? await this.getWorkOrderDetail(workOrder.Id, serviceAppointmentId) : undefined;
    const workTypeName = appointment.WorkTypeId
      ? await this.getWorkTypeName(appointment.WorkTypeId)
      : workOrderDetail?.workTypeName;

    const missingDataFlags = workOrderDetail?.missingDataFlags ? [...workOrderDetail.missingDataFlags] : [];
    if (!appointment.SchedStartTime) missingDataFlags.push('Missing Scheduled Start');

    return {
      id: appointment.Id,
      appointmentNumber: appointment.AppointmentNumber ?? 'Missing Data',
      status: appointment.Status ?? 'Missing Data',
      scheduledStart: appointment.SchedStartTime ?? undefined,
      scheduledEnd: appointment.SchedEndTime ?? undefined,
      workTypeName,
      workOrderId: workOrder?.Id,
      workOrderNumber: workOrder?.WorkOrderNumber,
      builderName: workOrder?.Account?.Name ?? undefined,
      communityName: workOrder?.Community__r?.Name ?? undefined,
      lotName: workOrder?.Lot_Number__c ?? undefined,
      marketId: workOrder?.ServiceTerritoryId ?? undefined,
      marketName: workOrder?.ServiceTerritory?.Name ?? undefined,
      addressLine: buildAddress([workOrder?.Street, workOrder?.City, workOrder?.State, workOrder?.PostalCode]),
      assignedResourceName: undefined,
      notes: workOrder?.Description ?? undefined,
      requiredPhotos: buildRequiredPhotos(workTypeName),
      checklistGroups: workOrderDetail?.checklistGroups ?? [],
      lineItems: workOrderDetail?.lineItems ?? [],
      missingDataFlags
    };
  }

  async getWorkOrderDetail(workOrderId: string, serviceAppointmentId?: string): Promise<WorkOrderDetail> {
    const workOrder = await this.getWorkOrderRecord(workOrderId);
    if (!workOrder) {
      throw new Error(`WorkOrder ${workOrderId} not found.`);
    }

    const lineItems = await this.query<WorkOrderLineItemRecord>(
      `SELECT Id, Description, LineItemNumber
       FROM WorkOrderLineItem
       WHERE WorkOrderId = '${workOrderId}'
       ORDER BY LineItemNumber ASC`
    );

    let resolvedWorkTypeId = workOrder.WorkTypeId ?? undefined;
    if (!resolvedWorkTypeId && serviceAppointmentId) {
      const serviceAppointments = await this.query<ServiceAppointmentRecord>(
        `SELECT Id, WorkTypeId FROM ServiceAppointment WHERE Id = '${serviceAppointmentId}' LIMIT 1`
      );
      resolvedWorkTypeId = serviceAppointments[0]?.WorkTypeId ?? undefined;
    }

    const workTypeName = resolvedWorkTypeId ? await this.getWorkTypeName(resolvedWorkTypeId) : undefined;
    const missingDataFlags: string[] = [];
    const addressLine = buildAddress([workOrder.Street, workOrder.City, workOrder.State, workOrder.PostalCode]);
    if (!addressLine) missingDataFlags.push('Missing Address');
    if (!workTypeName) missingDataFlags.push('Missing Work Type');
    if (lineItems.length === 0) missingDataFlags.push('Missing WorkOrderLineItem');

    return {
      id: workOrder.Id,
      workOrderNumber: workOrder.WorkOrderNumber ?? 'Missing Data',
      subject: workOrder.Subject ?? undefined,
      status: workOrder.Status ?? 'Missing Data',
      workTypeName,
      jobType: workOrder.Job_Type__c ?? undefined,
      communityName: workOrder.Community__r?.Name ?? undefined,
      builderName: workOrder.Account?.Name ?? undefined,
      lotName: workOrder.Lot_Number__c ?? undefined,
      addressLine,
      notes: workOrder.Description ?? undefined,
      lineItems: lineItems.map((line): WorkOrderLineItem => ({
        id: line.Id,
        description: line.Description ?? line.LineItemNumber ?? 'Missing Data',
        status: 'Not Started'
      })),
      checklistGroups: buildVehicleChecklistTemplate(),
      photoRequirements: buildRequiredPhotos(workTypeName),
      serviceAppointmentId,
      marketId: workOrder.ServiceTerritoryId ?? undefined,
      marketName: workOrder.ServiceTerritory?.Name ?? undefined,
      missingDataFlags
    };
  }

  async updateServiceAppointmentStatus(serviceAppointmentId: string, newStatus: string): Promise<void> {
    await this.patchSObject('ServiceAppointment', serviceAppointmentId, { Status: newStatus });
  }

  async createTask(subject: string, description: string, whatId?: string): Promise<string> {
    return this.createSObject('Task', {
      Subject: subject,
      Description: description,
      Status: 'Not Started',
      WhatId: whatId
    });
  }

  async createScheduleIssue(payload: ScheduleIssueCreatePayload): Promise<string> {
    return this.createSObject('Schedule_Issue__c', payload as unknown as Record<string, unknown>);
  }

  async ensureFieldChecklist(payload: FieldChecklistCreatePayload): Promise<string> {
    const existing = await this.query<FieldChecklistRecord>(
      `SELECT Id, Offline_Local_Id__c
       FROM Field_Checklist__c
       WHERE Offline_Local_Id__c = '${payload.Offline_Local_Id__c}'
       LIMIT 1`
    );
    if (existing[0]?.Id) {
      return existing[0].Id;
    }
    return this.createSObject('Field_Checklist__c', payload as unknown as Record<string, unknown>);
  }

  async ensureFieldChecklistItem(payload: FieldChecklistItemCreatePayload): Promise<string> {
    const existing = await this.query<FieldChecklistItemRecord>(
      `SELECT Id, Offline_Local_Id__c
       FROM Field_Checklist_Item__c
       WHERE Offline_Local_Id__c = '${payload.Offline_Local_Id__c}'
       LIMIT 1`
    );
    if (existing[0]?.Id) {
      return existing[0].Id;
    }
    return this.createSObject('Field_Checklist_Item__c', payload as unknown as Record<string, unknown>);
  }

  async uploadPhotoFromBase64(
    title: string,
    base64: string,
    linkedEntityId: string,
    pathOnClient = 'photo.jpg'
  ): Promise<string> {
    return this.createSObject('ContentVersion', {
      Title: title,
      PathOnClient: pathOnClient,
      VersionData: base64,
      FirstPublishLocationId: linkedEntityId
    });
  }

  private async getWorkTypeName(workTypeId: string): Promise<string | undefined> {
    const records = await this.query<WorkTypeRecord>(
      `SELECT Id, Name, EstimatedDuration, DurationType FROM WorkType WHERE Id = '${workTypeId}' LIMIT 1`
    );
    return records[0]?.Name ?? undefined;
  }

  private async getWorkOrderRecord(workOrderId: string): Promise<WorkOrderRecord | undefined> {
    const records = await this.query<WorkOrderRecord>(
      `SELECT Id, WorkOrderNumber, Subject, Status, WorkTypeId, Description, Job_Type__c,
              Street, City, State, PostalCode, Lot_Number__c, ServiceTerritoryId,
              ServiceTerritory.Name, Account.Name, Community__r.Name
       FROM WorkOrder
       WHERE Id = '${workOrderId}'
       LIMIT 1`
    );
    return records[0];
  }

  private async describePicklist(objectApiName: string, fieldApiName: string): Promise<string[]> {
    const describe = await this.get<DescribeResponse>(`/services/data/v66.0/sobjects/${objectApiName}/describe`);
    const field = describe.fields.find((row) => row.name === fieldApiName);
    return field?.picklistValues?.filter((row) => row.active).map((row) => row.value) ?? [];
  }

  private unavailableRippling(): RipplingStatus {
    return {
      clockStatus: 'Unknown',
      exceptionState: 'Rippling status unavailable. Time remains managed in Rippling.'
    };
  }

  private async query<T>(soql: string): Promise<T[]> {
    const response = await this.get<QueryResponse<T>>(`/services/data/v66.0/query?q=${encodeSoql(soql)}`);
    return response.records;
  }

  private async get<T>(path: string): Promise<T> {
    const response = await fetch(`${this.session.instanceUrl}${path}`, {
      headers: {
        Authorization: `Bearer ${this.session.accessToken}`
      }
    });
    if (!response.ok) {
      throw new Error(`${path} failed: ${response.status}`);
    }
    return (await response.json()) as T;
  }

  private async getAbsolute<T>(url: string): Promise<T> {
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${this.session.accessToken}`
      }
    });
    if (!response.ok) {
      throw new Error(`${url} failed: ${response.status}`);
    }
    return (await response.json()) as T;
  }

  private async createSObject(objectApiName: string, body: Record<string, unknown>): Promise<string> {
    const response = await fetch(`${this.session.instanceUrl}/services/data/v66.0/sobjects/${objectApiName}`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.session.accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      const message = await response.text();
      throw new Error(`Create ${objectApiName} failed: ${response.status} ${message}`);
    }
    const result = (await response.json()) as { id?: string };
    return result.id ?? '';
  }

  private async patchSObject(objectApiName: string, recordId: string, body: Record<string, unknown>): Promise<void> {
    const response = await fetch(
      `${this.session.instanceUrl}/services/data/v66.0/sobjects/${objectApiName}/${recordId}`,
      {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${this.session.accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      }
    );
    if (!response.ok) {
      const message = await response.text();
      throw new Error(`Update ${objectApiName} failed: ${response.status} ${message}`);
    }
  }
}

function buildRequiredPhotos(workTypeName?: string): PhotoRequirement[] {
  const base: PhotoRequirement[] = [
    { category: 'Before Front', required: true },
    { category: 'Before Back', required: true },
    { category: 'Before Side Left', required: true },
    { category: 'Before Side Right', required: true },
    { category: 'Final', required: true }
  ];

  if (workTypeName?.toLowerCase().includes('sod')) {
    base.push({ category: 'Sod Quality', required: true });
  }

  return base;
}

function buildVehicleChecklistTemplate(): ChecklistGroup[] {
  return [
    {
      id: 'vehicle-alpha',
      name: 'Vehicle Checklist',
      items: [
        { id: 'tires', label: 'Tires', required: true, status: 'Pending' },
        { id: 'lights', label: 'Lights', required: true, status: 'Pending' },
        { id: 'fluids', label: 'Fluids', required: true, status: 'Pending' },
        { id: 'fuel', label: 'Fuel Level', required: true, status: 'Pending' },
        { id: 'safety', label: 'Safety Equipment', required: true, status: 'Pending' }
      ]
    },
    {
      id: 'loaded-alpha',
      name: 'Loaded Checklist',
      items: [
        { id: 'loaded', label: 'Loaded Materials Verified', required: true, status: 'Pending' }
      ]
    }
  ];
}
