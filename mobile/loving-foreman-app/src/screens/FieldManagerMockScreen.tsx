import React, { useState } from 'react';
import {
  Alert,
  Pressable,
  SafeAreaView,
  ScrollView,
  Text,
  TextInput,
  View
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import {
  fieldManagerAppointments,
  fieldManagerForemen,
  type FieldManagerForeman,
  type FieldManagerMockAppointment
} from '@/data/fieldManagerMock';

// ─── Design constants (same system as foreman App.tsx) ────────────────────────
const C = {
  navy: '#16325c',
  blue: '#0070d2',
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
  purple: '#ede9fe',
  purpleText: '#5b21b6',
} as const;

// ─── FM Tab type ──────────────────────────────────────────────────────────────
type FMTab = 'day' | 'crews' | 'map' | 'issues' | 'more';
type FMScreen = 'day' | 'visitDetail' | 'crews' | 'foremanDetail' | 'map' | 'issues' | 'healthCheck' | 'more';

interface FMAppProps {
  onSignOut: () => void;
}

// ─── Appointment type badge colors ────────────────────────────────────────────
const apptTypeTone: Record<string, { bg: string; color: string }> = {
  'Take-Offs': { bg: '#ede9fe', color: '#5b21b6' },
  'Quality Inspection': { bg: '#e8f5e9', color: '#2e7d32' },
  'Site Readiness': { bg: '#e3f0fb', color: '#0c447c' },
  'Customer Care': { bg: '#fce8e8', color: '#991b1b' },
  'Aqua Check-Work Order': { bg: '#e6f4f7', color: '#0a8aa6' },
  'Aqua Pick-Up-Work Order': { bg: '#fef3c7', color: '#92400e' }
};

const healthColors: Record<FieldManagerForeman['healthCheckStatus'], string> = {
  Green: C.green,
  Yellow: C.amber,
  Red: C.red
};

export function FieldManagerMockScreen({ onSignOut }: FMAppProps) {
  const [screen, setScreen] = useState<FMScreen>('day');
  const [selectedApptId, setSelectedApptId] = useState<string>(fieldManagerAppointments[0].id);
  const [selectedForemanId, setSelectedForemanId] = useState<string>(fieldManagerForemen[0].id);
  const [statusOverrides, setStatusOverrides] = useState<Record<string, FieldManagerMockAppointment['status']>>({});
  const [healthOverrides, setHealthOverrides] = useState<Record<string, FieldManagerForeman['healthCheckStatus']>>({});
  const [checklistDone, setChecklistDone] = useState<Record<string, boolean>>({});
  const [visitNote, setVisitNote] = useState('');
  const [issueNotes, setIssueNotes] = useState<Record<string, string>>({});

  const selectedAppt = fieldManagerAppointments.find((a) => a.id === selectedApptId) ?? fieldManagerAppointments[0];
  const selectedForeman = fieldManagerForemen.find((f) => f.id === selectedForemanId) ?? fieldManagerForemen[0];

  function go(s: FMScreen) { setScreen(s); }

  function tabActive(): FMTab {
    if (screen === 'day' || screen === 'visitDetail') return 'day';
    if (screen === 'crews' || screen === 'foremanDetail') return 'crews';
    if (screen === 'map') return 'map';
    if (screen === 'issues' || screen === 'healthCheck') return 'issues';
    return 'more';
  }

  function openVisit(id: string) {
    setSelectedApptId(id);
    go('visitDetail');
  }

  function openForeman(id: string) {
    setSelectedForemanId(id);
    go('foremanDetail');
  }

  // ─── Render helpers ───────────────────────────────────────────────────────
  function renderFslHeader(opts: { title: string; sub?: string; bg?: string; onBack?: () => void; action?: string; onAction?: () => void }) {
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

  function renderTabBar() {
    const active = tabActive();
    const tabs: Array<{ key: FMTab; icon: string; label: string }> = [
      { key: 'day', icon: '🏠', label: 'My Day' },
      { key: 'crews', icon: '👥', label: 'Crews' },
      { key: 'map', icon: '🗺', label: 'Map' },
      { key: 'issues', icon: '⚠️', label: 'Issues' },
      { key: 'more', icon: '⋯', label: 'More' }
    ];
    const targets: Record<FMTab, FMScreen> = {
      day: 'day', crews: 'crews', map: 'map', issues: 'issues', more: 'more'
    };
    return (
      <View style={{ backgroundColor: C.white, borderTopWidth: 1, borderTopColor: '#e0e0e0', flexDirection: 'row', height: 56, paddingBottom: 8, paddingTop: 6 }}>
        {tabs.map((tab) => {
          const isOn = tab.key === active;
          return (
            <Pressable key={tab.key} onPress={() => go(targets[tab.key])} style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
              <Text style={{ fontSize: 18, color: isOn ? C.blue : C.gray }}>{tab.icon}</Text>
              <Text style={{ fontSize: 9, fontWeight: '500', color: isOn ? C.blue : C.gray, marginTop: 2 }}>{tab.label}</Text>
            </Pressable>
          );
        })}
      </View>
    );
  }

  function renderPCard(children: React.ReactNode, variant?: 'alert' | 'warn' | 'ok' | 'gate' | 'blue', extra?: object) {
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
        extra
      ]}>
        {children}
      </View>
    );
  }

  function renderCardTitle(text: string, color?: string) {
    return <Text style={{ fontSize: 12, fontWeight: '600', color: color ?? C.navy, marginBottom: 6, flexDirection: 'row', alignItems: 'center' }}>{text}</Text>;
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
            <Text style={{ fontSize: 11, color: valueColor ?? C.navy, fontWeight: '600' }}>{value}</Text>
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
      purple: { bg: C.purple, color: C.purpleText }
    };
    const p = palette[tone];
    return (
      <View key={label} style={{ backgroundColor: p.bg, borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2, marginRight: 4, marginBottom: 4 }}>
        <Text style={{ fontSize: 10, fontWeight: '600', color: p.color }}>{label}</Text>
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
        <View style={{ width: 22, height: 22, borderRadius: 5, backgroundColor: done ? C.green : C.white, borderWidth: done ? 0 : 2, borderColor: C.borderMid, alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          {done ? <Text style={{ color: C.white, fontSize: 13 }}>✓</Text> : null}
        </View>
        <Text style={{ fontSize: 11, color: done ? '#2e844a' : C.navy, flex: 1 }}>{label}</Text>
      </Pressable>
    );
  }

  function renderPhotoTile(label: string, icon: string, captured: boolean, onPress?: () => void) {
    return (
      <Pressable
        key={label}
        onPress={onPress}
        style={{ width: '48%', aspectRatio: 1, borderRadius: 8, backgroundColor: captured ? '#5a8a4a' : '#e0e0e0', borderWidth: 2, borderStyle: captured ? 'solid' : 'dashed', borderColor: captured ? 'transparent' : '#b4b2a9', alignItems: 'center', justifyContent: 'center', gap: 4, marginBottom: 8 }}
      >
        <Text style={{ fontSize: 22 }}>{icon}</Text>
        <Text style={{ fontSize: 10, fontWeight: '600', color: captured ? C.white : C.gray }}>{label}</Text>
        {captured ? <View style={{ backgroundColor: 'rgba(0,0,0,0.5)', paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4 }}><Text style={{ fontSize: 9, color: C.white, fontWeight: '600' }}>CAPTURED</Text></View> : null}
      </Pressable>
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

  function renderPBtn(label: string, onPress: () => void, variant: 'primary' | 'success' | 'danger' | 'warn' | 'outline' | 'disabled' = 'primary', size: 'normal' | 'huge' = 'normal') {
    const styles: Record<string, { bg: string; color: string; borderWidth?: number; borderColor?: string }> = {
      primary: { bg: C.blue, color: C.white },
      success: { bg: C.green, color: C.white },
      danger: { bg: C.red, color: C.white },
      warn: { bg: C.amber, color: C.white },
      outline: { bg: C.white, color: C.blue, borderWidth: 1, borderColor: C.blue },
      disabled: { bg: '#e5e5e5', color: '#b4b2a9' }
    };
    const s = styles[variant];
    return (
      <Pressable
        onPress={variant === 'disabled' ? undefined : onPress}
        style={{ backgroundColor: s.bg, borderRadius: 10, paddingVertical: size === 'huge' ? 18 : 14, paddingHorizontal: 16, marginBottom: 8, borderWidth: s.borderWidth ?? 0, borderColor: s.borderColor ?? 'transparent', alignItems: 'center' }}
      >
        <Text style={{ color: s.color, fontSize: size === 'huge' ? 16 : 14, fontWeight: '600', textAlign: 'center' }}>{label}</Text>
      </Pressable>
    );
  }

  // ─── Visit card (FM's SA card equivalent) ─────────────────────────────────
  function renderVisitCard(appt: FieldManagerMockAppointment) {
    const status = statusOverrides[appt.id] ?? appt.status;
    const tone = apptTypeTone[appt.appointmentType] ?? { bg: C.purple, color: C.purpleText };
    const foreman = fieldManagerForemen.find((f) => f.id === appt.foremanId);
    const statusTone: 'green' | 'blue' | 'amber' | 'red' = status === 'Complete' ? 'green' : status === 'Needs Review' ? 'red' : status === 'In Progress' ? 'amber' : 'blue';
    return (
      <Pressable key={appt.id} onPress={() => openVisit(appt.id)} style={{ backgroundColor: C.white, borderRadius: 10, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1, overflow: 'hidden' }}>
        {/* Header: navy with appt type + status */}
        <View style={{ backgroundColor: C.navy, paddingHorizontal: 14, paddingVertical: 10, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Text style={{ color: C.white, fontSize: 11, fontWeight: '600' }}>{appt.scheduledWindow}</Text>
          <View style={{ backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: 8, paddingHorizontal: 7, paddingVertical: 2 }}>
            <Text style={{ color: C.white, fontSize: 9, fontWeight: '600' }}>{status.toUpperCase()}</Text>
          </View>
        </View>
        {/* Body */}
        <View style={{ padding: 12, paddingHorizontal: 14 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <Text style={{ fontSize: 14, fontWeight: '600', color: C.navy }}>{appt.community} {appt.lot}</Text>
            <View style={{ backgroundColor: tone.bg, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2 }}>
              <Text style={{ fontSize: 9, fontWeight: '600', color: tone.color }}>{appt.appointmentType}</Text>
            </View>
          </View>
          <Text style={{ fontSize: 11, color: C.gray, marginBottom: 8 }}>{appt.address} · {appt.builder}</Text>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', borderTopWidth: 1, borderTopColor: C.border, paddingTop: 8 }}>
            <Text style={{ fontSize: 11, color: C.gray }}><Text style={{ color: C.navy, fontWeight: '600' }}>{appt.scheduledWindow.split(' - ')[0]}</Text> start</Text>
            <Text style={{ fontSize: 11, color: C.gray }}>{foreman?.crewLabel ?? 'Unassigned'}</Text>
            <Text style={{ fontSize: 11, color: C.gray }}>{appt.market}</Text>
          </View>
        </View>
        {/* Bottom strip */}
        <View style={{ backgroundColor: C.blueLight, paddingHorizontal: 14, paddingVertical: 6, flexDirection: 'row', alignItems: 'center', gap: 6, borderTopWidth: 1, borderTopColor: '#b5d4f4' }}>
          <Text style={{ fontSize: 10, color: '#0c447c' }}>👤 {foreman?.name ?? 'No foreman'} · {foreman?.truckLabel} · Tap to open</Text>
        </View>
      </Pressable>
    );
  }

  // ─── Foreman status card for crew board ──────────────────────────────────
  function renderForemanCard(foreman: FieldManagerForeman) {
    const health = healthOverrides[foreman.id] ?? foreman.healthCheckStatus;
    const statusColor = foreman.status === 'On Site' ? C.green : foreman.status === 'In Route' ? C.blue : C.red;
    const healthColor = healthColors[health];
    return (
      <Pressable key={foreman.id} onPress={() => openForeman(foreman.id)} style={{ backgroundColor: C.white, borderRadius: 10, marginBottom: 10, shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 3, shadowOffset: { width: 0, height: 1 }, elevation: 1, overflow: 'hidden' }}>
        <View style={{ backgroundColor: C.navy, paddingHorizontal: 14, paddingVertical: 10, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Text style={{ color: C.white, fontSize: 11, fontWeight: '600' }}>{foreman.crewLabel} · {foreman.truckLabel}</Text>
          <View style={{ backgroundColor: healthColor, borderRadius: 8, paddingHorizontal: 7, paddingVertical: 2 }}>
            <Text style={{ color: C.white, fontSize: 9, fontWeight: '600' }}>HEALTH: {health.toUpperCase()}</Text>
          </View>
        </View>
        <View style={{ padding: 12, paddingHorizontal: 14 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <Text style={{ fontSize: 14, fontWeight: '600', color: C.navy }}>{foreman.name}</Text>
            <View style={{ backgroundColor: statusColor, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2 }}>
              <Text style={{ fontSize: 9, fontWeight: '600', color: C.white }}>{foreman.status.toUpperCase()}</Text>
            </View>
            {foreman.openIssues > 0 ? (
              <View style={{ backgroundColor: C.redLight, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2, borderWidth: 1, borderColor: C.red }}>
                <Text style={{ fontSize: 9, fontWeight: '600', color: C.red }}>{foreman.openIssues} OPEN ISSUE{foreman.openIssues > 1 ? 'S' : ''}</Text>
              </View>
            ) : null}
          </View>
          <Text style={{ fontSize: 11, color: C.gray, marginBottom: 4 }}>📍 {foreman.currentAddress}</Text>
          <Text style={{ fontSize: 11, color: C.gray }}>Next: {foreman.nextStop}</Text>
        </View>
        <View style={{ backgroundColor: C.blueLight, paddingHorizontal: 14, paddingVertical: 6, borderTopWidth: 1, borderTopColor: '#b5d4f4' }}>
          <Text style={{ fontSize: 10, color: '#0c447c' }}>🏓 Ping {foreman.lastPing} · Tap to drill in</Text>
        </View>
      </Pressable>
    );
  }

  // ─── Screens ──────────────────────────────────────────────────────────────
  const completedVisits = Object.values(statusOverrides).filter((s) => s === 'Complete').length;
  const totalVisits = fieldManagerAppointments.length;
  const openIssues = fieldManagerForemen.reduce((sum, f) => sum + f.openIssues, 0);
  const redCrews = fieldManagerForemen.filter((f) => (healthOverrides[f.id] ?? f.healthCheckStatus) === 'Red').length;

  // My Day — FM service visit schedule
  if (screen === 'day') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'My Day', sub: `FM Dashboard · ${new Date().toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })}`, action: '🔔' })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {/* Glance summary */}
          {renderPCard(
            <>
              {renderCardTitle('📊 Today at a glance')}
              {renderTimeCapture([
                ['Service visits scheduled', `${totalVisits} stops`],
                ['Completed', `${completedVisits} of ${totalVisits}`, completedVisits === totalVisits ? C.green : C.navy],
                ['Crews under management', `${fieldManagerForemen.length} active`],
                ['Open crew issues', `${openIssues} flag${openIssues !== 1 ? 's' : ''}`, openIssues > 0 ? C.red : C.green],
                ['Red health checks', `${redCrews} crew${redCrews !== 1 ? 's' : ''}`, redCrews > 0 ? C.red : C.green]
              ])}
            </>,
            'ok'
          )}
          {/* Crew status overview */}
          {renderPCard(
            <>
              {renderCardTitle('👥 Crew board')}
              {fieldManagerForemen.map((f) => {
                const health = healthOverrides[f.id] ?? f.healthCheckStatus;
                const hColor = healthColors[health];
                return (
                  <Pressable key={f.id} onPress={() => openForeman(f.id)} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 6, borderBottomWidth: 1, borderBottomColor: C.border, gap: 8 }}>
                    <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: hColor }} />
                    <Text style={{ fontSize: 11, color: C.navy, fontWeight: '600', flex: 1 }}>{f.crewLabel}</Text>
                    <Text style={{ fontSize: 11, color: C.gray }}>{f.status}</Text>
                    {f.openIssues > 0 ? <View style={{ backgroundColor: C.redLight, borderRadius: 8, paddingHorizontal: 6, paddingVertical: 1 }}><Text style={{ fontSize: 9, color: C.red, fontWeight: '600' }}>{f.openIssues}⚠</Text></View> : null}
                  </Pressable>
                );
              })}
            </>
          )}
          {/* Visit schedule */}
          <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>
            Today's visits · {totalVisits} stops
          </Text>
          {fieldManagerAppointments.map(renderVisitCard)}
          {renderPCard(
            <>
              {renderCardTitle('📖 Field Manager — My Day', C.blue)}
              {renderCardSub('Your day runs differently from a foreman. You\'re salary — no time clock. Each stop is a service visit: Take-Off verification, QI review, Site Readiness check, Customer Care resolution, or Aqua check. You drive lot-to-lot inspecting work, solving problems, and keeping crews unblocked. Foremen flag issues to you; you decide whether to create a Finish Job work order. You don\'t lay sod — you make sure the right sod is on the right lot at the right time.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // Visit Detail — single service visit
  if (screen === 'visitDetail') {
    const appt = selectedAppt;
    const status = statusOverrides[appt.id] ?? appt.status;
    const foreman = fieldManagerForemen.find((f) => f.id === appt.foremanId);
    const tone = apptTypeTone[appt.appointmentType] ?? { bg: C.purple, color: C.purpleText };
    const checklistKey = (item: string) => `${appt.id}::${item}`;
    const completedItems = appt.focusChecklist.filter((item) => checklistDone[checklistKey(item)]).length;
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({
          title: `${appt.community} ${appt.lot}`,
          sub: `${appt.appointmentType} · ${appt.scheduledWindow}`,
          bg: C.navy,
          onBack: () => go('day'),
          action: 'Map'
        })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {/* Chips + details */}
          {renderPCard(
            <>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
                <View style={{ backgroundColor: tone.bg, borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2, marginRight: 4, marginBottom: 4 }}>
                  <Text style={{ fontSize: 10, fontWeight: '600', color: tone.color }}>{appt.appointmentType}</Text>
                </View>
                {renderPChip(status, status === 'Complete' ? 'green' : status === 'Needs Review' ? 'red' : status === 'In Progress' ? 'amber' : 'blue')}
                {renderPChip(appt.market, 'gray')}
                {appt.workOrderLabel ? renderPChip(appt.workOrderLabel, 'purple') : null}
              </View>
              {renderTimeCapture([
                ['Builder', appt.builder],
                ['Community / Lot', `${appt.community} ${appt.lot}`],
                ['Address', appt.address],
                ['Time window', appt.scheduledWindow],
                ['Foreman', foreman ? `${foreman.name} · ${foreman.crewLabel} · ${foreman.truckLabel}` : 'Unassigned'],
                ['Crew status', foreman?.status ?? '–']
              ])}
            </>
          )}
          {/* Visit notes */}
          {renderPCard(
            <>
              {renderCardTitle('📝 Visit focus notes')}
              {renderCardSub(appt.notes)}
            </>
          )}
          {/* Focus checklist */}
          {renderPCard(
            <>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                {renderCardTitle('✅ Visit focus checklist')}
                <View style={{ backgroundColor: completedItems === appt.focusChecklist.length ? C.greenLight : '#fef3c7', borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2 }}>
                  <Text style={{ fontSize: 10, fontWeight: '600', color: completedItems === appt.focusChecklist.length ? '#2e7d32' : '#92400e' }}>{completedItems} of {appt.focusChecklist.length}</Text>
                </View>
              </View>
              {appt.focusChecklist.map((item) => renderCheckItem(item, Boolean(checklistDone[checklistKey(item)]), () => setChecklistDone((p) => ({ ...p, [checklistKey(item)]: !p[checklistKey(item)] }))))}
            </>
          )}
          {/* Required photos */}
          <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>Required photos · {appt.requiredPhotos.length} needed</Text>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginBottom: 10 }}>
            {appt.requiredPhotos.map((cat) => renderPhotoTile(cat, '📷', false, () => Alert.alert('Photo', `Staging "${cat}" photo for ${appt.community} ${appt.lot}`)))}
          </View>
          {/* Closeout deliverables */}
          {renderPCard(
            <>
              {renderCardTitle('📋 Closeout deliverables')}
              {appt.closeoutDeliverables.map((d) => (
                <Text key={d} style={{ fontSize: 11, color: C.gray, paddingVertical: 2 }}>→ {d}</Text>
              ))}
            </>
          )}
          {/* Visit notes input */}
          {renderPCard(
            <>
              {renderCardTitle('📝 FM visit notes (optional)')}
              <TextInput
                placeholder="Add notes for this visit — what you observed, decisions made, follow-ups needed..."
                value={visitNote}
                onChangeText={setVisitNote}
                multiline
                style={{ backgroundColor: '#f4f6f9', padding: 10, borderRadius: 6, fontSize: 12, color: C.navy, minHeight: 80, lineHeight: 18, marginTop: 4 }}
                placeholderTextColor={C.gray}
              />
            </>
          )}
          {/* Actions */}
          {status !== 'In Progress' ? renderPBtn('▶ Start Visit', () => { setStatusOverrides((p) => ({ ...p, [appt.id]: 'In Progress' })); Alert.alert('Visit started', `${appt.appointmentType} is now In Progress.`); }, 'primary', 'huge') : null}
          {renderPBtn('⚠️ Flag Issue → FM Action', () => { setStatusOverrides((p) => ({ ...p, [appt.id]: 'Needs Review' })); go('issues'); }, 'warn')}
          {renderPBtn('✅ Complete Visit', () => { setStatusOverrides((p) => ({ ...p, [appt.id]: 'Complete' })); go('day'); }, 'success', 'huge')}
          {renderPBtn('View Assigned Foreman', () => { if (appt.foremanId) openForeman(appt.foremanId); }, 'outline')}
          {renderPCard(
            <>
              {renderCardTitle('📖 ' + appt.appointmentType + ' — what you\'re doing here', C.blue)}
              {{
                'Take-Offs': renderCardSub('You are confirming lot dimensions, access path, irrigation conflicts, and scope deltas BEFORE material release. Your approval here gates whether the crew can execute. If you find a delta from the plan set, note it and route scope changes before the crew shows up. No take-off sign-off = no material release.'),
                'Quality Inspection': renderCardSub('Post-install QI. You walk the lot after the crew closes: seam visibility, grade transitions, cleanup around curb and driveway, irrigation exposure. If anything fails, punch it here and route to the crew for correction. Your signature on this screen is what allows the WO to close and the invoice to generate.'),
                'Site Readiness': renderCardSub('48-hour pre-install check. Access gate open? Grade finished? Debris cleared? Irrigation sleeves flagged? Material staging zone clear? If the site isn\'t ready, you put the SA on hold and notify the builder. Crew doesn\'t drive to a site that can\'t receive them.'),
                'Customer Care': renderCardSub('You\'re resolving a homeowner or builder concern in the field. Document what you see, what the complaint is, and what the corrective path is. If it needs work, create a Customer Care WO. If it\'s a warranty item, note it and route to Customer Care (Erica\'s queue). Photo evidence is required before you leave the lot.'),
                'Aqua Check-Work Order': renderCardSub('Verify the irrigation system: run valves, check coverage, document pressure issues, log damaged heads. If anything requires additional work, update the related Aqua WO status. Your findings here trigger scheduling of the pick-up crew.'),
                'Aqua Pick-Up-Work Order': renderCardSub('Confirm all pickup scope items are addressed, inspect the site post-removal, capture any damage or carryover scope, and close or re-route the related WO. This screen is your closeout checkpoint before the Aqua job disappears from the schedule.')
              }[appt.appointmentType] ?? renderCardSub('Service visit in progress.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // Crews board
  if (screen === 'crews') {
    const completedTotal = fieldManagerAppointments.filter((a) => (statusOverrides[a.id] ?? a.status) === 'Complete').length;
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'Crew Board', sub: `${fieldManagerForemen.length} crews · live via WEX GPS` })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              {renderCardTitle('📊 Portfolio status')}
              {renderTimeCapture([
                ['Crews active today', `${fieldManagerForemen.length}`],
                ['On site', `${fieldManagerForemen.filter((f) => f.status === 'On Site').length}`, C.green],
                ['In route', `${fieldManagerForemen.filter((f) => f.status === 'In Route').length}`, C.blue],
                ['Needs review', `${fieldManagerForemen.filter((f) => f.status === 'Needs Review').length}`, C.red],
                ['Open issues across crews', `${fieldManagerForemen.reduce((s, f) => s + f.openIssues, 0)}`, openIssues > 0 ? C.red : C.green],
                ['Visits complete today', `${completedTotal} of ${totalVisits}`]
              ])}
            </>,
            'ok'
          )}
          {redCrews > 0 ? renderPCard(
            <>
              {renderCardTitle('🚨 Crews needing attention', '#991b1b')}
              {fieldManagerForemen.filter((f) => (healthOverrides[f.id] ?? f.healthCheckStatus) === 'Red').map((f) => (
                <Pressable key={f.id} onPress={() => openForeman(f.id)} style={{ paddingVertical: 4 }}>
                  <Text style={{ fontSize: 12, color: C.red, fontWeight: '600' }}>→ {f.name} · {f.crewLabel}: {f.healthCheckNote}</Text>
                </Pressable>
              ))}
            </>,
            'alert'
          ) : null}
          <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>Crews</Text>
          {fieldManagerForemen.map(renderForemanCard)}
          {renderPBtn('Open 2 PM Health Check', () => go('healthCheck'), 'primary')}
          {renderPCard(
            <>
              {renderCardTitle('📖 Crew Board', C.blue)}
              {renderCardSub('This is your real-time crew dashboard. Each card shows crew status (On Site / In Route / Needs Review), health check color, GPS ping time, and open issue count. Tap any crew card to drill into their current location, active job, and GPS history. WEX GPS pings every 3 minutes — if a crew goes dark for more than 10 minutes, the card shows a stale GPS warning. You manage this portfolio, not a single job.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // Foreman detail drill-in
  if (screen === 'foremanDetail') {
    const foreman = selectedForeman;
    const health = healthOverrides[foreman.id] ?? foreman.healthCheckStatus;
    const crewAppts = fieldManagerAppointments.filter((a) => a.foremanId === foreman.id);
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: foreman.name, sub: `${foreman.crewLabel} · ${foreman.truckLabel}`, bg: C.navy, onBack: () => go('crews'), action: '⋯' })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', marginBottom: 8 }}>
                {renderPChip(foreman.status, foreman.status === 'On Site' ? 'green' : foreman.status === 'In Route' ? 'blue' : 'red')}
                {renderPChip(`Health: ${health}`, health === 'Green' ? 'green' : health === 'Red' ? 'red' : 'amber')}
                {foreman.openIssues > 0 ? renderPChip(`${foreman.openIssues} open issue${foreman.openIssues > 1 ? 's' : ''}`, 'red') : renderPChip('No open issues', 'green')}
              </View>
              {renderTimeCapture([
                ['Crew', foreman.crewLabel],
                ['Truck', foreman.truckLabel],
                ['Current location', foreman.currentAddress],
                ['Last GPS ping', foreman.lastPing],
                ['Next stop', foreman.nextStop],
                ['Health check note', foreman.healthCheckNote]
              ])}
            </>
          )}
          {/* Health check update */}
          {renderPCard(
            <>
              {renderCardTitle('🏥 2PM Health Check')}
              {renderCardSub(`Current: ${health} — ${foreman.healthCheckNote}`)}
              <View style={{ flexDirection: 'row', gap: 8, marginTop: 8 }}>
                <Pressable
                  onPress={() => setHealthOverrides((p) => ({ ...p, [foreman.id]: 'Green' }))}
                  style={{ flex: 1, backgroundColor: C.green, borderRadius: 10, padding: 14, alignItems: 'center' }}
                >
                  <Text style={{ color: C.white, fontSize: 15, fontWeight: '700' }}>🟢{'\n'}GREEN{'\n'}<Text style={{ fontSize: 11, fontWeight: '500' }}>On track</Text></Text>
                </Pressable>
                <Pressable
                  onPress={() => { setHealthOverrides((p) => ({ ...p, [foreman.id]: 'Red' })); go('issues'); }}
                  style={{ flex: 1, backgroundColor: C.red, borderRadius: 10, padding: 14, alignItems: 'center' }}
                >
                  <Text style={{ color: C.white, fontSize: 15, fontWeight: '700' }}>🔴{'\n'}RED{'\n'}<Text style={{ fontSize: 11, fontWeight: '500' }}>Needs action</Text></Text>
                </Pressable>
              </View>
            </>
          )}
          {/* Crew's scheduled visits */}
          {crewAppts.length > 0 ? (
            <>
              <Text style={{ fontSize: 11, color: C.gray, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 6, marginLeft: 2 }}>Assigned visits</Text>
              {crewAppts.map((a) => {
                const astatus = statusOverrides[a.id] ?? a.status;
                return (
                  <Pressable key={a.id} onPress={() => openVisit(a.id)} style={{ backgroundColor: C.white, borderRadius: 8, padding: 12, marginBottom: 6, borderWidth: 1, borderColor: C.border }}>
                    <Text style={{ fontSize: 12, color: C.navy, fontWeight: '600' }}>{a.appointmentType} · {a.community} {a.lot}</Text>
                    <Text style={{ fontSize: 11, color: C.gray, marginTop: 2 }}>{a.scheduledWindow} · {astatus}</Text>
                  </Pressable>
                );
              })}
            </>
          ) : null}
          {renderPBtn('Open Issue Queue for This Crew', () => go('issues'), 'warn')}
          {renderPBtn('🗺 Open Crew Location in Maps', () => Alert.alert('Maps', `Opening: ${foreman.currentAddress}`), 'outline')}
          {renderPCard(
            <>
              {renderCardTitle('📖 Foreman drill-in', C.blue)}
              {renderCardSub(`${foreman.name} is your eyes on the ground. When they flag an issue, it lands in your Issues tab — you review it and decide whether to create a Finish Job WO, put the SA on hold, or mark it resolved. The health check is your 2PM pulse check: Green means they\'re tracking, Red means they need your intervention before the day closes. You don\'t create FJs from this screen — that happens in the Issues tab after reviewing their notes.`)}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // Map placeholder
  if (screen === 'map') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'Territory Map', sub: 'Crews + visits · live GPS', bg: C.blue })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {/* Map placeholder */}
          <View style={{ height: 280, borderRadius: 10, backgroundColor: '#d4e3f0', marginBottom: 10, overflow: 'hidden', position: 'relative' }}>
            <View style={{ position: 'absolute', top: '27%', left: 0, right: 0, height: 3, backgroundColor: '#a5b8c9' }} />
            <View style={{ position: 'absolute', top: '55%', left: 0, right: 0, height: 3, backgroundColor: '#a5b8c9' }} />
            <View style={{ position: 'absolute', left: '30%', top: 0, bottom: 0, width: 3, backgroundColor: '#a5b8c9' }} />
            <View style={{ position: 'absolute', left: '65%', top: 0, bottom: 0, width: 3, backgroundColor: '#a5b8c9' }} />
            <Text style={{ position: 'absolute', top: 10, left: 0, right: 0, textAlign: 'center', fontSize: 11, color: C.navy, fontWeight: '600' }}>Asheville Metro · FM Territory</Text>
            {/* Crew pins */}
            <View style={{ position: 'absolute', top: '38%', left: '18%', width: 20, height: 20, borderRadius: 10, backgroundColor: C.green, borderWidth: 2, borderColor: '#fff', alignItems: 'center', justifyContent: 'center' }}><Text style={{ fontSize: 9, color: '#fff', fontWeight: '700' }}>C4</Text></View>
            <View style={{ position: 'absolute', top: '22%', left: '52%', width: 20, height: 20, borderRadius: 10, backgroundColor: C.blue, borderWidth: 2, borderColor: '#fff', alignItems: 'center', justifyContent: 'center' }}><Text style={{ fontSize: 9, color: '#fff', fontWeight: '700' }}>C7</Text></View>
            <View style={{ position: 'absolute', top: '60%', left: '72%', width: 20, height: 20, borderRadius: 10, backgroundColor: C.red, borderWidth: 2, borderColor: '#fff', alignItems: 'center', justifyContent: 'center' }}><Text style={{ fontSize: 9, color: '#fff', fontWeight: '700' }}>C11</Text></View>
            {/* You */}
            <View style={{ position: 'absolute', top: '45%', left: '42%', width: 24, height: 24, borderRadius: 12, backgroundColor: C.navy, borderWidth: 3, borderColor: '#fff', alignItems: 'center', justifyContent: 'center' }}><Text style={{ fontSize: 9, color: '#fff', fontWeight: '700' }}>FM</Text></View>
          </View>
          {/* Legend */}
          {renderPCard(
            <>
              {renderCardTitle('📍 Map legend')}
              {[
                { color: C.green, label: 'Crew 04 · On Site · Brook Hollow L-18' },
                { color: C.blue, label: 'Crew 07 · In Route · Harbor North L-07' },
                { color: C.red, label: 'Crew 11 · Needs Review · Meadow View L-02' },
                { color: C.navy, label: 'You (FM) · Current location' }
              ].map(({ color, label }) => (
                <View key={label} style={{ flexDirection: 'row', alignItems: 'center', gap: 8, paddingVertical: 4 }}>
                  <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: color }} />
                  <Text style={{ fontSize: 11, color: C.gray }}>{label}</Text>
                </View>
              ))}
            </>
          )}
          {renderPCard(
            <>
              {renderCardTitle('📖 Territory map', C.blue)}
              {renderCardSub('The FM map shows all crews in your portfolio in real time. Green pins = on site and healthy. Blue pins = in route. Red pins = needs review or open issue. Your location (FM) is the navy pin. Tap any crew card on the Crews tab to drill into their GPS history and active job. WEX GPS updates every 3 minutes — you\'ll see the crew dot move as they progress across your territory.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // 2PM Health Check (this is the FM's version — they run the check)
  if (screen === 'healthCheck') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: '2 PM Health Check', sub: 'Required · Flag every crew Green or Red', bg: C.red, onBack: () => go('issues') })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              {renderCardTitle('🚨 Required action', '#991b1b')}
              {renderCardSub('Review each crew. Green = on track or ahead. Red = behind, blocked, or items can\'t complete today. Red crews trigger an alert to you and Megan\'s dashboard. You then create any Finish Job WOs for items that won\'t close today.')}
            </>,
            'alert'
          )}
          {fieldManagerForemen.map((foreman) => {
            const health = healthOverrides[foreman.id] ?? foreman.healthCheckStatus;
            return renderPCard(
              <>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <View style={{ flex: 1 }}>
                    {renderCardTitle(`${foreman.name} · ${foreman.crewLabel}`)}
                    {renderCardSub(`${foreman.status} · ${foreman.currentAddress}`)}
                  </View>
                  <View style={{ backgroundColor: healthColors[health], borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4 }}>
                    <Text style={{ color: C.white, fontSize: 11, fontWeight: '700' }}>{health}</Text>
                  </View>
                </View>
                {renderTimeCapture([
                  ['Next stop', foreman.nextStop],
                  ['Open issues', `${foreman.openIssues}`],
                  ['Note', foreman.healthCheckNote]
                ])}
                <View style={{ flexDirection: 'row', gap: 8, marginTop: 4 }}>
                  <Pressable
                    onPress={() => setHealthOverrides((p) => ({ ...p, [foreman.id]: 'Green' }))}
                    style={{ flex: 1, backgroundColor: health === 'Green' ? C.green : '#e8f5e9', borderRadius: 8, padding: 12, alignItems: 'center', borderWidth: 1, borderColor: C.green }}
                  >
                    <Text style={{ color: health === 'Green' ? C.white : '#2e7d32', fontWeight: '700', fontSize: 13 }}>🟢 GREEN</Text>
                  </Pressable>
                  <Pressable
                    onPress={() => setHealthOverrides((p) => ({ ...p, [foreman.id]: 'Red' }))}
                    style={{ flex: 1, backgroundColor: health === 'Red' ? C.red : C.redLight, borderRadius: 8, padding: 12, alignItems: 'center', borderWidth: 1, borderColor: C.red }}
                  >
                    <Text style={{ color: health === 'Red' ? C.white : '#991b1b', fontWeight: '700', fontSize: 13 }}>🔴 RED</Text>
                  </Pressable>
                </View>
              </>,
              health === 'Red' ? 'alert' : health === 'Yellow' ? 'warn' : 'ok'
            );
          })}
          {renderPCard(
            <>
              {renderCardTitle('📖 2 PM Health Check — FM role', C.blue)}
              {renderCardSub('This is your check — NOT the foreman\'s. Foremen in the Foreman app do not see a 2PM health check. YOU review each crew\'s pace and decide Green or Red. Red means you\'re flagging that crew for intervention. After marking Red, you\'ll create any necessary Finish Job WOs in the Issues tab — the foreman told you what\'s blocked, you decide the response. By 2 PM there\'s still 3 hours of daylight to act on Red crews. Catching it at 5 PM is too late.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // Issues / FJ decision queue
  if (screen === 'issues') {
    const flaggedCrews = fieldManagerForemen.filter((f) => f.openIssues > 0 || (healthOverrides[f.id] ?? f.healthCheckStatus) === 'Red');
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'Issues + FJ Queue', sub: 'Incoming flags from foremen · you decide', bg: C.navy })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPBtn('Open 2 PM Health Check', () => go('healthCheck'), 'danger', 'huge')}
          {renderPCard(
            <>
              {renderCardTitle('📊 Issue summary')}
              {renderTimeCapture([
                ['Total open issues', `${openIssues}`, openIssues > 0 ? C.red : C.green],
                ['Red health checks', `${redCrews}`, redCrews > 0 ? C.red : C.green],
                ['Crews flagged', `${flaggedCrews.length} of ${fieldManagerForemen.length}`]
              ])}
            </>,
            openIssues > 0 ? 'alert' : 'ok'
          )}
          {flaggedCrews.length === 0 ? renderPCard(
            <>
              {renderCardTitle('✅ No open issues', C.green)}
              {renderCardSub('All crews are clear. No Finish Job WOs needed at this time.')}
            </>,
            'ok'
          ) : null}
          {flaggedCrews.map((foreman) => {
            const health = healthOverrides[foreman.id] ?? foreman.healthCheckStatus;
            const noteKey = `issue-note-${foreman.id}`;
            return renderPCard(
              <>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 }}>
                  <View>
                    {renderCardTitle(`${foreman.name} · ${foreman.crewLabel}`, '#991b1b')}
                    {renderCardSub(foreman.healthCheckNote, '#991b1b')}
                  </View>
                  <View style={{ backgroundColor: healthColors[health], borderRadius: 8, paddingHorizontal: 6, paddingVertical: 3 }}>
                    <Text style={{ color: C.white, fontSize: 9, fontWeight: '700' }}>{health}</Text>
                  </View>
                </View>
                {renderTimeCapture([
                  ['Open issues', `${foreman.openIssues}`],
                  ['Location', foreman.currentAddress],
                  ['Next stop', foreman.nextStop]
                ])}
                <Text style={{ fontSize: 11, fontWeight: '600', color: C.navy, marginBottom: 4 }}>FM response notes</Text>
                <TextInput
                  placeholder="What action are you taking? Note your FJ decision, date, crew assignment..."
                  value={issueNotes[noteKey] ?? ''}
                  onChangeText={(t) => setIssueNotes((p) => ({ ...p, [noteKey]: t }))}
                  multiline
                  style={{ backgroundColor: '#f4f6f9', padding: 10, borderRadius: 6, fontSize: 12, color: C.navy, minHeight: 70, lineHeight: 18, marginBottom: 8 }}
                  placeholderTextColor={C.gray}
                />
                <View style={{ flexDirection: 'row', gap: 8 }}>
                  <Pressable
                    onPress={() => Alert.alert('FJ Created', `Finish Job work order queued for ${foreman.crewLabel}. Would assign crew and date in live app.`)}
                    style={{ flex: 1, backgroundColor: C.blue, borderRadius: 8, padding: 10, alignItems: 'center' }}
                  >
                    <Text style={{ color: C.white, fontSize: 12, fontWeight: '600' }}>Create FJ WO</Text>
                  </Pressable>
                  <Pressable
                    onPress={() => Alert.alert('Resolved', `Issue for ${foreman.crewLabel} marked resolved.`)}
                    style={{ flex: 1, backgroundColor: C.green, borderRadius: 8, padding: 10, alignItems: 'center' }}
                  >
                    <Text style={{ color: C.white, fontSize: 12, fontWeight: '600' }}>Mark Resolved</Text>
                  </Pressable>
                </View>
              </>,
              'alert'
            );
          })}
          {renderPCard(
            <>
              {renderCardTitle('📖 Issues + FJ Queue — FM role', C.blue)}
              {renderCardSub('Foremen identify what can\'t complete. You decide what to do about it. When a foreman taps "Flag Issue" in their app, it lands here. You review their notes, look at it from your portfolio view (other lots, crew availability, builder priorities), and either: (1) Create a Finish Job WO with scope, date, and crew assignment; (2) Mark resolved if it\'s not actually a FJ situation; or (3) Put on hold pending builder clearance. Foremen don\'t create FJs. You do. This split prevents scope creep and scheduling chaos.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // More / Settings
  if (screen === 'more') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
        <StatusBar style="light" />
        {renderFslHeader({ title: 'More', sub: 'Field Manager controls' })}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 12, paddingBottom: 12 }}>
          {renderPCard(
            <>
              {renderCardTitle('👤 Session info')}
              {renderTimeCapture([
                ['Role', 'Field Manager (salary)'],
                ['App', 'LOVING FM Mobile'],
                ['No time tracking', 'Salary · Rippling not active'],
                ['Crews managed', `${fieldManagerForemen.length}`],
                ['App version', '1.0.0']
              ])}
            </>
          )}
          {renderPCard(
            <>
              {renderCardTitle('FM rules', C.navy)}
              {renderCardSub('You are salary — no clock-in/clock-out, no Rippling sync. Your job is service visits, crew oversight, and issue resolution. You run the 2PM health check (foremen do not). You create Finish Job WOs. You own the portfolio view across all crews under you.')}
            </>,
            'blue'
          )}
          {renderPBtn('Open 2 PM Health Check', () => go('healthCheck'), 'primary')}
          {renderPBtn('Issue Queue + FJ Decisions', () => go('issues'), 'outline')}
          {renderPBtn('Back to Sign In', onSignOut, 'outline')}
          {renderPCard(
            <>
              {renderCardTitle('📖 About LOVING FM Mobile', C.blue)}
              {renderCardSub('Standalone Field Manager app for salaried FM team. Service visits (Take-Offs, QI, Site Readiness, Customer Care, Aqua) flow from your assigned ServiceAppointments. The 2PM Health Check is your responsibility — not the foreman\'s. Issue flags from foremen land in your Issues tab for FJ WO decisions. Photos, checklists, and visit notes sync to Salesforce. You don\'t track time — Rippling is for hourly crew only.')}
            </>,
            'blue'
          )}
        </ScrollView>
        {renderTabBar()}
      </SafeAreaView>
    );
  }

  // Fallback
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.bg }}>
      <StatusBar style="light" />
      {renderFslHeader({ title: 'LOVING FM Mobile', bg: C.navy })}
      <ScrollView contentContainerStyle={{ padding: 12 }}>
        {renderPCard(<><Text style={{ color: C.navy }}>Loading FM app...</Text></>)}
        {renderPBtn('Go to My Day', () => go('day'), 'primary')}
      </ScrollView>
    </SafeAreaView>
  );
}
