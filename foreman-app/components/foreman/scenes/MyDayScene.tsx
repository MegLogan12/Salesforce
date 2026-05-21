import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Linking,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
import type { SfCrewMember, SfWorkOrder } from '@/lib/foreman-types';

function crewChipColor(status: SfCrewMember['status']): string {
  switch (status) {
    case 'Clocked In': return C.green;
    case 'Confirmed': return C.orange;
    case 'On Break': return C.red;
    case 'Clocked Out': return C.muted;
  }
}

function woTypeColor(type: SfWorkOrder['workOrderType']): string {
  switch (type) {
    case 'Sod Install': return C.green;
    case 'Sod Repair': return C.orange;
    case 'Fertilization': return C.blue;
    case 'Mowing': return C.purple;
    case 'Tree': return '#7b5e35';
    default: return C.muted;
  }
}

function subStatusColor(status: SfWorkOrder['subStatus']): string {
  switch (status) {
    case 'In Progress': return C.blue;
    case 'Complete':    return C.green;
    case 'On Hold':     return C.red;
    case 'Awaiting QI': return C.orange;
    default:            return C.muted;
  }
}

export function MyDayScene() {
  const day = useForeman(s => s.day);
  const goScene = useForeman(s => s.goScene);

  const totalHours = day.workOrders.reduce((sum, w) => sum + w.goalHours, 0);

  return (
    <View style={styles.root}>
      {/* Summary card */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Today's Assignment</Text>
        <View style={styles.summaryRow}>
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{day.workOrders.length}</Text>
            <Text style={styles.statSub}>Work Orders</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{day.crew.length}</Text>
            <Text style={styles.statSub}>Crew</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{totalHours}h</Text>
            <Text style={styles.statSub}>Goal</Text>
          </View>
        </View>
        <View style={styles.depotRow}>
          <Text style={styles.depotLabel}>🏭 Depot</Text>
          <Text style={styles.depotText}>{day.depot}</Text>
        </View>
      </View>

      {/* Crew Roster */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew Roster</Text>
        {day.crew.map(member => (
          <View key={member.id} style={styles.crewRow}>
            <View style={styles.crewAvatar}>
              <Text style={styles.crewInitial}>{member.name.charAt(0)}</Text>
            </View>
            <Text style={styles.crewName}>{member.name}</Text>
            <View style={[styles.chip, { backgroundColor: crewChipColor(member.status) + '22', borderColor: crewChipColor(member.status) + '55' }]}>
              <Text style={[styles.chipText, { color: crewChipColor(member.status) }]}>{member.status}</Text>
            </View>
          </View>
        ))}
      </View>

      {/* Work Orders */}
      <Text style={styles.sectionLabel}>Work Orders</Text>
      {day.workOrders.map(wo => (
        <View key={wo.id} style={styles.card}>
          <View style={styles.woHeader}>
            <View style={styles.woHeaderLeft}>
              <Text style={styles.woNumber}>{wo.woNumber}</Text>
              <View style={[styles.chip, { backgroundColor: woTypeColor(wo.workOrderType) + '22', borderColor: woTypeColor(wo.workOrderType) + '55' }]}>
                <Text style={[styles.chipText, { color: woTypeColor(wo.workOrderType) }]}>{wo.workOrderType}</Text>
              </View>
            </View>
            <View style={[styles.chip, { backgroundColor: subStatusColor(wo.subStatus) + '22', borderColor: subStatusColor(wo.subStatus) + '55' }]}>
              <Text style={[styles.chipText, { color: subStatusColor(wo.subStatus) }]}>{wo.subStatus}</Text>
            </View>
          </View>

          <Text style={styles.woSubject}>{wo.subject}</Text>
          <Text style={styles.woAddress}>📍 {wo.address}</Text>

          <View style={styles.woStats}>
            <Text style={styles.woStat}>🌿 {wo.sodSqft.toLocaleString()} sq ft</Text>
            <Text style={styles.woStat}>🌱 {wo.sodSpecies}</Text>
            <Text style={styles.woStat}>⏱ {wo.goalHours}h goal</Text>
          </View>

          <View style={styles.fmRow}>
            <View style={styles.fmInfo}>
              <Text style={styles.fmLabel}>Field Manager</Text>
              <Text style={styles.fmName}>{wo.fieldManager.name}</Text>
              <Text style={styles.fmRegion}>{wo.fieldManager.region}</Text>
            </View>
            <TouchableOpacity
              style={styles.callBtn}
              onPress={() => Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
            >
              <Text style={styles.callBtnText}>📞 Call FM</Text>
            </TouchableOpacity>
          </View>

          {wo.deliveries.length > 0 && (
            <View style={styles.deliveryBadge}>
              <Text style={styles.deliveryBadgeText}>📦 {wo.deliveries.length} delivery line{wo.deliveries.length > 1 ? 's' : ''} expected</Text>
            </View>
          )}
        </View>
      ))}

      {/* Service Appointments */}
      {day.serviceAppointments.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.sectionLabel}>Service Appointments</Text>
          {day.serviceAppointments.map(sa => (
            <View key={sa.id} style={styles.saRow}>
              <View style={styles.saTime}>
                <Text style={styles.saTimeText}>
                  {new Date(sa.scheduledStartIso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
                </Text>
                <Text style={styles.saTimeSep}>–</Text>
                <Text style={styles.saTimeText}>
                  {new Date(sa.scheduledEndIso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
                </Text>
              </View>
              <View style={styles.saInfo}>
                <Text style={styles.saId}>{sa.id}</Text>
                <Text style={styles.saResource}>{sa.resourceName}</Text>
              </View>
              <View style={[styles.chip, { backgroundColor: C.blue + '22', borderColor: C.blue + '55' }]}>
                <Text style={[styles.chipText, { color: C.blue }]}>{sa.status}</Text>
              </View>
            </View>
          ))}
        </View>
      )}

      {/* CTA */}
      <TouchableOpacity style={styles.primaryBtn} onPress={() => goScene('morning')} activeOpacity={0.85}>
        <Text style={styles.primaryBtnText}>Start Morning Checklist →</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },
  card: {
    backgroundColor: C.white,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    gap: 10,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 2,
  },
  summaryRow: { flexDirection: 'row', alignItems: 'center' },
  statBlock: { flex: 1, alignItems: 'center' },
  statNum: { fontSize: 28, fontWeight: '800', color: C.text },
  statSub: { fontSize: 11, color: C.muted, marginTop: 2 },
  statDivider: { width: 1, height: 36, backgroundColor: C.border },
  depotRow: { flexDirection: 'row', alignItems: 'center', gap: 8, borderTopWidth: 1, borderTopColor: C.border, paddingTop: 10 },
  depotLabel: { fontSize: 12, color: C.muted, fontWeight: '600' },
  depotText: { fontSize: 13, fontWeight: '600', color: C.text, flex: 1 },
  crewRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 4 },
  crewAvatar: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: C.navy,
    alignItems: 'center',
    justifyContent: 'center',
  },
  crewInitial: { fontSize: 14, fontWeight: '700', color: C.white },
  crewName: { flex: 1, fontSize: 14, fontWeight: '500', color: C.text },
  chip: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
    borderWidth: 1,
  },
  chipText: { fontSize: 10, fontWeight: '700' },
  woHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  woHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  woNumber: { fontSize: 12, fontWeight: '700', color: C.muted },
  woSubject: { fontSize: 16, fontWeight: '700', color: C.text },
  woAddress: { fontSize: 13, color: C.muted },
  woStats: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  woStat: { fontSize: 13, color: C.text, fontWeight: '500' },
  fmRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: C.border,
    paddingTop: 10,
    gap: 12,
  },
  fmInfo: { flex: 1, gap: 2 },
  fmLabel: { fontSize: 10, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.5 },
  fmName: { fontSize: 14, fontWeight: '700', color: C.text },
  fmRegion: { fontSize: 11, color: C.muted },
  callBtn: {
    backgroundColor: C.blue + '15',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: C.blue + '40',
  },
  callBtnText: { fontSize: 13, fontWeight: '700', color: C.blue },
  deliveryBadge: {
    backgroundColor: C.orange + '15',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: C.orange + '40',
  },
  deliveryBadgeText: { fontSize: 12, fontWeight: '600', color: C.orange },
  saRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 4 },
  saTime: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  saTimeText: { fontSize: 12, fontWeight: '600', color: C.text },
  saTimeSep: { fontSize: 11, color: C.muted },
  saInfo: { flex: 1, gap: 2 },
  saId: { fontSize: 11, fontWeight: '600', color: C.muted },
  saResource: { fontSize: 13, fontWeight: '600', color: C.text },
  primaryBtn: {
    backgroundColor: C.blue,
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  primaryBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
});
