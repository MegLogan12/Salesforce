import React, { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Linking,
  Pressable,
  SafeAreaView,
  ScrollView,
  Text,
  TextInput,
  View
} from 'react-native';
import NetInfo from '@react-native-community/netinfo';
import * as AuthSession from 'expo-auth-session';
import { StatusBar } from 'expo-status-bar';
import * as Location from 'expo-location';
import * as FileSystem from 'expo-file-system';
import {
  authRedirectUri,
  getAuthSessionState,
  getOAuthConfig,
  getOAuthDiscovery
} from '@/salesforce/session';
import { SalesforceService } from '@/salesforce/SalesforceService';
import {
  clearStoredAuthSession,
  loadStoredAuthSession,
  saveStoredAuthSession
} from '@/salesforce/authSessionStore';
import { AsyncQueueRepository } from '@/offline/AsyncQueueRepository';
import { stagePhoto } from '@/photos/stagePhoto';
import { loadSnapshot, saveSnapshot } from '@/core/storage';
import type { AppSnapshot, AuthSessionState, ResourceSelection, ScreenName } from '@/core/types';
import type {
  ChecklistItem,
  IssueDraft,
  PhotoCategory,
  ServiceAppointmentDetail,
  ServiceAppointmentSummary,
  WorkOrderDetail
} from '@/data/contracts';
import type { OfflineQueueItem } from '@/offline/types';

// ─── Design constants (matching HTML reference) ───────────────────────────────
const C = {
  navy: '#16325c',
  blue: '#0070d2',
  lightBlue: '#00a1e0',
  green: '#04844b',
  amber: '#fe9339',
  red: '#c23934',
  gray: '#54698d',
  bg: '#f3f3f3',
  white: '#ffffff',
  border: '#f0f0f0',
  borderMid: '#d8dde6',
  blueLight: '#e3f0fb',
  greenLight: '#e8f5e9',
  amberLight: '#fffbeb',
  redLight: '#fef9f9',
} as const;

const queueRepository = new AsyncQueueRepository();

const DEFAULT_SNAPSHOT: AppSnapshot = {
  language: 'en',
  currentRole: 'foreman',
  selectedDate: new Date().toISOString().slice(0, 10),
  queue: [],
  currentScreen: 'language'
};

const issueTypes: Array<IssueDraft['issueType']> = [
  'Site Not Ready',
  'Material Missing',
  'Material Damaged',
  'Sod Quality Issue',
  'Weather',
  'Traffic',
  'Access Blocked',
  'Scope Conflict',
  'Customer / Builder Hold',
  'Safety Issue',
  'Other'
];

const scheduleIssueTypeMap: Record<IssueDraft['issueType'], string> = {
  'Site Not Ready': 'Site Readiness',
  'Material Missing': 'Missing Material',
  'Material Damaged': 'Inventory',
  'Sod Quality Issue': 'Site Issue',
  Weather: 'Weather',
  Traffic: 'Traffic',
  'Access Blocked': 'Site Issue',
  'Scope Conflict': 'Other',
  'Customer / Builder Hold': 'Builder Restriction',
  'Safety Issue': 'Safety Hazard',
  Other: 'Other'
};

interface SyncItemResult {
  syncStatus?: OfflineQueueItem['syncStatus'];
  errorMessage?: string;
  conflictState?: string;
  payloadUpdates?: Record<string, unknown>;
}

// ─── Tab bar screens that show the tab bar ────────────────────────────────────
const TAB_SCREENS: ScreenName[] = [
  'myDay', 'serviceAppointmentDetail', 'workOrderDetail', 'preShiftChecks',
  'routeNavigation', 'arrival', 'activeJob', 'flagIssue', 'closeout',
  'syncQueue', 'settings'
];

function tabActive(screen: ScreenName): 'home' | 'schedule' | 'map' | 'active' | 'more' {
  if (screen === 'myDay') return 'home';
  if (screen === 'serviceAppointmentDetail' || screen === 'workOrderDetail') return 'schedule';
  if (screen === 'routeNavigation') return 'map';
  if (['arrival', 'activeJob', 'flagIssue', 'closeout', 'preShiftChecks'].includes(screen)) return 'active';
  return 'more';
}

