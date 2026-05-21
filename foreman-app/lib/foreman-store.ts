import { create } from 'zustand';
import type {
  ForemanState,
  ForemanDay,
  Scene,
  Lang,
  SfWorkOrder,
  SfServiceAppointment,
  SfChecklistItem,
  SfCrewMember,
  SfDeliveryQcResult,
  DeliveryQcVerdict,
  SfHousekeepingItem,
  SfInventoryReport,
  SfMeasurement,
} from './foreman-types';

const today = new Date();
const at = (h: number, m: number) => {
  const d = new Date(today);
  d.setHours(h, m, 0, 0);
  return d.toISOString();
};

const fieldManager = {
  id: 'fm_avery',
  name: 'Avery Solano',
  phone: '+1 (469) 555-0182',
  email: 'avery.solano@lovingoutdoor.com',
  region: 'North Dallas — Region 4',
};

const deliveries = [
  {
    id: 'dl_sod_1',
    product: 'Sod' as const,
    species: 'Bermuda 419',
    unit: 'pallets' as const,
    expectedQty: 62,
    vendor: 'King Ranch Turfgrass',
    poNumber: 'PO-78421',
    scheduledIso: at(7, 15),
  },
  {
    id: 'dl_mulch_1',
    product: 'Mulch' as const,
    unit: 'cu yd' as const,
    expectedQty: 12,
    vendor: 'Living Earth',
    poNumber: 'PO-78422',
    scheduledIso: at(7, 30),
  },
];

const wo: SfWorkOrder = {
  id: 'wo_0148',
  woNumber: 'WO-2026-0148',
  subject: 'Sundance Ridge · Lot 14B',
  workOrderType: 'Sod Install',
  subStatus: 'Pre-Install',
  sodSpecies: 'Bermuda 419',
  sodSqft: 12400,
  goalHours: 8,
  fieldManager,
  address: '3320 Sundance Ridge, Prosper TX',
  deliveries,
};

const sa: SfServiceAppointment = {
  id: 'sa_0148_1',
  parentWorkOrderId: wo.id,
  scheduledStartIso: at(7, 30),
  scheduledEndIso: at(15, 30),
  status: 'Scheduled',
  resourceName: 'J. Reyes',
};

const crew: SfCrewMember[] = [
  { id: 'c1', name: 'J. Reyes', status: 'Confirmed' },
  { id: 'c2', name: 'R. Valle', status: 'Confirmed' },
  { id: 'c3', name: 'E. Valentine', status: 'Confirmed' },
  { id: 'c4', name: 'C. Ortiz', status: 'Confirmed' },
];

const vehicleChecklist: SfChecklistItem[] = [
  { id: 'v1', label: 'Tires + lights', required: true, done: false, category: 'vehicle' },
  { id: 'v2', label: 'Fluids + fuel', required: true, done: false, category: 'vehicle' },
  { id: 'v3', label: 'Trailer hitch + safety chains', required: true, done: false, category: 'vehicle' },
  { id: 'v4', label: 'First aid + fire extinguisher', required: true, done: false, category: 'vehicle' },
];

const loadedChecklist: SfChecklistItem[] = [
  { id: 'l1', label: 'Sod pallets loaded (62 ct.)', required: true, done: false, category: 'loaded' },
  { id: 'l2', label: 'Fertilizer bags (8 ct.)', required: true, done: false, category: 'loaded' },
  { id: 'l3', label: 'Sod cutters + edgers', required: true, done: false, category: 'loaded' },
  { id: 'l4', label: 'Crew water + ice', required: true, done: false, category: 'loaded' },
];

const closeoutChecklist: SfChecklistItem[] = [
  { id: 'co1', label: 'Inventory reconciled', required: true, done: false, category: 'closeout' },
  { id: 'co2', label: 'Housekeeping complete', required: true, done: false, category: 'closeout' },
  { id: 'co3', label: 'Hero after photo taken', required: true, done: false, category: 'closeout' },
];

