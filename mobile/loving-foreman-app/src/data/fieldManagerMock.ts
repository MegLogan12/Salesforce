import type { PhotoCategory } from '@/data/contracts';

export type FieldManagerAppointmentType =
  | 'Take-Offs'
  | 'Quality Inspection'
  | 'Site Readiness'
  | 'Customer Care'
  | 'Aqua Check-Work Order'
  | 'Aqua Pick-Up-Work Order';

export interface FieldManagerForeman {
  id: string;
  name: string;
  crewLabel: string;
  truckLabel: string;
  status: 'In Route' | 'On Site' | 'Needs Review';
  currentAddress: string;
  lastPing: string;
  nextStop: string;
  openIssues: number;
  healthCheckStatus: 'Green' | 'Yellow' | 'Red';
  healthCheckNote: string;
}

export interface FieldManagerMockAppointment {
  id: string;
  appointmentType: FieldManagerAppointmentType;
  title: string;
  status: 'Scheduled' | 'In Progress' | 'Needs Review' | 'Complete';
  scheduledWindow: string;
  builder: string;
  community: string;
  lot: string;
  address: string;
  market: string;
  foremanId: string;
  workOrderLabel?: string;
  notes: string;
  focusChecklist: string[];
  requiredPhotos: PhotoCategory[];
  closeoutDeliverables: string[];
}

export const fieldManagerForemen: FieldManagerForeman[] = [
  {
    id: 'foreman-mock-01',
    name: 'Crew Lead 04',
    crewLabel: 'Crew 04',
    truckLabel: 'Truck 204',
    status: 'On Site',
    currentAddress: '118 River Birch Lane, Asheville, NC',
    lastPing: '1 min ago',
    nextStop: 'Quality Inspection · Brook Hollow L-18',
    openIssues: 1,
    healthCheckStatus: 'Yellow',
    healthCheckNote: 'Running 25 minutes late after material unload.'
  },
  {
    id: 'foreman-mock-02',
    name: 'Crew Lead 07',
    crewLabel: 'Crew 07',
    truckLabel: 'Truck 217',
    status: 'In Route',
    currentAddress: '48 Summit Ridge Drive, Asheville, NC',
    lastPing: '3 min ago',
    nextStop: 'Site Readiness · Harbor North L-07',
    openIssues: 0,
    healthCheckStatus: 'Green',
    healthCheckNote: 'On pace for all scheduled visits.'
  },
  {
    id: 'foreman-mock-03',
    name: 'Crew Lead 11',
    crewLabel: 'Crew 11',
    truckLabel: 'Truck 233',
    status: 'Needs Review',
    currentAddress: '302 Fairview Park Road, Asheville, NC',
    lastPing: '7 min ago',
    nextStop: 'Customer Care · Meadow View L-02',
    openIssues: 2,
    healthCheckStatus: 'Red',
    healthCheckNote: 'Customer hold and access gate conflict need manager follow-up.'
  }
];