export default function App() {
  const [snapshot, setSnapshot] = useState<AppSnapshot>(DEFAULT_SNAPSHOT);
  const [booting, setBooting] = useState(true);
  const [authState, setAuthState] = useState<AuthSessionState>(getAuthSessionState());
  const [networkOnline, setNetworkOnline] = useState(true);
  const [service, setService] = useState<SalesforceService | null>(null);
  const [resources, setResources] = useState<Array<{ id: string; name: string; relatedUserId?: string | null }>>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [myDay, setMyDay] = useState<ServiceAppointmentSummary[]>([]);
  const [appointmentDetail, setAppointmentDetail] = useState<ServiceAppointmentDetail | null>(null);
  const [workOrderDetail, setWorkOrderDetail] = useState<WorkOrderDetail | null>(null);
  const [noteText, setNoteText] = useState('');
  const [closeoutText, setCloseoutText] = useState('');
  const [issueDraft, setIssueDraft] = useState<IssueDraft>({
    issueType: 'Other',
    notes: '',
    impactedLineItemIds: [],
    photoQueueIds: []
  });
  const [availableSaStatuses, setAvailableSaStatuses] = useState<string[]>([]);
  const [availableWoStatuses, setAvailableWoStatuses] = useState<string[]>([]);

  const selectedResource = snapshot.selectedResource;
  const stagedPhotoCount = useMemo(
    () => snapshot.queue.filter((row) => row.actionType === 'PHOTO_UPLOAD').length,
    [snapshot.queue]
  );

  // ─── Boot ─────────────────────────────────────────────────────────────────
  useEffect(() => {
    let mounted = true;
    loadSnapshot()
      .then((saved) => { if (mounted && saved) setSnapshot(saved); })
      .then(async () => {
        const storedAuth = await loadStoredAuthSession();
        if (!mounted || !storedAuth) return;
        if (getAuthSessionState().mode !== 'debugToken') setAuthState(storedAuth);
      })
      .finally(() => { if (mounted) setBooting(false); });
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    if (!booting) void saveSnapshot(snapshot);
  }, [booting, snapshot]);

  useEffect(() => {
    const unsub = NetInfo.addEventListener((s) => setNetworkOnline(Boolean(s.isConnected)));
    return () => unsub();
  }, []);

  useEffect(() => {
    if (authState.instanceUrl && authState.accessToken) {
      setService(new SalesforceService({ instanceUrl: authState.instanceUrl, accessToken: authState.accessToken }));
    }
  }, [authState]);

  useEffect(() => {
    if (service) { void loadResources(); void loadStatusOptions(); }
  }, [service]);

  useEffect(() => {
    if (networkOnline) void syncQueue();
  }, [networkOnline]);

  const canUseAuth = authState.mode === 'debugToken' || authState.mode === 'oauth';

  // ─── Service calls ────────────────────────────────────────────────────────
  async function loadResources() {
    if (!service) return;
    try {
      const rows = await service.getActiveServiceResources();
      setResources(rows.map((r) => ({ id: r.Id, name: r.Name, relatedUserId: r.RelatedRecordId })));
    } catch (e) { setError(reduceError(e)); }
  }

  async function loadStatusOptions() {
    if (!service) return;
    try {
      const [sa, wo] = await Promise.all([
        service.getServiceAppointmentStatusOptions(),
        service.getWorkOrderStatusOptions()
      ]);
      setAvailableSaStatuses(sa);
      setAvailableWoStatuses(wo);
    } catch (e) { setError(reduceError(e)); }
  }

  async function doOAuth() {
    const config = getOAuthConfig();
    if (!config.clientId || !config.authUrl || !config.tokenUrl) {
      setAuthState(getAuthSessionState());
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const discovery = getOAuthDiscovery();
      const request = await AuthSession.loadAsync(
        { clientId: config.clientId, responseType: AuthSession.ResponseType.Code, redirectUri: config.redirectUri, scopes: config.scopes, usePKCE: true },
        discovery
      );
      const result = await request.promptAsync(discovery);
      if (result.type !== 'success' || !result.params.code) {
        throw new Error(`OAuth login did not complete. Result: ${result.type}`);
      }
      const tokenPayload = new URLSearchParams({
        grant_type: 'authorization_code',
        code: String(result.params.code),
        client_id: config.clientId,
        redirect_uri: config.redirectUri
      });
      if (request.codeVerifier) tokenPayload.set('code_verifier', request.codeVerifier);
      const tokenResponse = await fetch(config.tokenUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: tokenPayload.toString()
      });
      if (!tokenResponse.ok) throw new Error(`OAuth token exchange failed: ${tokenResponse.status} ${await tokenResponse.text()}`);
      const tokenJson = (await tokenResponse.json()) as { access_token?: string; instance_url?: string };
      if (!tokenJson.access_token || !tokenJson.instance_url) throw new Error('OAuth token response missing access_token or instance_url.');
      const nextAuth: AuthSessionState = { mode: 'oauth', accessToken: tokenJson.access_token, instanceUrl: tokenJson.instance_url };
      try {
        const origin = new URL(config.authUrl).origin;
        const ui = (await (await fetch(`${origin}/services/oauth2/userinfo`, { headers: { Authorization: `Bearer ${tokenJson.access_token}` } })).json()) as { preferred_username?: string; user_id?: string; organization_id?: string };
        nextAuth.username = ui.preferred_username;
        nextAuth.userId = ui.user_id;
        nextAuth.orgId = ui.organization_id;
      } catch { /* user info optional */ }
      await saveStoredAuthSession(nextAuth);
      setAuthState(nextAuth);
    } catch (e) { setError(reduceError(e)); }
    finally { setLoading(false); }
  }

  async function refreshMyDay() {
    if (!service || !selectedResource) { setError('Select a Service Resource first.'); return; }
    setLoading(true);
    setError(null);
    try {
      const summary = await service.getMyDay(selectedResource.serviceResourceId, snapshot.selectedDate);
      setMyDay(summary.serviceAppointments);
      setSnapshot((p) => ({ ...p, lastSyncAt: new Date().toISOString(), lastSyncStatus: 'Synced' }));
    } catch (e) { setError(reduceError(e)); }
    finally { setLoading(false); }
  }

  async function openAppointment(appointmentId: string) {
    if (!service) return;
    setLoading(true);
    setError(null);
    try {
      const detail = await service.getServiceAppointmentDetail(appointmentId);
      setAppointmentDetail(detail);
      setSnapshot((p) => ({ ...p, currentScreen: 'serviceAppointmentDetail', currentServiceAppointmentId: appointmentId, currentWorkOrderId: detail.workOrderId }));
    } catch (e) { setError(reduceError(e)); }
    finally { setLoading(false); }
  }

  async function openWorkOrder(workOrderId: string) {
    if (!service) return;
    setLoading(true);
    setError(null);
    try {
      const detail = await service.getWorkOrderDetail(workOrderId, snapshot.currentServiceAppointmentId);
      setWorkOrderDetail(detail);
      setSnapshot((p) => ({ ...p, currentScreen: 'workOrderDetail', currentWorkOrderId: workOrderId }));
    } catch (e) { setError(reduceError(e)); }
    finally { setLoading(false); }
  }

  async function queueChecklist(groupName: string, item: ChecklistItem, nextStatus: ChecklistItem['status'], sortOrder: number) {
    const qi = buildQueueItem({
      workOrderId: snapshot.currentWorkOrderId,
      serviceAppointmentId: snapshot.currentServiceAppointmentId,
      objectApiName: 'Field_Checklist_Item__c',
      actionType: 'CHECKLIST_UPDATE',
      payload: {
        checklistType: groupName,
        checklistOfflineLocalId: [snapshot.currentServiceAppointmentId ?? 'missing-sa', snapshot.currentWorkOrderId ?? 'missing-wo', groupName].join(':'),
        label: item.label,
        status: nextStatus,
        sortOrder
      }
    });
    await queueRepository.save(qi);
    await refreshQueueFromStorage();
  }

  async function queueNote(targetWorkOrderId?: string) {
    if (!noteText.trim()) { Alert.alert('Note required'); return; }
    await queueRepository.save(buildQueueItem({
      salesforceRecordId: targetWorkOrderId,
      objectApiName: 'Task',
      actionType: 'NOTE_SAVE',
      workOrderId: targetWorkOrderId,
      payload: { subject: 'Foreman Mobile Note', description: noteText }
    }));
    setNoteText('');
    await refreshQueueFromStorage();
  }

  async function queueIssue() {
    if (!issueDraft.notes.trim()) { Alert.alert('Issue notes are required'); return; }
    await queueRepository.save(buildQueueItem({
      objectApiName: 'Schedule_Issue__c',
      actionType: 'ISSUE_CREATE',
      serviceAppointmentId: snapshot.currentServiceAppointmentId,
      workOrderId: snapshot.currentWorkOrderId,
      payload: {
        issueType: issueDraft.issueType,
        notes: issueDraft.notes,
        impactedLineItemIds: issueDraft.impactedLineItemIds,
        photoQueueIds: issueDraft.photoQueueIds,
        marketId: workOrderDetail?.marketId ?? appointmentDetail?.marketId
      }
    }));
    setIssueDraft({ issueType: 'Other', notes: '', impactedLineItemIds: [], photoQueueIds: [] });
    await refreshQueueFromStorage();
  }

  async function queueCloseout(targetWorkOrderId?: string) {
    if (!closeoutText.trim()) { Alert.alert('Closeout note required'); return; }
    await queueRepository.save(buildQueueItem({
      objectApiName: 'Task',
      actionType: 'CLOSEOUT_NOTE',
      serviceAppointmentId: snapshot.currentServiceAppointmentId,
      workOrderId: targetWorkOrderId,
      payload: { subject: 'Closeout Note', description: closeoutText }
    }));
    setCloseoutText('');
    await refreshQueueFromStorage();
  }

  async function queueArrival(status: string) {
    const perm = await Location.requestForegroundPermissionsAsync();
    let lat: number | undefined, lng: number | undefined;
    if (perm.granted) {
      const loc = await Location.getCurrentPositionAsync({});
      lat = loc.coords.latitude;
      lng = loc.coords.longitude;
    }
    await queueRepository.save(buildQueueItem({
      salesforceRecordId: snapshot.currentServiceAppointmentId,
      objectApiName: 'ServiceAppointment',
      actionType: 'SA_STATUS_UPDATE',
      serviceAppointmentId: snapshot.currentServiceAppointmentId,
      workOrderId: snapshot.currentWorkOrderId,
      locationLatitude: lat,
      locationLongitude: lng,
      payload: { status }
    }));
    await refreshQueueFromStorage();
  }

  async function queuePhoto(category: PhotoCategory) {
    try {
      const staged = await stagePhoto(category);
      await queueRepository.save(buildQueueItem({
        objectApiName: 'ContentVersion',
        actionType: 'PHOTO_UPLOAD',
        salesforceRecordId: snapshot.currentWorkOrderId ?? snapshot.currentServiceAppointmentId,
        serviceAppointmentId: snapshot.currentServiceAppointmentId,
        workOrderId: snapshot.currentWorkOrderId,
        photoLocalUri: staged.localUri,
        payload: { title: `${category} ${new Date(staged.capturedAt).toISOString()}`, category }
      }));
      await refreshQueueFromStorage();
    } catch (e) { setError(reduceError(e)); }
  }

  async function refreshQueueFromStorage() {
    const queue = await queueRepository.listPending();
    setSnapshot((p) => ({ ...p, queue }));
  }

  async function syncQueue() {
    if (!service) return;
    const items = await queueRepository.listPending();
    for (const item of items) {
      if (item.syncStatus === 'Synced' || item.syncStatus === 'Syncing') continue;
      const syncing = { ...item, syncStatus: 'Syncing' as const, localUpdatedAt: new Date().toISOString() };
      await queueRepository.update(syncing);
      try {
        const outcome = await syncItem(syncing);
        await queueRepository.update({ ...syncing, payload: { ...syncing.payload, ...(outcome.payloadUpdates ?? {}) }, syncStatus: outcome.syncStatus ?? 'Synced', errorMessage: outcome.errorMessage, conflictState: outcome.conflictState, localUpdatedAt: new Date().toISOString() });
      } catch (e) {
        await queueRepository.update({ ...syncing, syncStatus: 'Failed', errorMessage: reduceError(e), retryCount: syncing.retryCount + 1, localUpdatedAt: new Date().toISOString() });
      }
    }
    await refreshQueueFromStorage();
    setSnapshot((p) => ({ ...p, lastSyncAt: new Date().toISOString(), lastSyncStatus: 'Synced' }));
  }

  async function syncItem(item: OfflineQueueItem): Promise<SyncItemResult> {
    if (!service) throw new Error('Salesforce service unavailable.');
    switch (item.actionType) {
      case 'NOTE_SAVE': {
        const taskId = await service.createTask(String(item.payload.subject ?? 'Foreman Mobile Note'), String(item.payload.description ?? ''), item.workOrderId);
        return { payloadUpdates: { syncedTaskId: taskId } };
      }
      case 'CLOSEOUT_NOTE': {
        const taskId = await service.createTask(String(item.payload.subject ?? 'Closeout Note'), String(item.payload.description ?? ''), item.workOrderId);
        return { payloadUpdates: { syncedTaskId: taskId } };
      }
      case 'ISSUE_CREATE': {
        if (!item.workOrderId) throw new Error('Missing WorkOrder id for issue sync.');
        if (!item.serviceAppointmentId) throw new Error('Missing ServiceAppointment id for issue sync.');
        const reqType = String(item.payload.issueType ?? 'Other') as IssueDraft['issueType'];
        const issueId = await service.createScheduleIssue({
          Issue_Type__c: scheduleIssueTypeMap[reqType] ?? 'Other',
          Severity__c: 'Medium',
          Status__c: 'Open',
          Summary__c: `${reqType}: ${String(item.payload.notes ?? '').slice(0, 120) || 'Submitted from LOVING Field App'}`,
          Resolution_Notes__c: [`Requested Issue Type: ${reqType}`, `Notes: ${String(item.payload.notes ?? '')}`, `Impacted Line Items: ${Array.isArray(item.payload.impactedLineItemIds) ? item.payload.impactedLineItemIds.join(', ') : ''}`].join('\n'),
          Market__c: typeof item.payload.marketId === 'string' ? item.payload.marketId : undefined,
          Standard_Work_Order__c: item.workOrderId,
          Service_Appointment__c: item.serviceAppointmentId
        });
        return { payloadUpdates: { scheduleIssueId: issueId } };
      }
      case 'PHOTO_UPLOAD': {
        if (!item.photoLocalUri) throw new Error('Missing staged photo URI.');
        if (!item.salesforceRecordId) throw new Error('Missing related Salesforce record for photo upload.');
        const base64 = await FileSystem.readAsStringAsync(item.photoLocalUri, { encoding: FileSystem.EncodingType.Base64 });
        const cvId = await service.uploadPhotoFromBase64(String(item.payload.title ?? 'Field Photo'), base64, item.salesforceRecordId);
        return { payloadUpdates: { contentVersionId: cvId } };
      }
      case 'SA_STATUS_UPDATE':
        if (!item.serviceAppointmentId) throw new Error('Missing ServiceAppointment id.');
        await service.updateServiceAppointmentStatus(item.serviceAppointmentId, String(item.payload.status ?? 'Scheduled'));
        return {};
      case 'CHECKLIST_UPDATE': {
        if (!item.workOrderId) throw new Error('Missing WorkOrder id for checklist sync.');
        if (!item.serviceAppointmentId) throw new Error('Missing ServiceAppointment id for checklist sync.');
        const checklistType = String(item.payload.checklistType ?? 'Active Job Checklist');
        const reqStatus = String(item.payload.status ?? 'Not Started');
        const parentStatus = reqStatus === 'Complete' ? 'Complete' : reqStatus === 'N/A' ? 'Needs Review' : 'In Progress';
        const checklistId = await service.ensureFieldChecklist({
          Service_Appointment__c: item.serviceAppointmentId,
          Work_Order__c: item.workOrderId,
          Service_Resource__c: item.serviceResourceId,
          Checklist_Type__c: checklistType,
          Status__c: parentStatus,
          Offline_Local_Id__c: String(item.payload.checklistOfflineLocalId ?? item.localId),
          Started_At__c: item.localCreatedAt,
          Completed_At__c: reqStatus === 'Complete' ? new Date().toISOString() : undefined,
          Completed_By__c: item.userId,
          Notes__c: String(item.payload.notes ?? '')
        });
        const checklistItemId = await service.ensureFieldChecklistItem({
          Field_Checklist__c: checklistId,
          Item_Label__c: String(item.payload.label ?? 'Checklist Item'),
          Status__c: reqStatus === 'Complete' ? 'Complete' : reqStatus === 'N/A' ? 'Needs Review' : 'Not Started',
          Completed_By__c: item.userId,
          Completed_At__c: reqStatus === 'Complete' ? new Date().toISOString() : undefined,
          Notes__c: String(item.payload.notes ?? ''),
          Offline_Local_Id__c: item.localId,
          Sort_Order__c: Number(item.payload.sortOrder ?? 0)
        });
        return { payloadUpdates: { fieldChecklistId: checklistId, fieldChecklistItemId: checklistItemId } };
      }
      default:
        throw new Error(`Unsupported queue action: ${item.actionType}`);
    }
  }

  function buildQueueItem(input: Partial<OfflineQueueItem> & Pick<OfflineQueueItem, 'objectApiName' | 'actionType' | 'payload'>): OfflineQueueItem {
    return {
      localId: `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      salesforceRecordId: input.salesforceRecordId,
      objectApiName: input.objectApiName,
      actionType: input.actionType,
      payload: input.payload,
      localCreatedAt: new Date().toISOString(),
      localUpdatedAt: new Date().toISOString(),
      userId: authState.userId ?? 'Missing Data',
      serviceResourceId: selectedResource?.serviceResourceId ?? 'Missing Data',
      serviceAppointmentId: input.serviceAppointmentId,
      workOrderId: input.workOrderId,
      locationLatitude: input.locationLatitude,
      locationLongitude: input.locationLongitude,
      photoLocalUri: input.photoLocalUri,
      retryCount: 0,
      syncStatus: 'Queued',
      errorMessage: undefined,
      conflictState: undefined
    };
  }

  async function logout() {
    await clearStoredAuthSession();
    const nextAuth = getAuthSessionState();
    setAuthState(nextAuth.mode === 'debugToken' ? nextAuth : { mode: 'blocked', blocker: 'Signed out. Authenticate with Salesforce to continue.' });
    setService(null);
    setResources([]);
    setMyDay([]);
    setAppointmentDetail(null);
    setWorkOrderDetail(null);
    setSnapshot((p) => ({ ...p, selectedResource: undefined, currentServiceAppointmentId: undefined, currentWorkOrderId: undefined, currentScreen: 'signIn' }));
  }

  function go(screen: ScreenName) {
    setSnapshot((p) => ({ ...p, currentScreen: screen }));
  }

  function getChecklistCompletion(detail: WorkOrderDetail) {
    const required = detail.checklistGroups.flatMap((g) => g.items.filter((i) => i.required));
    const doneIds = new Set(
      snapshot.queue
        .filter((r) => r.actionType === 'CHECKLIST_UPDATE' && r.workOrderId === detail.id && String(r.payload.status ?? '') === 'Complete')
        .map((r) => String(r.payload.checklistItemId ?? ''))
    );
    return {
      requiredCount: required.length,
      completedCount: required.filter((i) => doneIds.has(i.id)).length,
      ready: required.length > 0 && required.every((i) => doneIds.has(i.id))
    };
  }

  async function openMaps(addressLine?: string) {
    if (!addressLine) { setError('Missing Address'); return; }
    const encoded = encodeURIComponent(addressLine);
    const appleUrl = `http://maps.apple.com/?q=${encoded}`;
    const googleUrl = `comgooglemaps://?q=${encoded}`;
    const target = (await Linking.canOpenURL(googleUrl)) ? googleUrl : appleUrl;
    await Linking.openURL(target);
  }

  // ─── Render helpers ──────────────────────────────────────────────────────
  function renderFslHeader(opts: {
    title: string;
    sub?: string;
    bg?: string;
    onBack?: () => void;
    action?: string;
    onAction?: () => void;
  }) {
    const bg = opts.bg ?? C.navy;
    return (
      <View style={{ backgroundColor: bg, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 10, minHeight: 50 }}>
        <Pressable onPress={opts.onBack} style={{ width: 28 }}>
          {opts.onBack ? <Text style={{ color: C.white, fontSize: 22, fontWeight: '300' }}>‹</Text> : <View />}
        </Pressable>
        <View style={{ flex: 1, alignItems: 'center' }}>
          <Text style={{ color: C.white, fontSize: 14, fontWeight: '600' }}>{opts.title}</Text>
          {opts.sub ? <Text style={{ color: 'rgba(255,255,255,0.8)', fontSize: 10, marginTop: 1 }}>{opts.sub}</Text> : null}
        </View>
        <Pressable onPress={opts.onAction} style={{ width: 28, alignItems: 'flex-end' }}>
          {opts.action ? <Text style={{ color: C.white, fontSize: 12 }}>{opts.action}</Text> : <View />}
        </Pressable>
      </View>
    );
  }

  function renderTabBar(screen: ScreenName) {
    const tabs: Array<{ key: 'home' | 'schedule' | 'map' | 'active' | 'more'; icon: string; label: string; target: ScreenName }> = [
      { key: 'home', icon: '🏠', label: snapshot.language === 'es' ? 'Mi Día' : 'My Day', target: 'myDay' },
      { key: 'schedule', icon: '📅', label: snapshot.language === 'es' ? 'Horario' : 'Schedule', target: 'serviceAppointmentDetail' },
      { key: 'map', icon: '🗺', label: snapshot.language === 'es' ? 'Mapa' : 'Map', target: 'routeNavigation' },
      { key: 'active', icon: '📋', label: snapshot.language === 'es' ? 'Trabajo' : 'Active', target: 'activeJob' },
      { key: 'more', icon: '⋯', label: snapshot.language === 'es' ? 'Más' : 'More', target: 'settings' }
    ];
    const active = tabActive(screen);
    return (
      <View style={{ backgroundColor: C.white, borderTopWidth: 1, borderTopColor: '#e0e0e0', flexDirection: 'row', height: 56, paddingBottom: 8, paddingTop: 6 }}>
        {tabs.map((tab) => {
          const isOn = tab.key === active;
          return (
            <Pressable
              key={tab.key}
              onPress={() => {
                if (tab.key === 'schedule' && appointmentDetail) go('serviceAppointmentDetail');
                else if (tab.key === 'schedule') go('myDay');
                else if (tab.key === 'active' && workOrderDetail) go('activeJob');
                else if (tab.key === 'active') go('myDay');
                else go(tab.target);
              }}
              style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}
            >
              <Text style={{ fontSize: 18, color: isOn ? C.blue : C.gray }}>{tab.icon}</Text>
              <Text style={{ fontSize: 9, fontWeight: '500', color: isOn ? C.blue : C.gray, marginTop: 2 }}>{tab.label}</Text>
            </Pressable>
          );
        })}
      </View>
    );
  }

  function renderSyncBadge(variant: 'green' | 'amber' = 'green') {
    const bg = variant === 'green' ? '#e8f5e9' : '#fef3c7';
    const dot = variant === 'green' ? C.green : C.amber;
    const text = variant === 'green' ? C.green : '#92400e';
    const msg = variant === 'green'
      ? (snapshot.lastSyncAt ? `Synced · ${new Date(snapshot.lastSyncAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : 'Synced from Salesforce')
      : 'Offline · changes queued locally';
    return (
      <View style={{ flexDirection: 'row', alignItems: 'center', backgroundColor: bg, borderRadius: 6, paddingHorizontal: 10, paddingVertical: 6, marginBottom: 8, gap: 6 }}>
        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: dot }} />
        <Text style={{ fontSize: 10, color: text, fontWeight: '500', flex: 1 }}>{msg} · {networkOnline ? 'Online' : 'Offline'} · Queue {snapshot.queue.length}</Text>
      </View>
    );
  }

  function renderPCard(children: React.ReactNode, variant?: 'alert' | 'warn' | 'ok' | 'gate' | 'blue', extraStyle?: object) {
    const borders: Record<string, { borderColor: string; bg: string }> = {
      alert: { borderColor: C.red, bg: C.redLight },
      warn: { borderColor: C.amber, bg: C.amberLight },
      ok: { borderColor: C.green, bg: '#f8fdf9' },
      gate: { borderColor: C.amber, bg: C.amberLight },
      blue: { borderColor: C.blue, bg: '#f8faff' }
    };
    const v = variant ? borders[variant] : null;
    return (
      <View style={[
        { backgroundColor: v ? v.bg : C.white, borderRadius: 10, padding: 12, paddingHorizontal: 14, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1 },
        v ? { borderLeftWidth: 4, borderLeftColor: v.borderColor } : {},
        extraStyle
      ]}>
        {children}
      </View>
    );
  }

  function renderCardTitle(text: string, color?: string) {
    return <Text style={{ fontSize: 12, fontWeight: '600', color: color ?? C.navy, marginBottom: 6 }}>{text}</Text>;
  }

  function renderCardSub(text: string, color?: string) {
    return <Text style={{ fontSize: 11, color: color ?? C.gray, lineHeight: 16 }}>{text}</Text>;
  }

  function renderTimeCapture(rows: Array<[string, string, string?]>) {
    return (
      <View style={{ backgroundColor: '#f8fafc', borderWidth: 1, borderColor: C.blueLight, borderRadius: 8, padding: 10, paddingHorizontal: 12, marginBottom: 8 }}>
        {rows.map(([label, value, valueColor]) => (
          <View key={label} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 3 }}>
            <Text style={{ fontSize: 11, color: C.gray }}>{label}</Text>
            <Text style={{ fontSize: 11, color: valueColor ?? C.navy, fontWeight: '600', fontFamily: 'monospace' }}>{value}</Text>
          </View>
        ))}
      </View>
    );
  }

  function renderPChip(label: string, tone: 'green' | 'red' | 'blue' | 'amber' | 'gray' | 'purple' = 'gray') {
    const palette: Record<string, { bg: string; color: string }> = {
      green: { bg: C.greenLight, color: '#2e7d32' },
      red: { bg: C.redLight, color: '#991b1b' },
      blue: { bg: C.blueLight, color: '#0c447c' },
      amber: { bg: '#fef3c7', color: '#92400e' },
      gray: { bg: '#f4f6f9', color: C.gray },
      purple: { bg: '#ede9fe', color: '#5b21b6' }
    };
    const p = palette[tone];
    return (
      <View key={label} style={{ backgroundColor: p.bg, borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2, marginRight: 4, marginBottom: 4 }}>
        <Text style={{ fontSize: 10, fontWeight: '600', color: p.color }}>{label}</Text>
      </View>
    );
  }

  function renderProgressBar(pct: number, tone: 'green' | 'amber' | 'red' = 'green') {
    const colors = { green: C.green, amber: C.amber, red: C.red };
    return (
      <View style={{ height: 6, backgroundColor: '#e5e5e5', borderRadius: 3, overflow: 'hidden', marginVertical: 6 }}>
        <View style={{ width: `${Math.min(100, Math.max(0, pct))}%`, height: 6, backgroundColor: colors[tone], borderRadius: 3 }} />
      </View>
    );
  }

  function renderCheckItem(label: string, done: boolean, onPress?: () => void) {
    return (
      <Pressable
        key={label}
        onPress={onPress}
        style={{ flexDirection: 'row', alignItems: 'center', gap: 10, padding: 7, paddingHorizontal: 10, backgroundColor: done ? '#f8fdf9' : C.white, borderRadius: 6, marginBottom: 4, borderWidth: 1, borderColor: done ? '#a5d6a7' : C.border }}
      >
        <View style={{ width: 22, height: 22, borderRadius: 5, backgroundColor: done ? C.green : C.white, borderWidth: done ? 0 : 2, borderColor: C.borderMid, alignItems: 'center', justifyContent: 'center' }}>
          {done ? <Text style={{ color: C.white, fontSize: 13 }}>✓</Text> : null}
        </View>
        <Text style={{ fontSize: 11, color: done ? '#2e844a' : C.navy, flex: 1 }}>{label}</Text>
        {onPress && !done ? <Text style={{ fontSize: 11, color: C.blue, fontWeight: '600' }}>Tap to complete</Text> : null}
      </Pressable>
    );
  }

  function renderPhotoTile(label: string, icon: string, captured: boolean, onPress?: () => void) {
    return (
      <Pressable
        key={label}
        onPress={onPress}
        style={{ width: '48%', aspectRatio: 1, borderRadius: 8, backgroundColor: captured ? '#6ba84f' : '#e0e0e0', borderWidth: 2, borderStyle: captured ? 'solid' : 'dashed', borderColor: captured ? 'transparent' : '#b4b2a9', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 8 }}
      >
        <Text style={{ fontSize: 22 }}>{icon}</Text>
        <Text style={{ fontSize: 10, fontWeight: '600', color: captured ? C.white : C.gray }}>{label}</Text>
        {captured ? <View style={{ backgroundColor: 'rgba(0,0,0,0.5)', paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4 }}><Text style={{ fontSize: 9, color: C.white, fontWeight: '600' }}>CAPTURED</Text></View> : null}
      </Pressable>
    );
  }

  function renderSaCard(row: ServiceAppointmentSummary) {
    return (
      <View key={row.id} style={{ backgroundColor: C.white, borderRadius: 10, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1, overflow: 'hidden' }}>
        <View style={{ backgroundColor: C.navy, paddingHorizontal: 14, paddingVertical: 10, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Text style={{ color: C.white, fontSize: 11, fontWeight: '600' }}>{row.appointmentNumber}</Text>
          <View style={{ backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: 8, paddingHorizontal: 7, paddingVertical: 2 }}>
            <Text style={{ color: C.white, fontSize: 9, fontWeight: '600' }}>{row.status.toUpperCase()}</Text>
          </View>
        </View>
        <View style={{ padding: 12, paddingHorizontal: 14 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <Text style={{ fontSize: 14, fontWeight: '600', color: C.navy }}>{row.lotName ?? row.appointmentNumber}</Text>
            {row.workTypeName ? (
              <View style={{ backgroundColor: '#ede9fe', borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2 }}>
                <Text style={{ fontSize: 9, fontWeight: '600', color: '#5b21b6' }}>{row.workTypeName}</Text>
              </View>
            ) : null}
          </View>
          <Text style={{ fontSize: 11, color: C.gray, marginBottom: 8 }}>{row.addressLine ?? 'Missing address'} · {row.builderName ?? 'Missing builder'}</Text>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', borderTopWidth: 1, borderTopColor: C.border, paddingTop: 8 }}>
            <Text style={{ fontSize: 11, color: C.gray }}><Text style={{ color: C.navy, fontWeight: '600' }}>{row.scheduledStart ? new Date(row.scheduledStart).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'TBD'}</Text> start</Text>
            <Text style={{ fontSize: 11, color: C.gray }}><Text style={{ color: C.navy, fontWeight: '600' }}>{row.goalHours?.toFixed(1) ?? '–'} hr</Text> goal</Text>
            <Text style={{ fontSize: 11, color: C.gray }}>{row.marketName ?? '–'}</Text>
          </View>
          {row.missingDataFlags.length > 0 ? (
            <View style={{ marginTop: 6, flexDirection: 'row', flexWrap: 'wrap' }}>
              {row.missingDataFlags.map((f) => renderPChip(f, 'amber'))}
            </View>
          ) : null}
        </View>
        <View style={{ backgroundColor: C.blueLight, paddingHorizontal: 14, paddingVertical: 6, flexDirection: 'row', alignItems: 'center', gap: 6, borderTopWidth: 1, borderTopColor: '#b5d4f4' }}>
          <Text style={{ fontSize: 10, color: '#0c447c' }}>🚚 Tap to open this appointment</Text>
        </View>
        <Pressable onPress={() => void openAppointment(row.id)} style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }} />
      </View>
    );
  }

  function renderMissingFlags(flags: string[]) {
    if (flags.length === 0) return null;
    return renderPCard(
      <>
        {renderCardTitle('Missing Data', '#92400e')}
        {flags.map((f) => <Text key={f} style={{ fontSize: 11, color: '#92400e', lineHeight: 18 }}>{f}</Text>)}
      </>,
      'warn'
    );
  }

  // ─── Screens ─────────────────────────────────────────────────────────────
  if (booting) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg, alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator size="large" color={C.blue} />
      </SafeAreaView>
    );
  }

  const screen = snapshot.currentScreen;

  // Language screen — no standard header
  if (screen === 'language') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        <View style={{ backgroundColor: C.navy, paddingVertical: 18, paddingHorizontal: 14, alignItems: 'center' }}>
          <Text style={{ color: C.white, fontSize: 18, fontWeight: '700' }}>LOVING FSL</Text>
          <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 11, marginTop: 2 }}>Foreman · Field Service</Text>
        </View>
        <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 30 }}>
          <View style={{ alignItems: 'center', marginBottom: 30 }}>
            <Text style={{ fontSize: 60, marginBottom: 14 }}>🌍</Text>
            <Text style={{ fontSize: 18, fontWeight: '600', color: C.navy, marginBottom: 4, textAlign: 'center' }}>Choose your language</Text>
            <Text style={{ fontSize: 17, fontWeight: '600', color: C.navy, fontStyle: 'italic', marginBottom: 6, textAlign: 'center' }}>Elija su idioma</Text>
            <Text style={{ fontSize: 11, color: C.gray, textAlign: 'center' }}>You can change this anytime in Settings · Puede cambiarlo en Configuración</Text>
          </View>
          <PBtn label="🇺🇸  English — United States" onPress={() => setSnapshot((p) => ({ ...p, language: 'en', currentScreen: 'signIn' }))} variant="primary" size="huge" />
          <PBtn label="🇲🇽  Español — México · United States" onPress={() => setSnapshot((p) => ({ ...p, language: 'es', currentScreen: 'signIn' }))} variant="outline" size="huge" />
          {renderPCard(
            <>
              {renderCardTitle('📱 Why language choice matters', C.green)}
              {renderCardSub('Pick English or Español. This setting sticks to the device and affects all WO scope text, checklist labels, and UI copy. Most LOVING crews are bilingual — letting you pick reduces errors when reading line item scopes and job notes.')}
            </>,
            'ok'
          )}
          <Text style={{ textAlign: 'center', marginTop: 20, fontSize: 10, color: '#b4b2a9' }}>LOVING Group · Foreman v1.0.0</Text>
        </ScrollView>
      </SafeAreaView>
    );
  }

  // Sign-In screen
  if (screen === 'signIn') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: snapshot.language === 'es' ? 'Iniciar sesión · Dispositivo' : 'Sign In · Foreman Device', bg: C.navy })}
        <ScrollView contentContainerStyle={{ padding: 12, paddingBottom: 40 }}>
          <View style={{ alignItems: 'center', paddingVertical: 24, paddingHorizontal: 16 }}>
            <View style={{ width: 64, height: 64, borderRadius: 14, backgroundColor: C.blue, alignItems: 'center', justifyContent: 'center', marginBottom: 16, shadowColor: C.blue, shadowOpacity: 0.25, shadowRadius: 12, shadowOffset: { width: 0, height: 4 }, elevation: 6 }}>
              <Text style={{ fontSize: 28, color: C.white }}>🚚</Text>
            </View>
            <Text style={{ fontSize: 17, fontWeight: '600', color: C.navy, marginBottom: 4 }}>
              {snapshot.language === 'es' ? 'Bienvenido' : 'Welcome back'}
            </Text>
            <Text style={{ fontSize: 12, color: C.gray }}>
              {snapshot.language === 'es' ? 'Selecciona tu recurso de servicio' : 'Select your Service Resource for today'}
            </Text>
          </View>
          {error ? renderPCard(<Text style={{ color: C.red, fontSize: 12 }}>{error}</Text>, 'alert') : null}
          {!canUseAuth ? renderPCard(
            <>
              {renderCardTitle('⚠ Auth blocked', '#92400e')}
              {renderCardSub(authState.blocker ?? 'Salesforce OAuth is not configured.')}
              {renderCardSub(`Redirect URI: ${authRedirectUri}`)}
            </>,
            'gate'
          ) : null}
          {renderPCard(
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Text style={{ fontSize: 11, color: C.gray }}>Session mode</Text>
              <Text style={{ fontSize: 11, color: C.navy, fontWeight: '600' }}>{authState.mode === 'debugToken' ? 'Local debug token' : 'OAuth'}</Text>
            </View>
          )}
          {authState.instanceUrl && authState.accessToken ? renderPCard(
            <>
              {renderCardTitle('✓ Authenticated', C.green)}
              {renderCardSub(`Org: ${authState.orgId ?? 'Connected'} · User: ${authState.username ?? 'Connected User'}`)}
            </>,
            'ok'
          ) : null}
          {!authState.accessToken && authState.mode === 'oauth' ? (
            <PBtn label={snapshot.language === 'es' ? 'Autenticar con Salesforce' : 'Authenticate with Salesforce'} onPress={() => void doOAuth()} variant="primary" size="huge" />
          ) : null}
          {loading ? <ActivityIndicator color={C.blue} style={{ marginVertical: 12 }} /> : null}
          {authState.accessToken ? (
            <>
              <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginTop: 4 }}>
                {snapshot.language === 'es' ? 'Seleccionar recurso de servicio' : 'Select Service Resource'}
              </Text>
              <PBtn label={snapshot.language === 'es' ? 'Actualizar recursos' : 'Refresh Resources'} onPress={() => void loadResources()} variant="outline" />
              {resources.length === 0 && !loading ? renderPCard(
                <>
                  {renderCardTitle('No active Service Resources')}
                  {renderCardSub('No active ServiceResource records were returned. Verify the user has an active Service Resource in Salesforce, then tap Refresh Resources.')}
                </>
              ) : null}
              {resources.map((r) => (
                <Pressable
                  key={r.id}
                  onPress={() => setSnapshot((p) => ({
                    ...p,
                    currentRole: 'foreman',
                    selectedResource: { serviceResourceId: r.id, serviceResourceName: r.name, relatedUserId: r.relatedUserId ?? undefined },
                    currentScreen: 'myDay'
                  }))}
                  style={{ backgroundColor: C.white, borderRadius: 10, padding: 14, marginBottom: 8, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1 }}
                >
                  <Text style={{ color: C.navy, fontSize: 15, fontWeight: '700' }}>{r.name}</Text>
                  <Text style={{ color: C.gray, fontSize: 11, marginTop: 4 }}>
                    {snapshot.language === 'es' ? 'Toca para cargar el trabajo de hoy' : "Tap to load today's active work"}
                  </Text>
                </Pressable>
              ))}
            </>
          ) : (
            renderPCard(<>{renderCardSub('Authenticate with Salesforce to load your assigned Service Resource and today\'s jobs.')}</>)
          )}
          {renderPCard(
            <>
              {renderCardTitle('🔐 How sign-in works', C.blue)}
              {renderCardSub('This device authenticates with your Salesforce org. Once authenticated, select your Service Resource to load today\'s assigned Service Appointments. The session persists until you sign out or the token expires. If authentication is blocked, verify your OAuth settings with your administrator.')}
            </>,
            'blue'
          )}
        </ScrollView>
      </SafeAreaView>
    );
  }

  // My Day
  if (screen === 'myDay') {
    const totalGoal = myDay.reduce((s, r) => s + (r.goalHours ?? 0), 0);
    const first = myDay[0];
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: snapshot.language === 'es' ? 'Mi Día' : 'My Day',
          sub: `${snapshot.language === 'es' ? 'Bienvenido' : 'Welcome'}, ${selectedResource?.serviceResourceName ?? 'Foreman'} · ${snapshot.selectedDate}`,
          bg: C.navy,
          action: '🔔'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderSyncBadge(networkOnline ? 'green' : 'amber')}
          {error ? renderPCard(<Text style={{ color: C.red, fontSize: 12 }}>{error}</Text>, 'alert') : null}
          {renderPCard(
            <>
              {renderCardTitle(snapshot.language === 'es' ? '📅 Resumen de hoy' : '📅 Today at a glance')}
              {renderTimeCapture([
                [snapshot.language === 'es' ? 'Paradas programadas' : 'Stops scheduled', `${myDay.length} ${snapshot.language === 'es' ? 'trabajos' : 'jobs'}`],
                [snapshot.language === 'es' ? 'Meta de horas' : 'Goal hours (Measuring Cup)', `${totalGoal.toFixed(1)} hr`, C.green],
                [snapshot.language === 'es' ? 'Inicio primer trabajo' : 'First job start', first ? `${first.scheduledStart ? new Date(first.scheduledStart).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'TBD'} · ${first.lotName ?? first.appointmentNumber}` : snapshot.language === 'es' ? 'Sin trabajos programados' : 'No jobs scheduled'],
                [snapshot.language === 'es' ? 'Regreso estimado' : 'Expected return', 'Managed in Rippling']
              ])}
            </>,
            'ok'
          )}
          {renderPCard(
            <>
              {renderCardTitle('⏱ Rippling · Time clock')}
              {renderCardSub('Rippling status unavailable. Time remains the single source of truth in Rippling. FSL Mobile is the ops layer on top.')}
            </>
          )}
          <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>
            {snapshot.language === 'es' ? `Horario de hoy · ${myDay.length} paradas` : `Today's Schedule · ${myDay.length} stops`}
          </Text>
          {loading ? <ActivityIndicator color={C.blue} style={{ marginVertical: 12 }} /> : null}
          {myDay.length === 0 && !loading ? renderPCard(<>{renderCardSub('No ServiceAppointments returned for the selected date and resource. Tap Refresh to try again.')}</>) : null}
          {myDay.map(renderSaCard)}
          <PBtn label={snapshot.language === 'es' ? '▶ Empezar Inspección Pre-turno' : '▶ Start Pre-shift Checks'} onPress={() => go('preShiftChecks')} variant="primary" size="huge" />
          <PBtn label={snapshot.language === 'es' ? 'Actualizar' : 'Refresh'} onPress={() => void refreshMyDay()} variant="outline" />
          <PBtn label={snapshot.language === 'es' ? 'Cola de Sync' : 'Sync Queue'} onPress={() => go('syncQueue')} variant="outline" />
          {renderPCard(
            <>
              {renderCardTitle('📖 About My Day', C.blue)}
              {renderCardSub('Your complete day is shown in route order. Each stop shows the lot, job type, address, scheduled start time, goal hours, and builder. Tap any SA card to open that job. All data comes from Salesforce via your assigned Service Appointments. Tap Refresh after the dispatcher updates the schedule.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Pre-shift checks
  if (screen === 'preShiftChecks') {
    const detail = workOrderDetail;
    const checklist = detail ? getChecklistCompletion(detail) : { requiredCount: 0, completedCount: 0, ready: false };
    const groups = detail?.checklistGroups ?? [];
    const lineItems = detail?.lineItems ?? [];
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: snapshot.language === 'es' ? 'Inspección Pre-turno' : 'Pre-Shift Checks', sub: snapshot.language === 'es' ? 'Vehículo + materiales cargados' : 'Vehicle + Loaded Checklist', bg: C.navy, onBack: () => go('myDay') })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderSyncBadge(networkOnline ? 'green' : 'amber')}
          {renderPCard(
            <>
              {renderCardTitle('⚠ Required before leaving depot', '#92400e')}
              {renderCardSub('Vehicle Checklist + Loaded Checklist must both be ✓ before Service Appointments can be marked In Route. The "Start First Job" button stays locked until both reach 100%.')}
            </>,
            'gate'
          )}
          {groups.length === 0 ? renderPCard(
            <>
              {renderCardTitle('No checklist loaded')}
              {renderCardSub('Open a Service Appointment from My Day first, then return here. Checklists are pulled from the active Work Order.')}
            </>
          ) : null}
          {groups.map((group) => (
            <View key={group.id} style={{ marginBottom: 10 }}>
              {renderPCard(
                <>
                  <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                    {renderCardTitle(`🚚 ${group.name}`)}
                    <View style={{ backgroundColor: '#fef3c7', borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2 }}>
                      <Text style={{ fontSize: 10, fontWeight: '600', color: '#92400e' }}>{group.items.filter((i) => i.status === 'Complete').length} of {group.items.length}</Text>
                    </View>
                  </View>
                  {group.items.map((item, idx) => renderCheckItem(item.label, item.status === 'Complete', () => void queueChecklist(group.name, item, 'Complete', idx + 1)))}
                </>
              )}
            </View>
          ))}
          {lineItems.length > 0 ? renderPCard(
            <>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                {renderCardTitle('📦 Loaded Checklist · Today\'s materials')}
                <View style={{ backgroundColor: '#fef3c7', borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2 }}>
                  <Text style={{ fontSize: 10, fontWeight: '600', color: '#92400e' }}>0 of {lineItems.length}</Text>
                </View>
              </View>
              <Text style={{ fontSize: 10, color: C.gray, marginBottom: 6 }}>Auto-pulled from today's WO scope. Verify all materials are loaded before departing.</Text>
              {lineItems.map((item) => renderCheckItem(item.description, false))}
            </>
          ) : null}
          <PBtn
            label={checklist.ready ? (snapshot.language === 'es' ? 'Ir a Ruta / Navegación' : 'Go to Route / Navigation') : `${snapshot.language === 'es' ? 'Inicio bloqueado · checklists incompletos' : 'Start First Job (locked · checklists incomplete)'}`}
            onPress={() => checklist.ready ? go('routeNavigation') : Alert.alert('Complete all required checklist items first.')}
            variant={checklist.ready ? 'primary' : 'disabled'}
            size="huge"
          />
          {renderPCard(
            <>
              {renderCardTitle('📖 Required before you roll', C.blue)}
              {renderCardSub('Two gating checklists must reach 100% before you can proceed to Route. Vehicle Checklist covers safety items (tires, lights, fluids, brakes, fuel, fire extinguisher, first aid). Loaded Checklist confirms today\'s materials are on the truck. Sod is NOT on this list — sod is delivered directly to site by the supplier and verified on arrival.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Service Appointment Detail / Arriving
  if (screen === 'serviceAppointmentDetail' && appointmentDetail) {
    const photos = appointmentDetail.requiredPhotos;
    const staged = snapshot.queue.filter((q) => q.actionType === 'PHOTO_UPLOAD' && q.serviceAppointmentId === appointmentDetail.id).length;
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: appointmentDetail.appointmentNumber,
          sub: `${appointmentDetail.lotName ?? 'Missing Lot'} · ${appointmentDetail.workTypeName ?? 'Missing Work Type'}`,
          bg: C.navy,
          onBack: () => go('myDay'),
          action: 'Map'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {error ? renderPCard(<Text style={{ color: C.red, fontSize: 12 }}>{error}</Text>, 'alert') : null}
          {renderPCard(
            <>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
                {renderPChip(appointmentDetail.status, appointmentDetail.status.toLowerCase().includes('progress') ? 'green' : 'blue')}
                {renderPChip(appointmentDetail.marketName ?? 'Missing Market', 'gray')}
                {appointmentDetail.workOrderNumber ? renderPChip(appointmentDetail.workOrderNumber, 'amber') : null}
              </View>
              {renderTimeCapture([
                ['Appointment', appointmentDetail.appointmentNumber],
                ['Scheduled Start', appointmentDetail.scheduledStart ? new Date(appointmentDetail.scheduledStart).toLocaleString() : 'Missing Data'],
                ['Scheduled End', appointmentDetail.scheduledEnd ? new Date(appointmentDetail.scheduledEnd).toLocaleString() : 'Missing Data'],
                ['Builder', appointmentDetail.builderName ?? 'Missing Data'],
                ['Lot', appointmentDetail.lotName ?? 'Missing Data'],
                ['Address', appointmentDetail.addressLine ?? 'Missing Data']
              ])}
            </>
          )}
          {renderPCard(
            <>
              {renderCardTitle('📋 Required: Before photos', '#92400e')}
              {renderCardSub(`Front yard, back yard, side L, side R · take all ${photos.filter((p) => p.required).length} required photos before starting the job.`)}
              {staged > 0 ? <Text style={{ fontSize: 11, color: C.green, marginTop: 4, fontWeight: '600' }}>✓ {staged} photo{staged !== 1 ? 's' : ''} staged</Text> : null}
            </>,
            'warn'
          )}
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginBottom: 10 }}>
            {renderPhotoTile('Front Yard', '📷', false, () => void queuePhoto('Before Front'))}
            {renderPhotoTile('Back Yard', '📷', false, () => void queuePhoto('Before Back'))}
            {renderPhotoTile('Side Left', '📷', false, () => void queuePhoto('Before Side Left'))}
            {renderPhotoTile('Side Right', '📷', false, () => void queuePhoto('Before Side Right'))}
          </View>
          {photos.some((p) => p.category === 'Sod Quality') ? renderPCard(
            <>
              {renderCardTitle('🌱 Required: Sod Quality Photo', '#991b1b')}
              {renderCardSub('WO scope includes sod. Photograph the pallets before laying. If quality is bad (brown, dry, pest-damaged, broken), use Flag Issue instead. That photo is your protection against supplier liability.')}
              <View style={{ flexDirection: 'row', gap: 8, marginTop: 8 }}>
                <Pressable onPress={() => void queuePhoto('Sod Quality')} style={{ flex: 1, aspectRatio: 1, borderRadius: 8, backgroundColor: '#e0e0e0', borderWidth: 2, borderStyle: 'dashed', borderColor: '#b4b2a9', alignItems: 'center', justifyContent: 'center' }}>
                  <Text style={{ fontSize: 22 }}>🌱</Text>
                  <Text style={{ fontSize: 10, color: C.gray, fontWeight: '600', marginTop: 4 }}>Sod Pallets</Text>
                </Pressable>
                <Pressable onPress={() => go('flagIssue')} style={{ flex: 1, aspectRatio: 1, borderRadius: 8, backgroundColor: C.white, borderWidth: 2, borderColor: C.red, alignItems: 'center', justifyContent: 'center' }}>
                  <Text style={{ fontSize: 22 }}>🚩</Text>
                  <Text style={{ fontSize: 10, color: C.red, fontWeight: '600', marginTop: 4 }}>Flag Sod Issue</Text>
                  <Text style={{ fontSize: 9, color: C.red, opacity: 0.85, textAlign: 'center' }}>Brown · dry · pest</Text>
                </Pressable>
              </View>
            </>,
            'alert'
          ) : null}
          {appointmentDetail.notes ? renderPCard(
            <>
              {renderCardTitle('📝 CM Notes / Job Notes')}
              <Text style={{ fontSize: 12, color: C.navy, fontStyle: 'italic', lineHeight: 18 }}>{appointmentDetail.notes}</Text>
            </>
          ) : null}
          {renderMissingFlags(appointmentDetail.missingDataFlags)}
          <PBtn label="▶ Start Job · Confirm Arrival" onPress={() => go('arrival')} variant="primary" size="huge" />
          <PBtn label="Pre-Shift Checks" onPress={() => go('preShiftChecks')} variant="outline" />
          <PBtn label="Back to My Day" onPress={() => go('myDay')} variant="outline" />
          {renderPCard(
            <>
              {renderCardTitle('📖 On site — what to do', C.blue)}
              {renderCardSub('Take all 4 Before photos (front, back, left side, right side) before starting work. If the WO scope includes sod, photograph the pallets before laying — that photo is your protection against supplier quality issues. Read CM notes before beginning. Tap Start Job to confirm arrival and begin the job clock.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Work Order Detail
  if (screen === 'workOrderDetail' && workOrderDetail) {
    const checklist = getChecklistCompletion(workOrderDetail);
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: workOrderDetail.lotName ?? workOrderDetail.workOrderNumber,
          sub: `${workOrderDetail.workTypeName ?? 'Missing Work Type'} · ${workOrderDetail.communityName ?? 'Missing Community'}`,
          bg: C.navy,
          onBack: () => go('myDay'),
          action: '⋯'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
                {renderPChip(workOrderDetail.status, workOrderDetail.status.toLowerCase().includes('complete') ? 'green' : 'blue')}
                {renderPChip(`${checklist.completedCount}/${checklist.requiredCount} checks`, checklist.ready ? 'green' : 'amber')}
                {renderPChip(workOrderDetail.marketName ?? 'Missing Market', 'gray')}
              </View>
              {renderTimeCapture([
                ['Work Order', workOrderDetail.workOrderNumber],
                ['Subject', workOrderDetail.subject ?? 'Missing Data'],
                ['Job Type', workOrderDetail.jobType ?? 'Missing Data'],
                ['Builder', workOrderDetail.builderName ?? 'Missing Data'],
                ['Lot', workOrderDetail.lotName ?? 'Missing Data'],
                ['Address', workOrderDetail.addressLine ?? 'Missing Data']
              ])}
            </>
          )}
          {renderPCard(
            <>
              {renderCardTitle('Work Scope')}
              {workOrderDetail.lineItems.length === 0 ? renderCardSub('Missing Data: no WorkOrderLineItem records.') : null}
              {workOrderDetail.lineItems.map((line) => (
                <View key={line.id} style={{ flexDirection: 'row', alignItems: 'center', backgroundColor: '#f8fafc', borderRadius: 6, padding: 10, marginBottom: 4, borderWidth: 1, borderColor: C.border }}>
                  <View style={{ width: 22, height: 22, borderRadius: 6, backgroundColor: line.status === 'Complete' ? C.green : C.white, borderWidth: 2, borderColor: line.status === 'Complete' ? C.green : C.borderMid, marginRight: 10, alignItems: 'center', justifyContent: 'center' }}>
                    {line.status === 'Complete' ? <Text style={{ color: C.white, fontSize: 12 }}>✓</Text> : null}
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 12, color: C.navy, fontWeight: '500' }}>{line.description}</Text>
                    <Text style={{ fontSize: 10, color: C.gray, marginTop: 2 }}>Qty: {line.quantity ?? 'Missing Data'} · {line.status}</Text>
                  </View>
                </View>
              ))}
            </>
          )}
          {workOrderDetail.notes ? renderPCard(
            <>{renderCardTitle('Notes')}{renderCardSub(workOrderDetail.notes)}</>
          ) : null}
          {renderMissingFlags(workOrderDetail.missingDataFlags)}
          <PBtn label="Pre-Shift Checks" onPress={() => go('preShiftChecks')} variant="primary" />
          <PBtn label={checklist.ready ? 'Route / Navigation' : 'Route blocked until required checks complete'} onPress={() => go('routeNavigation')} variant={checklist.ready ? 'outline' : 'disabled'} />
          <PBtn label="Active Job" onPress={() => go('activeJob')} variant="outline" />
          <PBtn label="Closeout" onPress={() => go('closeout')} variant="outline" />
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Route / Navigation
  if (screen === 'routeNavigation') {
    const detail = workOrderDetail;
    const canOpenMap = Boolean(detail?.addressLine);
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: 'In Route',
          sub: detail ? `${detail.lotName ?? 'Next stop'} · ${detail.addressLine ?? 'Missing address'}` : 'Select a job first',
          bg: C.blue,
          onBack: () => go('preShiftChecks'),
          action: '⋯'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              <Text style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 1, color: C.gray, marginBottom: 4 }}>🚚 DRIVING</Text>
              <Text style={{ fontSize: 24, fontWeight: '700', color: C.navy }}>Open Navigation</Text>
              {renderCardSub('WEX GPS tracking active while in route. Drive time captured separately from job time.')}
            </>
          )}
          <View style={{ height: 220, borderRadius: 10, backgroundColor: C.blueLight, alignItems: 'center', justifyContent: 'center', marginBottom: 10, borderWidth: 1, borderColor: '#b5d4f4' }}>
            <Text style={{ fontSize: 38 }}>🗺️</Text>
            <Text style={{ color: C.navy, fontWeight: '700', marginTop: 8 }}>Navigation handoff</Text>
            <Text style={{ color: C.gray, fontSize: 10, marginTop: 4 }}>Opens Apple Maps or Google Maps for voice guidance</Text>
          </View>
          <PBtn label="🧭 Open in Apple Maps" onPress={() => void openMaps(detail?.addressLine)} variant={canOpenMap ? 'primary' : 'disabled'} size="huge" />
          {detail ? renderPCard(
            <>
              {renderCardTitle('📍 Turn-by-turn directions')}
              {renderCardSub('Directions are provided through native navigation apps. Tap Open in Apple Maps to start voice guidance.')}
              {renderTimeCapture([
                ['Address', detail.addressLine ?? 'Missing Data'],
                ['Market', detail.marketName ?? 'Missing Data'],
                ['Work Type', detail.workTypeName ?? 'Missing Data']
              ])}
            </>
          ) : null}
          {detail ? renderPCard(
            <>
              {renderCardTitle('📋 Next up at ' + (detail.lotName ?? 'job site'))}
              {renderCardSub(`${detail.workTypeName ?? 'Missing Work Type'} · ${detail.lineItems.length} line item${detail.lineItems.length === 1 ? '' : 's'} · ${detail.addressLine ?? 'Missing address'}`)}
            </>
          ) : null}
          <PBtn label="Arrival · Confirm On Site" onPress={() => go('arrival')} variant="outline" />
          {renderPCard(
            <>
              {renderCardTitle('📖 Drive time tracking', C.blue)}
              {renderCardSub('Drive time is captured from the moment you mark In Route until Confirm Arrival. It is recorded separately from active job time so routing variance does not penalize crew productivity scores. WEX GPS pings every 3 minutes. If GPS is unavailable, the system logs estimated drive time based on scheduled start.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Arrival / On Site
  if (screen === 'arrival') {
    const target = availableSaStatuses.includes('In Progress') ? 'In Progress' : availableSaStatuses.includes('Scheduled') ? 'Scheduled' : availableSaStatuses[0];
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: appointmentDetail?.appointmentNumber ?? 'Arriving',
          sub: `${appointmentDetail?.lotName ?? 'On Site'} · Confirm arrival`,
          bg: C.navy,
          onBack: () => go('routeNavigation')
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          <View style={{ backgroundColor: C.blue, borderRadius: 10, padding: 14, marginBottom: 10, alignItems: 'center' }}>
            <Text style={{ color: 'rgba(255,255,255,0.9)', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 }}>📍 Arrived (confirm below)</Text>
            <Text style={{ color: C.white, fontSize: 24, fontWeight: '700' }}>{new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</Text>
            {appointmentDetail?.addressLine ? <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 11, marginTop: 2 }}>{appointmentDetail.addressLine}</Text> : null}
          </View>
          {renderPCard(
            <>
              {renderTimeCapture([
                ['Available statuses', availableSaStatuses.join(', ') || 'Unavailable'],
                ['Target status', target ?? 'Unavailable']
              ])}
            </>
          )}
          {renderPCard(
            <>
              {renderCardTitle('📍 Arrival capture', '#92400e')}
              {renderCardSub('If location permission is granted, GPS coordinates are queued with the arrival update and logged on the Service Appointment record in Salesforce. FM Jimbo receives a push notification when you confirm arrival.')}
            </>,
            'warn'
          )}
          <PBtn
            label={`▶ Start Job · Confirm Arrival${target ? ` → ${target}` : ''}`}
            onPress={() => void queueArrival(target ?? '')}
            variant={target ? 'primary' : 'disabled'}
            size="huge"
          />
          <PBtn label="Active Job" onPress={() => go('activeJob')} variant="outline" />
          {renderPCard(
            <>
              {renderCardTitle('📖 Job clock starts here', C.blue)}
              {renderCardSub('Tapping Start Job captures the official Job Start Time. This timestamp is logged on the Work Order and Service Appointment in Salesforce. It is the start of active job time for Measuring Cup variance calculations. Before photos should be taken before or immediately after confirming arrival.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Active Job
  if (screen === 'activeJob' && workOrderDetail) {
    const detail = workOrderDetail;
    const now = new Date();
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: detail.lotName ?? detail.workOrderNumber,
          sub: `${detail.workTypeName ?? 'Missing Work Type'} · In Progress`,
          bg: C.green,
          onBack: () => go('arrival'),
          action: '⋯'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderTimeCapture([
            ['Job Start', 'Captured on arrival'],
            ['Elapsed (active)', now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })],
            ['Goal', detail.lineItems.length > 0 ? `${detail.lineItems.length} line item${detail.lineItems.length === 1 ? '' : 's'}` : 'Missing Data'],
            ['Projected end', 'Calculated from Measuring Cup goal hours']
          ])}
          {renderPCard(
            <>
              {renderCardTitle('⏱ On track', C.green)}
              {renderProgressBar(45, 'green')}
              {renderCardSub('Progress updates as line items are completed. Each tap queues a timestamp to Salesforce.')}
            </>,
            'ok'
          )}
          <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>Job checklist</Text>
          {detail.lineItems.length === 0 ? renderPCard(<>{renderCardSub('Missing Data: no WorkOrderLineItem records.')}</>) : null}
          {detail.lineItems.map((line) => (
            <View key={line.id} style={{ flexDirection: 'row', alignItems: 'center', backgroundColor: C.white, borderRadius: 8, padding: 10, paddingHorizontal: 12, marginBottom: 6, borderWidth: 1, borderColor: C.border }}>
              <View style={{ width: 22, height: 22, borderRadius: 6, backgroundColor: line.status === 'Complete' ? C.green : C.white, borderWidth: 2, borderColor: line.status === 'Complete' ? C.green : C.borderMid, marginRight: 10, alignItems: 'center', justifyContent: 'center' }}>
                {line.status === 'Complete' ? <Text style={{ color: C.white, fontSize: 13 }}>✓</Text> : null}
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontSize: 12, color: C.navy, fontWeight: '500' }}>{line.description}</Text>
                <Text style={{ fontSize: 10, color: C.gray, marginTop: 2 }}>Qty: {line.quantity ?? 'Missing Data'} · {line.status}</Text>
              </View>
            </View>
          ))}
          <TextInput
            placeholder="Add note about this job..."
            value={noteText}
            onChangeText={setNoteText}
            multiline
            style={{ backgroundColor: C.white, borderWidth: 1, borderColor: C.borderMid, borderRadius: 10, padding: 12, fontSize: 13, color: C.navy, marginBottom: 8, minHeight: 60 }}
            placeholderTextColor={C.gray}
          />
          <PBtn label="📝 Queue Note" onPress={() => void queueNote(detail.id)} variant="outline" />
          <PBtn label="📷 Add Progress Photo" onPress={() => void queuePhoto('Progress')} variant="outline" />
          <PBtn label="⚠ Flag Issue" onPress={() => go('flagIssue')} variant="warn" />
          <PBtn label="✅ Closeout" onPress={() => go('closeout')} variant="success" />
          {renderPCard(
            <>
              {renderCardTitle('📖 Active job in progress', C.blue)}
              {renderCardSub('Track progress by tapping line items as your crew completes them — each tap queues a timestamp to Salesforce. Stage progress photos throughout. If anything can\'t be completed today (blocked access, missing material, site not ready), use Flag Issue to notify your Field Manager. FM — not you — creates any Finish Job work order.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Flag Issue (replaces 2PM Health Check — always available, no time gate)
  if (screen === 'flagIssue') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: 'Flag + Submit',
          sub: 'Routes to your Field Manager · Always available',
          bg: C.red,
          onBack: () => go('activeJob'),
          action: 'Submit'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              {renderCardTitle('🚨 Required: notes + flag items', '#991b1b')}
              {renderCardSub('Tag items that cannot complete and add notes explaining why. Your Field Manager receives a push notification and reviews your submission. FM — not you — creates the Finish Job work order.')}
            </>,
            'alert'
          )}
          <Text style={{ fontSize: 11, color: C.navy, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>Issue Type</Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 10 }}>
            {issueTypes.map((type) => (
              <Pressable
                key={type}
                onPress={() => setIssueDraft((p) => ({ ...p, issueType: type }))}
                style={{ backgroundColor: issueDraft.issueType === type ? C.blue : C.white, borderColor: C.blue, borderWidth: 1, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 8, marginRight: 6, marginBottom: 6 }}
              >
                <Text style={{ color: issueDraft.issueType === type ? C.white : C.blue, fontSize: 12, fontWeight: '600' }}>{type}</Text>
              </Pressable>
            ))}
          </View>
          {renderPCard(
            <>
              {renderCardTitle('📝 Notes (required)')}
              <TextInput
                placeholder="Describe what can't complete and why. Include what was done today and what remains. Recommend a return date if known."
                value={issueDraft.notes}
                onChangeText={(t) => setIssueDraft((p) => ({ ...p, notes: t }))}
                multiline
                style={{ backgroundColor: '#f4f6f9', padding: 10, borderRadius: 6, fontSize: 12, color: C.navy, minHeight: 110, lineHeight: 18, marginTop: 4 }}
                placeholderTextColor={C.gray}
              />
            </>
          )}
          {workOrderDetail && workOrderDetail.lineItems.length > 0 ? renderPCard(
            <>
              {renderCardTitle('Tap items that cannot complete')}
              {workOrderDetail.lineItems.map((line) => (
                <Pressable
                  key={line.id}
                  onPress={() => setIssueDraft((p) => {
                    const already = p.impactedLineItemIds.includes(line.id);
                    return { ...p, impactedLineItemIds: already ? p.impactedLineItemIds.filter((id) => id !== line.id) : [...p.impactedLineItemIds, line.id] };
                  })}
                  style={{ flexDirection: 'row', alignItems: 'center', backgroundColor: issueDraft.impactedLineItemIds.includes(line.id) ? C.redLight : C.white, borderRadius: 8, padding: 10, marginBottom: 6, borderWidth: 1, borderColor: issueDraft.impactedLineItemIds.includes(line.id) ? C.red : C.border }}
                >
                  <View style={{ width: 22, height: 22, borderRadius: 6, backgroundColor: issueDraft.impactedLineItemIds.includes(line.id) ? C.red : C.white, borderWidth: 2, borderColor: issueDraft.impactedLineItemIds.includes(line.id) ? C.red : C.borderMid, marginRight: 10, alignItems: 'center', justifyContent: 'center' }}>
                    {issueDraft.impactedLineItemIds.includes(line.id) ? <Text style={{ color: C.white, fontSize: 13 }}>✗</Text> : null}
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={{ fontSize: 12, color: issueDraft.impactedLineItemIds.includes(line.id) ? '#991b1b' : C.navy, fontWeight: '500' }}>{line.description}</Text>
                    {issueDraft.impactedLineItemIds.includes(line.id) ? <Text style={{ fontSize: 10, color: '#991b1b', marginTop: 2 }}>CANNOT COMPLETE · flagged</Text> : null}
                  </View>
                </Pressable>
              ))}
            </>
          ) : null}
          {renderPCard(
            <>
              {renderCardTitle('⚠ When you submit', '#92400e')}
              {renderCardSub('→ FM receives push notification with your notes + flagged items\n→ FM reviews, creates FJ work order, schedules + assigns crew\n→ You do not create the FJ · your FM does\n→ This issue closes with line-item-level Cannot Complete data recorded in Salesforce')}
            </>,
            'warn'
          )}
          <PBtn label="📷 Stage Issue Photo" onPress={() => void queuePhoto('Issue')} variant="outline" />
          <PBtn label="⚠ Submit to Field Manager" onPress={() => void queueIssue()} variant="warn" size="huge" />
          {renderPCard(
            <>
              {renderCardTitle('📖 Flagging an issue', C.blue)}
              {renderCardSub('This screen is always available — there is no 2 PM time gate in the Foreman app. Flag items any time you know something cannot complete. Add notes explaining the situation and recommend a return date if you know one. Your Field Manager (FM) sees your notes, reviews the flagged items, and creates the Finish Job work order. Foremen identify the problem. FM decides the response.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Closeout
  if (screen === 'closeout') {
    const detail = workOrderDetail;
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: 'Closeout',
          sub: detail ? `${detail.lotName ?? detail.workOrderNumber} · ${detail.workTypeName ?? 'Missing Work Type'}` : 'Finish Job',
          bg: C.green,
          onBack: () => go('activeJob')
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {detail ? renderTimeCapture([
            ['Job Type', detail.workTypeName ?? 'Missing Data'],
            ['Work Order', detail.workOrderNumber],
            ['Status', detail.status],
            ['Goal', `${detail.lineItems.length} line item${detail.lineItems.length === 1 ? '' : 's'}`],
            ['Available WO statuses', availableWoStatuses.join(', ') || 'Unavailable'],
            ['Staged photos', `${stagedPhotoCount}`]
          ]) : null}
          {renderPCard(
            <>
              {renderCardTitle('✅ Ready to close')}
              {detail ? renderCardSub(`${detail.lineItems.filter((l) => l.status === 'Complete').length} of ${detail.lineItems.length} items complete · ${stagedPhotoCount} photo${stagedPhotoCount !== 1 ? 's' : ''} staged`) : renderCardSub('Review the data above before closing.')}
            </>,
            'ok'
          )}
          <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>
            Required photos · Final + Material
          </Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginBottom: 10 }}>
            {renderPhotoTile('Sod Laid', '🌱', false, () => void queuePhoto('Sod Quality'))}
            {renderPhotoTile('Final After', '✨', false, () => void queuePhoto('Final'))}
            {renderPhotoTile('Material Check', '📦', false, () => void queuePhoto('Material'))}
            {renderPhotoTile('Progress Shot', '📷', false, () => void queuePhoto('Progress'))}
          </View>
          {detail && detail.lineItems.length > 0 ? renderPCard(
            <>
              {renderCardTitle('Material check')}
              {detail.lineItems.map((line) => (
                <View key={line.id} style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 3, borderBottomWidth: 1, borderBottomColor: C.border }}>
                  <Text style={{ fontSize: 11, color: C.navy, flex: 1 }}>{line.description}</Text>
                  <View style={{ flexDirection: 'row', gap: 4 }}>
                    {renderPChip(line.status === 'Complete' ? '✓ Done' : line.status, line.status === 'Complete' ? 'green' : line.status === 'Cannot Complete' ? 'red' : 'amber')}
                  </View>
                </View>
              ))}
            </>
          ) : null}
          <TextInput
            placeholder="Closeout notes — describe final site condition, any outstanding items, access instructions for follow-up..."
            value={closeoutText}
            onChangeText={setCloseoutText}
            multiline
            style={{ backgroundColor: C.white, borderWidth: 1, borderColor: C.borderMid, borderRadius: 10, padding: 12, fontSize: 13, color: C.navy, marginBottom: 8, minHeight: 110 }}
            placeholderTextColor={C.gray}
          />
          <PBtn label="📷 Stage Final Photo" onPress={() => void queuePhoto('Final')} variant="outline" />
          <PBtn label="✅ Queue Closeout Note" onPress={() => void queueCloseout(snapshot.currentWorkOrderId)} variant="success" size="huge" />
          <PBtn label="View Sync Queue" onPress={() => go('syncQueue')} variant="outline" />
          {renderPCard(
            <>
              {renderCardTitle('📖 Closing this job', C.blue)}
              {renderCardSub('Closeout captures Job Type, Work Order, and completion state — this data feeds the analytics layer for time-by-job-type measurement. Stage your Final photos before tapping Queue Closeout Note. All queued items sync to Salesforce when you reconnect. Queued data persists through app restarts and retries automatically. Rippling remains the system of record for time — this app captures the ops layer.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Sync Queue
  if (screen === 'syncQueue') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'Sync Queue', sub: 'Offline + On-device queued items', bg: C.navy, onBack: () => go('myDay') })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderSyncBadge(networkOnline ? 'green' : 'amber')}
          {renderPCard(
            <>{renderTimeCapture([
              ['Total queued', `${snapshot.queue.length}`],
              ['Failed', `${snapshot.queue.filter((q) => q.syncStatus === 'Failed').length}`],
              ['Synced', `${snapshot.queue.filter((q) => q.syncStatus === 'Synced').length}`],
              ['Last sync', snapshot.lastSyncAt ? new Date(snapshot.lastSyncAt).toLocaleTimeString() : 'Never']
            ])}</>
          )}
          <PBtn label="🔄 Sync Now" onPress={() => void syncQueue()} variant="primary" />
          {snapshot.queue.length === 0 ? renderPCard(
            <>{renderCardTitle('No queued items', C.green)}{renderCardSub('All data is synced to Salesforce.')}</>,
            'ok'
          ) : null}
          {snapshot.queue.map((item) => (
            <View key={item.localId} style={{ backgroundColor: C.white, borderRadius: 10, padding: 12, paddingHorizontal: 14, marginBottom: 8, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1 }}>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 6 }}>
                {renderPChip(item.actionType, 'blue')}
                {renderPChip(item.syncStatus, item.syncStatus === 'Synced' ? 'green' : item.syncStatus === 'Failed' ? 'red' : item.syncStatus === 'Syncing' ? 'amber' : 'gray')}
              </View>
              <Text style={{ fontSize: 10, color: C.gray }}>Local ID: {item.localId}</Text>
              <Text style={{ fontSize: 10, color: C.gray }}>Record: {item.salesforceRecordId ?? item.workOrderId ?? item.serviceAppointmentId ?? 'Local only'}</Text>
              {item.photoLocalUri ? <Text style={{ fontSize: 10, color: C.gray }}>Photo: {item.photoLocalUri}</Text> : null}
              {item.errorMessage ? <Text style={{ color: C.red, fontSize: 11, marginTop: 6 }}>{item.errorMessage}</Text> : null}
              {(item.syncStatus === 'Failed' || item.syncStatus === 'Queued') ? (
                <PBtn
                  label="Retry"
                  onPress={async () => {
                    await queueRepository.update({ ...item, syncStatus: 'Queued', localUpdatedAt: new Date().toISOString() });
                    await refreshQueueFromStorage();
                    await syncQueue();
                  }}
                  variant="outline"
                />
              ) : null}
            </View>
          ))}
          {renderPCard(
            <>
              {renderCardTitle('📖 Offline sync', C.blue)}
              {renderCardSub('Every action (status updates, photos, checklist items, notes, issue flags) is queued locally first, then synced to Salesforce when online. Items marked Failed can be retried. Queued items persist through app restarts. If an item stays Failed after multiple retries, check your Salesforce connection and org configuration, then retry manually.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Settings / More
  if (screen === 'settings') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'More', sub: 'Foreman app controls · Session info', bg: C.navy })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>{renderTimeCapture([
              ['Org', authState.orgId ?? 'Connected'],
              ['User', authState.username ?? 'Connected User'],
              ['Current App', 'LOVING Foreman'],
              ['Language', snapshot.language === 'es' ? 'Español' : 'English'],
              ['Offline storage', 'AsyncStorage'],
              ['Last sync', snapshot.lastSyncAt ? new Date(snapshot.lastSyncAt).toLocaleString() : 'Never'],
              ['App version', '1.0.0'],
              ['Network', networkOnline ? 'Online' : 'Offline']
            ])}</>
          )}
          {renderPCard(
            <>
              {renderCardTitle('Foreman rules', C.navy)}
              {renderCardSub('No lunch workflow. No 2 PM Health Check. No time clock in this app — time remains the single source of truth in Rippling. FSL Mobile is the ops layer: checklists, jobs, photos, issue flags, and sync.')}
            </>,
            'blue'
          )}
          {renderPCard(
            <>
              {renderCardTitle('Active work data flow')}
              {renderCardSub('ServiceAppointment → ParentRecordId → WorkOrder. Market and division are sourced from WorkOrder.ServiceTerritory. All writes queue offline and sync on reconnect. Schedule_Issue__c receives issue flags. Field_Checklist__c receives pre-shift checks.')}
            </>
          )}
          <PBtn label="Switch to English" onPress={() => setSnapshot((p) => ({ ...p, language: 'en' }))} variant="primary" />
          <PBtn label="Cambiar a Español" onPress={() => setSnapshot((p) => ({ ...p, language: 'es' }))} variant="outline" />
          <PBtn label="View Sync Queue" onPress={() => go('syncQueue')} variant="outline" />
          <PBtn label="Sign Out" onPress={() => void logout()} variant="outline" />
          {renderPCard(
            <>
              {renderCardTitle('📖 About LOVING Foreman', C.blue)}
              {renderCardSub('Standalone Foreman app for Production Install crews. Active work flows from your assigned ServiceAppointment through the ParentRecordId to the WorkOrder. All offline writes queue locally and sync when you reconnect. Rippling owns time tracking — this app captures the operations layer: pre-shift checklists, arrival confirmation, job progress, issue flags, photos, and closeout notes.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar(screen)}
      </SafeAreaView>
    );
  }

  // Fallback for unknown screen
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
      <StatusBar style="light" />
      {renderFslHeader({ title: 'LOVING Foreman', bg: C.navy })}
      <ScrollView contentContainerStyle={{ padding: 12 }}>
        {renderPCard(
          <>
            {renderCardTitle('Unknown screen')}
            {renderCardSub(`Screen "${screen}" not found.`)}
          </>
        )}
        <PBtn label="Go to My Day" onPress={() => go('myDay')} variant="primary" />
        <PBtn label="Go to Sign In" onPress={() => go('signIn')} variant="outline" />
      </ScrollView>
    </SafeAreaView>
  );
}

// ─── Shared UI primitives ─────────────────────────────────────────────────────
function PBtn({
  label,
  onPress,
  variant = 'primary',
  size = 'normal'
}: {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'success' | 'danger' | 'warn' | 'outline' | 'disabled';
  size?: 'normal' | 'huge';
}) {
  const styles: Record<string, { bg: string; color: string; borderWidth?: number; borderColor?: string }> = {
    primary: { bg: '#0070d2', color: '#ffffff' },
    success: { bg: '#04844b', color: '#ffffff' },
    danger: { bg: '#c23934', color: '#ffffff' },
    warn: { bg: '#fe9339', color: '#ffffff' },
    outline: { bg: '#ffffff', color: '#0070d2', borderWidth: 1, borderColor: '#0070d2' },
    disabled: { bg: '#e5e5e5', color: '#b4b2a9' }
  };
  const s = styles[variant];
  const py = size === 'huge' ? 18 : 14;
  const fs = size === 'huge' ? 16 : 14;
  return (
    <Pressable
      onPress={variant === 'disabled' ? undefined : onPress}
      style={{ backgroundColor: s.bg, borderRadius: 10, paddingVertical: py, paddingHorizontal: 16, marginBottom: 8, borderWidth: s.borderWidth ?? 0, borderColor: s.borderColor ?? 'transparent', alignItems: 'center' }}
    >
      <Text style={{ color: s.color, fontSize: fs, fontWeight: '600', textAlign: 'center' }}>{label}</Text>
    </Pressable>
  );
}

function reduceError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}
