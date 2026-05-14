import React, { useMemo, useState } from 'react';
import { Linking, Pressable, ScrollView, Text, View } from 'react-native';
import { baseStyles } from '@/design/theme';
import { tokens } from '@/design/tokens';
import {
  fieldManagerAppointments,
  fieldManagerForemen,
  type FieldManagerForeman,
  type FieldManagerMockAppointment
} from '@/data/fieldManagerMock';
import { FieldButton } from '@/components/FieldButton';

type FieldManagerPanel = 'day' | 'appointment' | 'healthCheck' | 'foreman';

interface FieldManagerMockScreenProps {
  onBackToSignIn: () => void;
  onOpenSettings: () => void;
}

export function FieldManagerMockScreen({ onBackToSignIn, onOpenSettings }: FieldManagerMockScreenProps) {
  const [panel, setPanel] = useState<FieldManagerPanel>('day');
  const [selectedAppointmentId, setSelectedAppointmentId] = useState<string>(fieldManagerAppointments[0].id);
  const [selectedForemanId, setSelectedForemanId] = useState<string>(fieldManagerForemen[0].id);
  const [activityLog, setActivityLog] = useState<string[]>([
    'Mock only: field manager layout is not connected to live Salesforce yet.'
  ]);
  const [appointmentStatusOverrides, setAppointmentStatusOverrides] = useState<Record<string, FieldManagerMockAppointment['status']>>(
    {}
  );
  const [healthOverrides, setHealthOverrides] = useState<Record<string, FieldManagerForeman['healthCheckStatus']>>({});

  const selectedAppointment = useMemo(
    () =>
      fieldManagerAppointments.find((row) => row.id === selectedAppointmentId) ?? fieldManagerAppointments[0],
    [selectedAppointmentId]
  );
  const selectedForeman = useMemo(
    () => fieldManagerForemen.find((row) => row.id === selectedForemanId) ?? fieldManagerForemen[0],
    [selectedForemanId]
  );

  function appendLog(entry: string) {
    setActivityLog((prev) => [`${new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })} · ${entry}`, ...prev].slice(0, 8));
  }

  async function openMaps(address: string) {
    const encoded = encodeURIComponent(address);
    const appleUrl = `http://maps.apple.com/?q=${encoded}`;
    await Linking.openURL(appleUrl);
    appendLog(`Opened map handoff for ${address}`);
  }

  function openAppointment(appointmentId: string) {
    setSelectedAppointmentId(appointmentId);
    setPanel('appointment');
  }

  function openForeman(foremanId: string) {
    setSelectedForemanId(foremanId);
    setPanel('foreman');
  }

  function setAppointmentStatus(appointmentId: string, status: FieldManagerMockAppointment['status']) {
    setAppointmentStatusOverrides((prev) => ({ ...prev, [appointmentId]: status }));
  }

  function setHealthStatus(foremanId: string, status: FieldManagerForeman['healthCheckStatus']) {
    setHealthOverrides((prev) => ({ ...prev, [foremanId]: status }));
  }

  function statusTone(status: string) {
    if (status === 'Complete' || status === 'Green' || status === 'On Site') return tokens.color.green;
    if (status === 'Needs Review' || status === 'Yellow') return tokens.color.amber;
    if (status === 'Red') return tokens.color.red;
    return tokens.color.salesforceBlue;
  }

  function renderSegmentButton(label: string, nextPanel: FieldManagerPanel) {
    const active = panel === nextPanel;
    return (
      <Pressable
        onPress={() => setPanel(nextPanel)}
        style={{
          flex: 1,
          backgroundColor: active ? tokens.color.navy : '#ffffff',
          borderWidth: 1,
          borderColor: tokens.color.navy,
          borderRadius: tokens.radius.button,
          paddingVertical: tokens.spacing.sm,
          marginRight: tokens.spacing.sm
        }}
      >
        <Text style={{ textAlign: 'center', color: active ? '#ffffff' : tokens.color.navy, fontWeight: '700' }}>
          {label}
        </Text>
      </Pressable>
    );
  }

  function renderAppointmentCard(appointment: FieldManagerMockAppointment) {
    const foreman = fieldManagerForemen.find((row) => row.id === appointment.foremanId);
    const status = appointmentStatusOverrides[appointment.id] ?? appointment.status;
    return (
      <View
        key={appointment.id}
        style={[baseStyles.card, { borderWidth: 1, borderColor: tokens.color.border, marginBottom: tokens.spacing.md }]}
      >
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: tokens.spacing.sm }}>
          <View style={{ flex: 1 }}>
            <Text style={baseStyles.sectionTitle}>{appointment.appointmentType}</Text>
            <Text style={baseStyles.meta}>{appointment.title}</Text>
          </View>
          <View
            style={{
              alignSelf: 'flex-start',
              backgroundColor: statusTone(status),
              borderRadius: tokens.radius.badge,
              paddingHorizontal: tokens.spacing.md,
              paddingVertical: tokens.spacing.xs
            }}
          >
            <Text style={{ color: '#ffffff', fontWeight: '700' }}>{status}</Text>
          </View>
        </View>
        <Text style={[baseStyles.meta, { marginTop: tokens.spacing.sm }]}>Scheduled: {appointment.scheduledWindow}</Text>
        <Text style={baseStyles.meta}>Builder: {appointment.builder}</Text>
        <Text style={baseStyles.meta}>Community: {appointment.community}</Text>
        <Text style={baseStyles.meta}>Lot: {appointment.lot}</Text>
        <Text style={baseStyles.meta}>Address: {appointment.address}</Text>
        <Text style={baseStyles.meta}>Market: {appointment.market}</Text>
        <Text style={baseStyles.meta}>Foreman: {foreman?.name ?? 'Missing Data'} · {foreman?.crewLabel ?? 'Missing Crew'}</Text>
        {appointment.workOrderLabel ? <Text style={baseStyles.meta}>Related Work Order: {appointment.workOrderLabel}</Text> : null}
        <FieldButton label="Open Appointment" onPress={() => openAppointment(appointment.id)} />
        <FieldButton label="View Foreman / Crew" onPress={() => openForeman(appointment.foremanId)} />
      </View>
    );
  }

  function renderMyDay() {
    return (
      <View>
        <View style={[baseStyles.card, { backgroundColor: '#fff8e6', borderWidth: 1, borderColor: tokens.color.amber }]}>
          <Text style={baseStyles.sectionTitle}>Mock Only</Text>
          <Text style={baseStyles.meta}>
            Field Manager layout only. This screen is separate from the live Foreman workflow and is not using live service appointment data yet.
          </Text>
        </View>

        <View style={[baseStyles.card, { backgroundColor: tokens.color.navy }]}>
          <Text style={{ color: '#ffffff', fontSize: tokens.typography.sectionSize, fontWeight: '700' }}>2 PM Health Check</Text>
          <Text style={{ color: '#ffffff', marginTop: tokens.spacing.xs }}>
            Review crew pace, open issues, builder holds, and who needs follow-up before the afternoon window.
          </Text>
          <FieldButton label="Open 2 PM Health Check" onPress={() => setPanel('healthCheck')} />
        </View>

        {fieldManagerAppointments.map(renderAppointmentCard)}
      </View>
    );
  }

  function renderAppointmentDetail() {
    const foreman = fieldManagerForemen.find((row) => row.id === selectedAppointment.foremanId);
    const status = appointmentStatusOverrides[selectedAppointment.id] ?? selectedAppointment.status;
    return (
      <View style={baseStyles.card}>
        <Text style={baseStyles.sectionTitle}>{selectedAppointment.appointmentType}</Text>
        <Text style={baseStyles.meta}>{selectedAppointment.title}</Text>
        <Text style={[baseStyles.meta, { marginTop: tokens.spacing.sm }]}>Status: {status}</Text>
        <Text style={baseStyles.meta}>Scheduled: {selectedAppointment.scheduledWindow}</Text>
        <Text style={baseStyles.meta}>Builder: {selectedAppointment.builder}</Text>
        <Text style={baseStyles.meta}>Community: {selectedAppointment.community}</Text>
        <Text style={baseStyles.meta}>Lot: {selectedAppointment.lot}</Text>
        <Text style={baseStyles.meta}>Address: {selectedAppointment.address}</Text>
        <Text style={baseStyles.meta}>Market: {selectedAppointment.market}</Text>
        <Text style={baseStyles.meta}>Foreman: {foreman?.name ?? 'Missing Data'} · {foreman?.crewLabel ?? 'Missing Crew'}</Text>
        {selectedAppointment.workOrderLabel ? (
          <Text style={baseStyles.meta}>Related Work Order: {selectedAppointment.workOrderLabel}</Text>
        ) : null}
        <Text style={[baseStyles.meta, { marginTop: tokens.spacing.sm }]}>Notes: {selectedAppointment.notes}</Text>

        <Text style={[baseStyles.sectionTitle, { marginTop: tokens.spacing.lg }]}>Visit Focus</Text>
        {selectedAppointment.focusChecklist.map((item) => (
          <Text key={item} style={baseStyles.meta}>• {item}</Text>
        ))}

        <Text style={[baseStyles.sectionTitle, { marginTop: tokens.spacing.lg }]}>Required Photos</Text>
        {selectedAppointment.requiredPhotos.map((item) => (
          <Text key={item} style={baseStyles.meta}>• {item}</Text>
        ))}

        <Text style={[baseStyles.sectionTitle, { marginTop: tokens.spacing.lg }]}>Closeout Deliverables</Text>
        {selectedAppointment.closeoutDeliverables.map((item) => (
          <Text key={item} style={baseStyles.meta}>• {item}</Text>
        ))}

        <FieldButton
          label="Start Visit"
          onPress={() => {
            setAppointmentStatus(selectedAppointment.id, 'In Progress');
            appendLog(`${selectedAppointment.appointmentType} moved to In Progress.`);
          }}
        />
        <FieldButton label="Open Maps" onPress={() => void openMaps(selectedAppointment.address)} />
        <FieldButton
          label="Capture Photos"
          onPress={() => appendLog(`Required photos captured for ${selectedAppointment.appointmentType}.`)}
        />
        <FieldButton label="View Foreman / Crew" onPress={() => openForeman(selectedAppointment.foremanId)} />
        <FieldButton label="Open 2 PM Health Check" onPress={() => setPanel('healthCheck')} />
        <FieldButton
          label="Flag Builder / Crew Issue"
          onPress={() => {
            setAppointmentStatus(selectedAppointment.id, 'Needs Review');
            appendLog(`Issue flagged on ${selectedAppointment.appointmentType}.`);
          }}
        />
        <FieldButton
          label="Complete Visit"
          onPress={() => {
            setAppointmentStatus(selectedAppointment.id, 'Complete');
            appendLog(`${selectedAppointment.appointmentType} marked Complete.`);
          }}
        />
      </View>
    );
  }

  function renderHealthCheck() {
    return (
      <View style={baseStyles.card}>
        <Text style={baseStyles.sectionTitle}>2 PM Health Check</Text>
        <Text style={baseStyles.meta}>
          Field Manager review of crew location, pace, blockers, and who needs follow-up before closeout.
        </Text>
        {fieldManagerForemen.map((foreman) => {
          const health = healthOverrides[foreman.id] ?? foreman.healthCheckStatus;
          return (
            <View
              key={foreman.id}
              style={[baseStyles.card, { borderWidth: 1, borderColor: tokens.color.border, marginTop: tokens.spacing.md }]}
            >
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: tokens.spacing.sm }}>
                <View style={{ flex: 1 }}>
                  <Text style={baseStyles.sectionTitle}>{foreman.name}</Text>
                  <Text style={baseStyles.meta}>{foreman.crewLabel} · {foreman.truckLabel}</Text>
                </View>
                <View
                  style={{
                    alignSelf: 'flex-start',
                    backgroundColor: statusTone(health),
                    borderRadius: tokens.radius.badge,
                    paddingHorizontal: tokens.spacing.md,
                    paddingVertical: tokens.spacing.xs
                  }}
                >
                  <Text style={{ color: '#ffffff', fontWeight: '700' }}>{health}</Text>
                </View>
              </View>
              <Text style={baseStyles.meta}>Crew Status: {foreman.status}</Text>
              <Text style={baseStyles.meta}>Last Ping: {foreman.lastPing}</Text>
              <Text style={baseStyles.meta}>Current Location: {foreman.currentAddress}</Text>
              <Text style={baseStyles.meta}>Next Stop: {foreman.nextStop}</Text>
              <Text style={baseStyles.meta}>Open Issues: {foreman.openIssues}</Text>
              <Text style={baseStyles.meta}>Health Note: {foreman.healthCheckNote}</Text>
              <FieldButton label="Open Foreman / Crew" onPress={() => openForeman(foreman.id)} />
              <FieldButton
                label="Mark Green"
                onPress={() => {
                  setHealthStatus(foreman.id, 'Green');
                  appendLog(`2 PM health check marked Green for ${foreman.name}.`);
                }}
              />
              <FieldButton
                label="Needs Follow-Up"
                onPress={() => {
                  setHealthStatus(foreman.id, 'Red');
                  appendLog(`2 PM health check escalated for ${foreman.name}.`);
                }}
              />
            </View>
          );
        })}
      </View>
    );
  }

  function renderForemanDetail() {
    const activeAppointment =
      fieldManagerAppointments.find((row) => row.foremanId === selectedForeman.id) ?? fieldManagerAppointments[0];
    const health = healthOverrides[selectedForeman.id] ?? selectedForeman.healthCheckStatus;
    return (
      <View style={baseStyles.card}>
        <Text style={baseStyles.sectionTitle}>{selectedForeman.name}</Text>
        <Text style={baseStyles.meta}>{selectedForeman.crewLabel} · {selectedForeman.truckLabel}</Text>
        <Text style={baseStyles.meta}>Crew Status: {selectedForeman.status}</Text>
        <Text style={baseStyles.meta}>Current Location: {selectedForeman.currentAddress}</Text>
        <Text style={baseStyles.meta}>Last Ping: {selectedForeman.lastPing}</Text>
        <Text style={baseStyles.meta}>Next Stop: {selectedForeman.nextStop}</Text>
        <Text style={baseStyles.meta}>Open Issues: {selectedForeman.openIssues}</Text>
        <Text style={baseStyles.meta}>2 PM Health Check: {health}</Text>
        <Text style={baseStyles.meta}>Health Note: {selectedForeman.healthCheckNote}</Text>

        <Text style={[baseStyles.sectionTitle, { marginTop: tokens.spacing.lg }]}>Current Appointment</Text>
        <Text style={baseStyles.meta}>{activeAppointment.appointmentType}</Text>
        <Text style={baseStyles.meta}>{activeAppointment.address}</Text>
        <Text style={baseStyles.meta}>{activeAppointment.scheduledWindow}</Text>

        <FieldButton label="Open Current Appointment" onPress={() => openAppointment(activeAppointment.id)} />
        <FieldButton label="Open Current Location" onPress={() => void openMaps(selectedForeman.currentAddress)} />
        <FieldButton label="Open 2 PM Health Check" onPress={() => setPanel('healthCheck')} />
        <FieldButton label="Log Follow-Up" onPress={() => appendLog(`Follow-up logged for ${selectedForeman.name}.`)} />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={{ paddingBottom: 24 }}>
      <View style={{ flexDirection: 'row', marginBottom: tokens.spacing.md }}>
        {renderSegmentButton('My Day', 'day')}
        {renderSegmentButton('2 PM Check', 'healthCheck')}
        {renderSegmentButton('Foreman', 'foreman')}
      </View>

      {panel === 'day' && renderMyDay()}
      {panel === 'appointment' && renderAppointmentDetail()}
      {panel === 'healthCheck' && renderHealthCheck()}
      {panel === 'foreman' && renderForemanDetail()}

      <View style={baseStyles.card}>
        <Text style={baseStyles.sectionTitle}>Mock Action Log</Text>
        {activityLog.map((entry) => (
          <Text key={entry} style={baseStyles.meta}>• {entry}</Text>
        ))}
      </View>

      <View style={baseStyles.card}>
        <FieldButton label="Open Settings" onPress={onOpenSettings} />
        <FieldButton label="Back to App Selection" onPress={onBackToSignIn} />
      </View>
    </ScrollView>
  );
}