const directions = [
  { icon: '↑', instruction: 'Head south on Forestburg Dr', distance: '0.4 mi' },
  { icon: '↰', instruction: 'Turn left onto E Bethany Dr', distance: '1.2 mi' },
  { icon: '↱', instruction: 'Right onto Custer Pkwy', distance: '3.1 mi' },
  { icon: '📍', instruction: 'Arrive at 3320 Sundance Ridge, Prosper TX', distance: '0.5 mi' },
];

const housekeeping: SfHousekeepingItem[] = [
  { id: 'hk1', label: 'All debris / clippings bagged and removed', done: false, required: true },
  { id: 'hk2', label: 'Sidewalks + driveway blown clean', done: false, required: true },
  { id: 'hk3', label: 'Sod scraps off-site or in truck', done: false, required: true },
  { id: 'hk4', label: 'Tools secured in truck / trailer', done: false, required: true },
  { id: 'hk5', label: 'Gates re-latched / doors re-closed', done: false, required: true },
  { id: 'hk6', label: 'Sprinklers confirmed off', done: false, required: false },
  { id: 'hk7', label: 'Customer walkthrough completed', done: false, required: true },
];

const initialInventory: SfInventoryReport = {
  items: [
    { id: 'inv1', label: 'Sod pallets', unit: 'pallets', loaded: 62, used: null, returned: null },
    { id: 'inv2', label: 'Fertilizer bags', unit: 'bags', loaded: 8, used: null, returned: null },
    { id: 'inv3', label: 'Herbicide (pre-mix)', unit: 'gal', loaded: 4, used: null, returned: null },
    { id: 'inv4', label: 'Mulch', unit: 'cu yd', loaded: 12, used: null, returned: null },
  ],
  hasExcess: null,
  excessDetails: '',
  excessPhotoCaptured: false,
  hasMissing: null,
  missingDetails: '',
  submitted: false,
};

const seedDay: ForemanDay = {
  dateIso: today.toISOString(),
  foremanName: 'J. Reyes',
  depot: '2810 Forestburg Dr',
  crew,
  workOrders: [wo],
  serviceAppointments: [sa],
  vehicleChecklist,
  loadedChecklist,
  closeoutChecklist,
  housekeeping,
  directions,
  selectedWorkOrderId: wo.id,
  clockedInAt: at(6, 42),
  clockedOutAt: null,
  arrivedAt: null,
  jobStartedAt: null,
  lunchStartAt: null,
  photos: [],
  flag: { speciesDiscovered: '', extraSqft: null, submitted: false },
  deliveryQc: deliveries.map(d => ({
    deliveryLineId: d.id,
    verdict: 'pending' as DeliveryQcVerdict,
    verifiedQty: null,
    issueNote: '',
    locked: false,
  })),
  inventory: initialInventory,
  measurements: [],
};

export interface ForemanStore extends ForemanState {
  appendPinDigit: (d: string) => void;
  backspacePin: () => void;
  clearPin: () => void;
  submitPin: () => boolean;
  signOut: () => void;

  setLang: (l: Lang) => void;
  toggleLang: () => void;
  goScene: (s: Scene) => void;

  toggleChecklistItem: (cat: 'vehicle' | 'loaded' | 'closeout', id: string) => void;

  arrive: () => void;

  setDeliveryVerdict: (lineId: string, v: DeliveryQcVerdict) => void;
  setDeliveryVerifiedQty: (lineId: string, qty: number | null) => void;
  setDeliveryNote: (lineId: string, note: string) => void;
  captureDeliveryPhoto: (lineId: string) => void;
  submitDeliveryQc: (lineId: string) => { ok: boolean; locked: boolean; reason?: string };
  unlockDelivery: (lineId: string) => void;

  startJob: () => void;
  capturePhoto: (cat: import('./foreman-types').SfCapturedPhoto['category']) => void;

  goLunch: () => void;
  endLunch: () => void;

  setFlagSpecies: (s: string) => void;
  setFlagSqft: (n: number | null) => void;
  submitFlag: () => void;

  toggleHousekeeping: (id: string) => void;

