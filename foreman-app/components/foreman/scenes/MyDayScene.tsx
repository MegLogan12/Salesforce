import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Linking,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';
import type { SfCrewMember, SfWorkOrder } from '@/lib/foreman-types';

function crewStatusColor(status: SfCrewMember['status']): string {
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
    case 'Complete': return C.green;
    case 'On Hold': return C.red;
    case 'Awaiting QI': return C.orange;
    default: return C.muted;
  }
}

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

export function MyDayScene() {
  const day = useForeman(s => s.day);
  const goScene = useForeman(s => s.goScene);

  const totalHours = day.workOrders.reduce((sum, w) => sum + w.goalHours, 0);
  const sa = day.serviceAppointments[0];

  return (
    <View style={styles.root}>
      {sa && (
        <View style={styles.appointmentBlock}>
          <View style={styles.apptTimeRow}>
            <Text style={styles.apptTime}>{fmtTime(sa.scheduledStartIso)}</Text>
            <Text style={styles.apptTimeSep}> — </Text>
            <Text style={styles.apptTime}>{fmtTime(sa.scheduledEndIso)}</Text>
          </View>
          {day.workOrders[0] && (
            <>
              <Text style={styles.apptWoNum}>{day.workOrders[0].woNumber}</Text>
              <Text style={styles.apptAddr}>📍 {day.workOrders[0].address}</Text>
              <View style={styles.apptTypeBadge}>
                <Text style={styles.apptTypeBadgeText}>{day.workOrders[0].workOrderType}</Text>
              </View>
            </>
          )}
        </View>
      )}

      <View style={styles.statsRow}>
        <View style={styles.statCell}>
          <Text style={styles.statNum}>{day.workOrders.length}</Text>
          <Text style={styles.statLabel}>Work Orders</Text>
        </View>
        <View style={styles.statDivider} />
        <View style={styles.statCell}>
          <Text style={styles.statNum}>{day.crew.length}</Text>
          <Text style={styles.statLabel}>Crew</Text>
        </View>
        <View style={styles.statDivider} />
        <View style={styles.statCell}>
          <Text style={styles.statNum}>{totalHours}h</Text>
          <Text style={styles.statLabel}>Goal Hours</Text>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew Roster</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.crewScroll}>
          {day.crew.map(member => (
            <View key={member.id} style={styles.crewAvatarCol}>
              <View style={[styles.crewAvatar, { borderColor: crewStatusColor(member.status) }]}>
                <Text style={styles.crewInitial}>{member.name.split(' ').map(p => p.charAt(0)).join('')}</Text>
              </View>
              <View style={[styles.crewStatusDot, { backgroundColor: crewStatusColor(member.status) }]} />
              <Text style={styles.crewName}>{member.name.split(' ')[0]}</Text>
            </View>
          ))}
        </ScrollView>
      </View>

      {day.workOrders.map(wo => (
        <View key={wo.id} style={[styles.card, styles.woCard, { borderLeftColor: woTypeColor(wo.workOrderType) }]}>
          <View style={styles.woHeaderRow}>
            <View style={styles.woHeaderLeft}>
              <Text style={styles.woNumber}>{wo.woNumber}</Text>
              <View style={[styles.typePill, { backgroundColor: woTypeColor(wo.workOrderType) + '18', borderColor: woTypeColor(wo.workOrderType) + '50' }]}>
                <Text style={[styles.typePillText, { color: woTypeColor(wo.workOrderType) }]}>{wo.workOrderType}</Text>
              </View>
            </View>
            <View style={[styles.statusPill, { backgroundColor: subStatusColor(wo.subStatus) + '15', borderColor: subStatusColor(wo.subStatus) + '45' }]}>
              <Text style={[styles.statusPillText, { color: subStatusColor(wo.subStatus) }]}>{wo.subStatus}</Text>
            </View>
          </View>

          <Text style={styles.woSubject}>{wo.subject}</Text>
          <Text style={styles.woAddr}>📍 {wo.address}</Text>

          <View style={styles.woSpecsRow}>
            <Text style={styles.woSpec}>🌿 {wo.sodSqft.toLocaleString()} sq ft</Text>
            <Text style={styles.woSpec}>🌱 {wo.sodSpecies}</Text>
            <Text style={styles.woSpec}>⏱ {wo.goalHours}h goal</Text>
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

      <TouchableOpacity style={styles.ctaBtn} onPress={() => goScene('morning')} activeOpacity={0.85}>
        <Text style={styles.ctaBtnText}>Begin Morning Checklist →</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  appointmentBlock: {
    backgroundColor: C.navy,
    borderRadius: R.md,
    padding: 18,
    gap: 6,
    ...Sh.sm,
  },
  apptTimeRow: { flexDirection: 'row', alignItems: 'center' },
  apptTime: { fontSize: 22, fontWeight: '900', color: C.white },
  apptTimeSep: { fontSize: 18, color: 'rgba(255,255,255,0.4)', fontWeight: '300' },
  apptWoNum: { fontSize: 12, fontWeight: '700', color: 'rgba(255,255,255,0.45)', letterSpacing: 0.5 },
  apptAddr: { fontSize: 14, color: 'rgba(255,255,255,0.8)', fontWeight: '500' },
  apptTypeBadge: {
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(1,118,211,0.3)',
    borderRadius: R.xs,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderWidth: 1,
    borderColor: 'rgba(1,118,211,0.5)',
    marginTop: 2,
  },
  apptTypeBadgeText: { fontSize: 10, fontWeight: '700', color: '#7EC8FF' },

  statsRow: {
    flexDirection: 'row',
    backgroundColor: C.white,
    borderRadius: R.md,
    borderWidth: 1,
    borderColor: C.border,
    paddingVertical: 14,
    ...Sh.xs,
  },
  statCell: { flex: 1, alignItems: 'center' },
  statNum: { fontSize: 26, fontWeight: '900', color: C.text },
  statLabel: { fontSize: 10, color: C.muted, marginTop: 2, textTransform: 'uppercase', letterSpacing: 0.8 },
  statDivider: { width: 1, height: 38, backgroundColor: C.border },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    ...Sh.xs,
  },
  woCard: {
    borderLeftWidth: 4,
    paddingLeft: 14,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginBottom: 2,
  },

  crewScroll: { gap: 16, paddingRight: 4 },
  crewAvatarCol: { alignItems: 'center', gap: 5 },
  crewAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: C.navy,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2.5,
  },
  crewInitial: { fontSize: 14, fontWeight: '800', color: C.white },
  crewStatusDot: { width: 9, height: 9, borderRadius: 5, marginTop: -2 },
  crewName: { fontSize: 11, fontWeight: '600', color: C.text2 },

  woHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  woHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  woNumber: { fontSize: 11, fontWeight: '700', color: C.muted, letterSpacing: 0.4 },
  typePill: {
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: R.xs,
    borderWidth: 1,
  },
  typePillText: { fontSize: 10, fontWeight: '700' },
  statusPill: {
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: R.xs,
    borderWidth: 1,
  },
  statusPillText: { fontSize: 10, fontWeight: '700' },
  woSubject: { fontSize: 16, fontWeight: '700', color: C.text },
  woAddr: { fontSize: 13, color: C.muted },
  woSpecsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  woSpec: { fontSize: 13, color: C.text2, fontWeight: '500' },

  fmRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: C.border,
    paddingTop: 10,
    gap: 12,
  },
  fmInfo: { flex: 1, gap: 2 },
  fmLabel: { fontSize: 10, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.8 },
  fmName: { fontSize: 14, fontWeight: '700', color: C.text },
  fmRegion: { fontSize: 11, color: C.muted },
  callBtn: {
    backgroundColor: C.blue + '14',
    borderRadius: R.sm,
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderWidth: 1,
    borderColor: C.blue + '35',
  },
  callBtnText: { fontSize: 13, fontWeight: '700', color: C.blue },

  deliveryBadge: {
    backgroundColor: C.orange + '14',
    borderRadius: R.sm,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: C.orange + '35',
  },
  deliveryBadgeText: { fontSize: 12, fontWeight: '600', color: C.orange },

  ctaBtn: {
    backgroundColor: C.orange,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.sm,
  },
  ctaBtnText: { fontSize: 15, fontWeight: '800', color: C.white, letterSpacing: 0.2 },
});