export const fieldManagerAppointments: FieldManagerMockAppointment[] = [
  {
    id: 'fm-appt-001',
    appointmentType: 'Take-Offs',
    title: 'Final Take-Off Confirmation',
    status: 'Scheduled',
    scheduledWindow: '8:00 AM - 9:00 AM',
    builder: 'Mock Builder North',
    community: 'Brook Hollow',
    lot: 'L-18',
    address: '118 River Birch Lane, Asheville, NC',
    market: 'Asheville',
    foremanId: 'foreman-mock-01',
    notes: 'Verify final dimensions before material release and confirm crew staging area.',
    focusChecklist: [
      'Confirm lot dimensions against plan set',
      'Verify access path for crew and equipment',
      'Confirm irrigation and hardscape conflicts',
      'Record any scope delta for scheduling'
    ],
    requiredPhotos: ['Before Front', 'Before Side Left', 'Before Side Right', 'Progress'],
    closeoutDeliverables: ['Take-off approved', 'Scope exceptions logged', 'Photos attached']
  },
  {
    id: 'fm-appt-002',
    appointmentType: 'Quality Inspection',
    title: 'Post-Install Quality Review',
    status: 'In Progress',
    scheduledWindow: '10:00 AM - 11:00 AM',
    builder: 'Mock Builder North',
    community: 'Brook Hollow',
    lot: 'L-22',
    address: '125 River Birch Lane, Asheville, NC',
    market: 'Asheville',
    foremanId: 'foreman-mock-01',
    notes: 'Review seams, grade transitions, cleanup, and irrigation exposure before closeout.',
    focusChecklist: [
      'Inspect edge finish and seam visibility',
      'Check grade transitions and drainage',
      'Review cleanup around curb and driveway',
      'Confirm final punch items with foreman'
    ],
    requiredPhotos: ['Before Front', 'Progress', 'Final', 'Safety'],
    closeoutDeliverables: ['Inspection pass/fail logged', 'Punch list routed', 'Final photos complete']
  },
  {
    id: 'fm-appt-003',
    appointmentType: 'Site Readiness',
    title: '48-Hour Site Readiness Review',
    status: 'Scheduled',
    scheduledWindow: '11:30 AM - 12:15 PM',
    builder: 'Mock Builder South',
    community: 'Harbor North',
    lot: 'L-07',
    address: '48 Summit Ridge Drive, Asheville, NC',
    market: 'Asheville',
    foremanId: 'foreman-mock-02',
    notes: 'Check access, grading, irrigation readiness, and material drop space for crew arrival.',
    focusChecklist: [
      'Confirm access gate and parking path',
      'Verify grade is finished and debris is cleared',
      'Confirm irrigation sleeves and utilities are flagged',
      'Validate material staging zone'
    ],
    requiredPhotos: ['Before Front', 'Before Back', 'Material', 'Safety'],
    closeoutDeliverables: ['Readiness status posted', 'Builder hold logged if needed', 'Photos attached']
  },
  {
    id: 'fm-appt-004',
    appointmentType: 'Customer Care',
    title: 'Customer Care Resolution Visit',
    status: 'Needs Review',
    scheduledWindow: '1:00 PM - 2:00 PM',
    builder: 'Mock Builder East',
    community: 'Meadow View',
    lot: 'L-02',
    address: '302 Fairview Park Road, Asheville, NC',
    market: 'Asheville',
    foremanId: 'foreman-mock-03',
    notes: 'Review customer concern, document root cause, and capture photos for service resolution.',
    focusChecklist: [
      'Confirm homeowner or builder concern details',
      'Inspect affected turf or irrigation area',
      'Capture corrective action plan',
      'Route any follow-up work order'
    ],
    requiredPhotos: ['Issue', 'Progress', 'Final'],
    closeoutDeliverables: ['Concern logged', 'Resolution path sent', 'Customer care photos complete']
  },
  {
    id: 'fm-appt-005',
    appointmentType: 'Aqua Check-Work Order',
    title: 'Aqua Check Verification',
    status: 'Scheduled',
    scheduledWindow: '2:30 PM - 3:15 PM',
    builder: 'Mock Builder West',
    community: 'Stone Creek',
    lot: 'L-14',
    address: '91 Stone Creek Drive, Asheville, NC',
    market: 'Asheville',
    foremanId: 'foreman-mock-02',
    workOrderLabel: 'Aqua Check WO-1048',
    notes: 'Verify valve layout, controller response, coverage notes, and handoff to scheduling.',
    focusChecklist: [
      'Run valve and controller check',
      'Confirm irrigation coverage and pressure observations',
      'Document any leaks or damaged heads',
      'Confirm next action on related work order'
    ],
    requiredPhotos: ['Progress', 'Material', 'Final'],
    closeoutDeliverables: ['Aqua check results logged', 'Related WO updated', 'Photos attached']
  },
  {
    id: 'fm-appt-006',
    appointmentType: 'Aqua Pick-Up-Work Order',
    title: 'Aqua Pick-Up Close Review',
    status: 'Scheduled',
    scheduledWindow: '3:30 PM - 4:15 PM',
    builder: 'Mock Builder West',
    community: 'Stone Creek',
    lot: 'L-19',
    address: '104 Stone Creek Drive, Asheville, NC',
    market: 'Asheville',
    foremanId: 'foreman-mock-03',
    workOrderLabel: 'Aqua Pick-Up WO-1052',
    notes: 'Verify removal list, pickup completion, site condition, and remaining follow-up scope.',
    focusChecklist: [
      'Confirm all pickup items are listed',
      'Inspect site after removal',
      'Capture any damage or scope carryover',
      'Close or re-route related work order'
    ],
    requiredPhotos: ['Issue', 'Material', 'Final'],
    closeoutDeliverables: ['Pickup confirmed', 'Exceptions logged', 'Final condition photos complete']
  }
];