  setInventoryUsed: (itemId: string, qty: number | null) => void;
  setInventoryReturned: (itemId: string, qty: number | null) => void;
  setHasExcess: (v: boolean) => void;
  setExcessDetails: (s: string) => void;
  captureExcessPhoto: () => void;
  setHasMissing: (v: boolean) => void;
  setMissingDetails: (s: string) => void;
  submitInventory: () => void;

  addMeasurement: () => void;
  updateMeasurement: (id: string, patch: Partial<SfMeasurement>) => void;
  removeMeasurement: (id: string) => void;

  submitCloseout: () => void;
  clockOut: () => void;

  selectedWorkOrder: () => SfWorkOrder | null;
  selectedSA: () => SfServiceAppointment | null;
  hasDeliveries: () => boolean;
  anyDeliveryLocked: () => boolean;
  allDeliveriesCleared: () => boolean;

  resetDay: () => void;
}

export const useForeman = create<ForemanStore>((set, get) => ({
  pinAuth: { expectedPin: '1421', foremanId: 'fm_jreyes', attemptsRemaining: 5, locked: false },
  pinEntered: '',
  authenticated: false,
  lang: 'en',
  scene: 'pin',
  day: seedDay,
  syncedAtIso: new Date().toISOString(),

  appendPinDigit: (d) =>
    set((s) => {
      if (s.pinAuth.locked || s.pinEntered.length >= s.pinAuth.expectedPin.length) return s;
      return { pinEntered: s.pinEntered + d };
    }),

  backspacePin: () => set((s) => ({ pinEntered: s.pinEntered.slice(0, -1) })),
  clearPin: () => set({ pinEntered: '' }),

  submitPin: () => {
    const s = get();
    if (s.pinAuth.locked) return false;
    if (s.pinEntered === s.pinAuth.expectedPin) {
      set({ authenticated: true, scene: 'login', pinEntered: '', pinAuth: { ...s.pinAuth, attemptsRemaining: 5 } });
      return true;
    }
    const remaining = s.pinAuth.attemptsRemaining - 1;
    set({ pinEntered: '', pinAuth: { ...s.pinAuth, attemptsRemaining: remaining, locked: remaining <= 0 } });
    return false;
  },

  signOut: () => set({ authenticated: false, scene: 'pin', pinEntered: '' }),

  setLang: (lang) => set({ lang }),
  toggleLang: () => set((s) => ({ lang: s.lang === 'en' ? 'es' : 'en' })),
  goScene: (scene) => set({ scene }),

  toggleChecklistItem: (cat, id) =>
    set((s) => {
      const key = cat === 'vehicle' ? 'vehicleChecklist' : cat === 'loaded' ? 'loadedChecklist' : 'closeoutChecklist';
      return { day: { ...s.day, [key]: s.day[key].map((i) => (i.id === id ? { ...i, done: !i.done } : i)) } };
    }),

  arrive: () =>
    set((s) => ({
      day: { ...s.day, arrivedAt: new Date().toISOString() },
      scene: 'arriving',
    })),

  setDeliveryVerdict: (lineId, verdict) =>
    set((s) => ({
      day: {
        ...s.day,
        deliveryQc: s.day.deliveryQc.map((r) => (r.deliveryLineId === lineId ? { ...r, verdict } : r)),
      },
    })),

  setDeliveryVerifiedQty: (lineId, qty) =>
    set((s) => ({
      day: {
        ...s.day,
        deliveryQc: s.day.deliveryQc.map((r) => (r.deliveryLineId === lineId ? { ...r, verifiedQty: qty } : r)),
      },
    })),

  setDeliveryNote: (lineId, issueNote) =>
    set((s) => ({
      day: {
        ...s.day,
        deliveryQc: s.day.deliveryQc.map((r) => (r.deliveryLineId === lineId ? { ...r, issueNote } : r)),
      },
    })),

  captureDeliveryPhoto: (lineId) => {
    const photoId = `ph_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    set((s) => ({
      day: {
        ...s.day,
        photos: [
          ...s.day.photos,
          { id: photoId, uri: '', category: 'delivery-qc', capturedAt: new Date().toISOString(), deliveryLineId: lineId },
        ],
        deliveryQc: s.day.deliveryQc.map((r) => (r.deliveryLineId === lineId ? { ...r, photoId } : r)),
      },
    }));
  },

  submitDeliveryQc: (lineId) => {
    const s = get();
    const result = s.day.deliveryQc.find((r) => r.deliveryLineId === lineId);
    if (!result) return { ok: false, locked: false, reason: 'no-result' };
    if (result.verdict === 'pending') return { ok: false, locked: false, reason: 'no-verdict' };
    if (!result.photoId) return { ok: false, locked: false, reason: 'no-photo' };
    if (result.verdict === 'red' && !result.issueNote.trim()) return { ok: false, locked: false, reason: 'no-note' };
    if (result.verifiedQty === null) return { ok: false, locked: false, reason: 'no-count' };
    const newLocked = result.verdict === 'red';
    set({
      day: {
        ...s.day,
        deliveryQc: s.day.deliveryQc.map((r) =>
          r.deliveryLineId === lineId ? { ...r, submittedAt: new Date().toISOString(), locked: newLocked } : r
        ),
        workOrders: s.day.workOrders.map((w) =>
          newLocked && w.id === s.day.selectedWorkOrderId ? { ...w, subStatus: 'On Hold' } : w
        ),
      },
    });
    return { ok: true, locked: newLocked };
  },

  unlockDelivery: (lineId) =>
    set((s) => ({
      day: {
        ...s.day,
        deliveryQc: s.day.deliveryQc.map((r) => (r.deliveryLineId === lineId ? { ...r, locked: false } : r)),
        workOrders: s.day.workOrders.map((w) =>
          w.id === s.day.selectedWorkOrderId ? { ...w, subStatus: 'Pre-Install' } : w
        ),
      },
    })),

  startJob: () =>
    set((s) => ({
      day: {
        ...s.day,
        jobStartedAt: new Date().toISOString(),
        workOrders: s.day.workOrders.map((w) =>
          w.id === s.day.selectedWorkOrderId ? { ...w, subStatus: 'In Progress' as const } : w
        ),
        serviceAppointments: s.day.serviceAppointments.map((a) =>
          a.parentWorkOrderId === s.day.selectedWorkOrderId ? { ...a, status: 'In Progress' as const } : a
        ),
      },
      scene: 'active',
    })),

  capturePhoto: (category) =>
    set((s) => ({
      day: {
        ...s.day,
        photos: [
          ...s.day.photos,
          {
            id: `ph_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
            uri: '',
            category,
            capturedAt: new Date().toISOString(),
          },
        ],
      },
    })),

  goLunch: () =>
    set((s) => ({
      day: {
        ...s.day,
        lunchStartAt: new Date().toISOString(),
        crew: s.day.crew.map((c) => ({ ...c, status: 'On Break' as const })),
      },
      scene: 'lunch',
    })),

  endLunch: () =>
    set((s) => ({
      day: {
        ...s.day,
        lunchStartAt: null,
        crew: s.day.crew.map((c) => ({ ...c, status: 'Clocked In' as const })),
      },
      scene: 'active',
    })),

  setFlagSpecies: (speciesDiscovered) =>
    set((s) => ({ day: { ...s.day, flag: { ...s.day.flag, speciesDiscovered } } })),
  setFlagSqft: (extraSqft) =>
    set((s) => ({ day: { ...s.day, flag: { ...s.day.flag, extraSqft } } })),
  submitFlag: () =>
    set((s) => ({ day: { ...s.day, flag: { ...s.day.flag, submitted: true } }, scene: 'active' })),

  toggleHousekeeping: (id) =>
    set((s) => ({
      day: { ...s.day, housekeeping: s.day.housekeeping.map((h) => (h.id === id ? { ...h, done: !h.done } : h)) },
    })),

  setInventoryUsed: (itemId, qty) =>
    set((s) => ({
      day: {
        ...s.day,
        inventory: {
          ...s.day.inventory,
          items: s.day.inventory.items.map((i) => (i.id === itemId ? { ...i, used: qty } : i)),
        },
      },
    })),

  setInventoryReturned: (itemId, qty) =>
    set((s) => ({
      day: {
        ...s.day,
        inventory: {
          ...s.day.inventory,
          items: s.day.inventory.items.map((i) => (i.id === itemId ? { ...i, returned: qty } : i)),
        },
      },
    })),

  setHasExcess: (v) =>
    set((s) => ({ day: { ...s.day, inventory: { ...s.day.inventory, hasExcess: v } } })),
  setExcessDetails: (s2) =>
    set((s) => ({ day: { ...s.day, inventory: { ...s.day.inventory, excessDetails: s2 } } })),
  captureExcessPhoto: () => {
    const photoId = `ph_excess_${Date.now()}`;
    set((s) => ({
      day: {
        ...s.day,
        inventory: { ...s.day.inventory, excessPhotoCaptured: true },
        photos: [...s.day.photos, { id: photoId, uri: '', category: 'excess', capturedAt: new Date().toISOString() }],
      },
    }));
  },
  setHasMissing: (v) =>
    set((s) => ({ day: { ...s.day, inventory: { ...s.day.inventory, hasMissing: v } } })),
  setMissingDetails: (s2) =>
    set((s) => ({ day: { ...s.day, inventory: { ...s.day.inventory, missingDetails: s2 } } })),
  submitInventory: () =>
    set((s) => ({ day: { ...s.day, inventory: { ...s.day.inventory, submitted: true } } })),

  addMeasurement: () =>
    set((s) => ({
      day: {
        ...s.day,
        measurements: [
          ...s.day.measurements,
          { id: `m_${Date.now()}`, label: '', lengthFt: null, widthFt: null, notes: '' },
        ],
      },
    })),

  updateMeasurement: (id, patch) =>
    set((s) => ({
      day: {
        ...s.day,
        measurements: s.day.measurements.map((m) => (m.id === id ? { ...m, ...patch } : m)),
      },
    })),

  removeMeasurement: (id) =>
    set((s) => ({
      day: { ...s.day, measurements: s.day.measurements.filter((m) => m.id !== id) },
    })),

  submitCloseout: () =>
    set((s) => ({
      day: {
        ...s.day,
        closeoutChecklist: s.day.closeoutChecklist.map((i) => ({ ...i, done: true })),
        workOrders: s.day.workOrders.map((w) =>
          w.id === s.day.selectedWorkOrderId ? { ...w, subStatus: 'Awaiting QI' as const } : w
        ),
        serviceAppointments: s.day.serviceAppointments.map((a) =>
          a.parentWorkOrderId === s.day.selectedWorkOrderId ? { ...a, status: 'Completed' as const } : a
        ),
      },
      scene: 'eod',
    })),

  clockOut: () =>
    set((s) => ({
      day: { ...s.day, clockedOutAt: new Date().toISOString() },
    })),

  selectedWorkOrder: () => {
    const s = get();
    return s.day.workOrders.find((w) => w.id === s.day.selectedWorkOrderId) ?? null;
  },
  selectedSA: () => {
    const s = get();
    return s.day.serviceAppointments.find((a) => a.parentWorkOrderId === s.day.selectedWorkOrderId) ?? null;
  },
  hasDeliveries: () => {
    const wo = get().selectedWorkOrder();
    return !!wo && wo.deliveries.length > 0;
  },
  anyDeliveryLocked: () => get().day.deliveryQc.some((r) => r.locked),
  allDeliveriesCleared: () => {
    const s = get();
    const wo = s.selectedWorkOrder();
    if (!wo || wo.deliveries.length === 0) return true;
    return wo.deliveries.every((d) => {
      const qc = s.day.deliveryQc.find((r) => r.deliveryLineId === d.id);
      return qc && !!qc.submittedAt && !qc.locked;
    });
  },

  resetDay: () =>
    set({
      day: seedDay,
      scene: 'pin',
      authenticated: false,
      pinEntered: '',
      pinAuth: { expectedPin: '1421', foremanId: 'fm_jreyes', attemptsRemaining: 5, locked: false },
    }),
}));
