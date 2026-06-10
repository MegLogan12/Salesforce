import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Linking } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

export function EodScene() {
  const day = useForeman(s => s.day);
  const clockOut = useForeman(s => s.clockOut);

  const wo = day.workOrders.find(w => w.id === day.selectedWorkOrderId);
  const sa = day.serviceAppointments.find(a => a.parentWorkOrderId === day.selectedWorkOrderId);

  const totalPhotos = day.photos.length;
  const progressPhotos = day.photos.filter(p => p.category === 'progress').length;
  const afterPhotos = day.photos.filter(p => p.category === 'after' || p.category === 'hero-after').length;

  const clockedIn = day.clockedInAt
    ? new Date(day.clockedInAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : '—';
  const clockedOut = day.clockedOutAt
    ? new Date(day.clockedOutAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  const jobStarted = day.jobStartedAt ? new Date(day.jobStartedAt) : null;
  const jobEnded = sa?.status === 'Completed' && day.clockedOutAt ? new Date(day.clockedOutAt) : null;
  const hoursOnJob = jobStarted && jobEnded
    ? ((jobEnded.getTime() - jobStarted.getTime()) / 3_600_000).toFixed(1)
    : null;

  const subStatus = wo?.subStatus ?? '—';
  const statusColor = subStatus === 'Awaiting QI' ? C.orange
    : subStatus === 'Complete' ? C.green
    : subStatus === 'On Hold' ? C.red
    : C.muted;

  const clocked = !!day.clockedOutAt;

  return (
    <View style={styles.root}>
      {clocked ? (
        <View style={styles.bannerDone}>
          <Text style={styles.bannerEmoji}>🏁</Text>
          <Text style={styles.bannerTitle}>Day Complete</Text>
          <Text style={styles.bannerSub}>Clock-out confirmed — great work today.</Text>
        </View>
      ) : (
        <View style={styles.bannerPending}>
          <Text style={styles.bannerEmoji}>⏳</Text>
          <Text style={styles.bannerTitle}>Job Closed</Text>
          <Text style={styles.bannerSub}>Clock out when you're back at depot.</Text>
        </View>
      )}

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Job Summary</Text>
        {wo && (
          <>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryKey}>Work Order</Text>
              <Text style={styles.summaryVal}>{wo.woNumber}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryKey}>Site</Text>
              <Text style={styles.summaryVal}>{wo.subject}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryKey}>Type</Text>
              <Text style={styles.summaryVal}>{wo.workOrderType}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryKey}>Sq Ft</Text>
              <Text style={styles.summaryVal}>{wo.sodSqft.toLocaleString()}</Text>
            </View>
            <View style={[styles.summaryRow, styles.summaryRowLast]}>
              <Text style={styles.summaryKey}>Status</Text>
              <Text style={[styles.summaryVal, { color: statusColor, fontWeight: '700' }]}>{subStatus}</Text>
            </View>
            {hoursOnJob && (
              <View style={[styles.summaryRow, styles.summaryRowLast]}>
                <Text style={styles.summaryKey}>Hours on Job</Text>
                <Text style={styles.summaryVal}>{hoursOnJob}h</Text>
              </View>
            )}
          </>
        )}
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Time Card</Text>
        <View style={styles.timeCardRow}>
          <View style={styles.timeBlock}>
            <Text style={styles.timeBlockLabel}>CLOCK IN</Text>
            <Text style={styles.timeBlockVal}>{clockedIn}</Text>
          </View>
          <View style={styles.timeArrow}>
            <Text style={styles.timeArrowText}>→</Text>
          </View>
          <View style={styles.timeBlock}>
            <Text style={styles.timeBlockLabel}>CLOCK OUT</Text>
            <Text style={[styles.timeBlockVal, !clockedOut && styles.timeBlockValEmpty]}>
              {clockedOut ?? '—'}
            </Text>
          </View>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Photos Captured</Text>
        <View style={styles.photoStats}>
          <View style={styles.photoStatCell}>
            <Text style={styles.photoStatNum}>{totalPhotos}</Text>
            <Text style={styles.photoStatLabel}>Total</Text>
          </View>
          <View style={styles.photoStatDivider} />
          <View style={styles.photoStatCell}>
            <Text style={styles.photoStatNum}>{progressPhotos}</Text>
            <Text style={styles.photoStatLabel}>Progress</Text>
          </View>
          <View style={styles.photoStatDivider} />
          <View style={styles.photoStatCell}>
            <Text style={styles.photoStatNum}>{afterPhotos}</Text>
            <Text style={styles.photoStatLabel}>After</Text>
          </View>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew</Text>
        {day.crew.map(m => (
          <View key={m.id} style={styles.crewRow}>
            <View style={styles.crewAvatar}>
              <Text style={styles.crewInitial}>{m.name.charAt(0)}</Text>
            </View>
            <Text style={styles.crewName}>{m.name}</Text>
            <View style={styles.crewDoneBadge}>
              <Text style={styles.crewDoneText}>✓ Done</Text>
            </View>
          </View>
        ))}
      </View>

      {!clocked ? (
        <TouchableOpacity style={styles.clockOutBtn} onPress={clockOut} activeOpacity={0.85}>
          <Text style={styles.clockOutBtnText}>Clock Out</Text>
        </TouchableOpacity>
      ) : (
        <View style={styles.clockedConfirm}>
          <Text style={styles.clockedConfirmText}>✓ Clocked out at {clockedOut}</Text>
        </View>
      )}

      {wo?.fieldManager && (
        <TouchableOpacity
          style={styles.fmBtn}
          onPress={() => Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
          activeOpacity={0.8}
        >
          <Text style={styles.fmBtnText}>📞 Call {wo.fieldManager.name}</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  bannerDone: {
    backgroundColor: C.green,
    borderRadius: R.md,
    padding: 24,
    alignItems: 'center',
    gap: 6,
    ...Sh.sm,
  },
  bannerPending: {
    backgroundColor: C.navy,
    borderRadius: R.md,
    padding: 24,
    alignItems: 'center',
    gap: 6,
    ...Sh.sm,
  },
  bannerEmoji: { fontSize: 38 },
  bannerTitle: { fontSize: 26, fontWeight: '900', color: C.white },
  bannerSub: { fontSize: 13, color: 'rgba(255,255,255,0.65)', textAlign: 'center' },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 6,
    ...Sh.xs,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginBottom: 4,
  },

  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: C.divider,
  },
  summaryRowLast: { borderBottomWidth: 0 },
  summaryKey: { fontSize: 13, color: C.muted },
  summaryVal: { fontSize: 13, fontWeight: '600', color: C.text, textAlign: 'right', flex: 1, marginLeft: 12 },

  timeCardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
    paddingVertical: 8,
  },
  timeBlock: { alignItems: 'center', gap: 4 },
  timeBlockLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },
  timeBlockVal: { fontSize: 26, fontWeight: '900', color: C.text },
  timeBlockValEmpty: { color: C.subtle },
  timeArrow: {},
  timeArrowText: { fontSize: 22, color: C.muted },

  photoStats: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-around', paddingVertical: 6 },
  photoStatCell: { flex: 1, alignItems: 'center', gap: 3 },
  photoStatNum: { fontSize: 28, fontWeight: '900', color: C.text },
  photoStatLabel: { fontSize: 11, color: C.muted },
  photoStatDivider: { width: 1, height: 36, backgroundColor: C.border },

  crewRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 5 },
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
  crewDoneBadge: {
    backgroundColor: C.green + '18',
    borderRadius: R.xs,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderWidth: 1,
    borderColor: C.green + '40',
  },
  crewDoneText: { fontSize: 11, fontWeight: '700', color: C.green },

  clockOutBtn: {
    backgroundColor: C.red,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.sm,
  },
  clockOutBtnText: { fontSize: 16, fontWeight: '900', color: C.white },

  clockedConfirm: {
    backgroundColor: C.green + '14',
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: C.green + '35',
  },
  clockedConfirmText: { fontSize: 15, fontWeight: '700', color: C.green },

  fmBtn: {
    backgroundColor: C.blue + '0F',
    borderRadius: R.md,
    height: 50,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: C.blue + '30',
  },
  fmBtnText: { fontSize: 14, fontWeight: '700', color: C.blue },
});
