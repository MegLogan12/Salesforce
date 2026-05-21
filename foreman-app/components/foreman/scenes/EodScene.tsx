import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Linking } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';

export function EodScene() {
  const day = useForeman(s => s.day);
  const clockOut = useForeman(s => s.clockOut);
  const resetDay = useForeman(s => s.resetDay);

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
      {/* Completion banner */}
      <View style={[styles.banner, clocked ? styles.bannerDone : styles.bannerPending]}>
        <Text style={styles.bannerIcon}>{clocked ? '🏁' : '⏳'}</Text>
        <Text style={styles.bannerTitle}>{clocked ? 'Day Complete' : 'Job Closed'}</Text>
        <Text style={styles.bannerSub}>
          {clocked ? 'Clock-out confirmed — great work today.' : 'Clock out when you\'re back at depot.'}
        </Text>
      </View>

      {/* Job summary */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Job Summary</Text>
        {wo && (
          <>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Work Order</Text>
              <Text style={styles.summaryVal}>{wo.woNumber}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Site</Text>
              <Text style={styles.summaryVal}>{wo.subject}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Type</Text>
              <Text style={styles.summaryVal}>{wo.workOrderType}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Sq Ft</Text>
              <Text style={styles.summaryVal}>{wo.sodSqft.toLocaleString()}</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Status</Text>
              <Text style={[styles.summaryVal, { color: statusColor }]}>{subStatus}</Text>
            </View>
            {hoursOnJob && (
              <View style={styles.summaryRow}>
                <Text style={styles.summaryLabel}>Hours on Job</Text>
                <Text style={styles.summaryVal}>{hoursOnJob}h</Text>
              </View>
            )}
          </>
        )}
      </View>

      {/* Time card */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Time Card</Text>
        <View style={styles.timeRow}>
          <View style={styles.timeBlock}>
            <Text style={styles.timeLabel}>Clock In</Text>
            <Text style={styles.timeVal}>{clockedIn}</Text>
          </View>
          <View style={styles.timeArrow}><Text style={styles.timeArrowText}>→</Text></View>
          <View style={styles.timeBlock}>
            <Text style={styles.timeLabel}>Clock Out</Text>
            <Text style={[styles.timeVal, !clockedOut && { color: C.muted }]}>
              {clockedOut ?? '—'}
            </Text>
          </View>
        </View>
      </View>

      {/* Photos */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Photos Captured</Text>
        <View style={styles.photoStats}>
          <View style={styles.photoStat}>
            <Text style={styles.photoStatNum}>{totalPhotos}</Text>
            <Text style={styles.photoStatLabel}>Total</Text>
          </View>
          <View style={styles.photoStat}>
            <Text style={styles.photoStatNum}>{progressPhotos}</Text>
            <Text style={styles.photoStatLabel}>Progress</Text>
          </View>
          <View style={styles.photoStat}>
            <Text style={styles.photoStatNum}>{afterPhotos}</Text>
            <Text style={styles.photoStatLabel}>After</Text>
          </View>
        </View>
      </View>

      {/* Crew */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew</Text>
        {day.crew.map(m => (
          <View key={m.id} style={styles.crewRow}>
            <View style={styles.crewAvatar}>
              <Text style={styles.crewInitial}>{m.name.charAt(0)}</Text>
            </View>
            <Text style={styles.crewName}>{m.name}</Text>
            <View style={styles.crewDone}><Text style={styles.crewDoneText}>✓</Text></View>
          </View>
        ))}
      </View>

      {/* Clock out */}
      {!clocked ? (
        <TouchableOpacity style={styles.clockOutBtn} onPress={clockOut} activeOpacity={0.85}>
          <Text style={styles.clockOutBtnText}>Clock Out</Text>
        </TouchableOpacity>
      ) : (
        <View style={styles.clockedConfirm}>
          <Text style={styles.clockedConfirmText}>✓ Clocked out at {clockedOut}</Text>
        </View>
      )}

      {/* Field manager */}
      {wo?.fieldManager && (
        <TouchableOpacity
          style={styles.fmBtn}
          onPress={() => Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
          activeOpacity={0.8}
        >
          <Text style={styles.fmBtnText}>📞 Call {wo.fieldManager.name}</Text>
        </TouchableOpacity>
      )}

      {/* Reset (dev) */}
      <TouchableOpacity style={styles.resetBtn} onPress={resetDay} activeOpacity={0.7}>
        <Text style={styles.resetBtnText}>Reset Day (Demo)</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  banner: {
    borderRadius: 14,
    padding: 24,
    alignItems: 'center',
    gap: 6,
  },
  bannerDone: { backgroundColor: C.green },
  bannerPending: { backgroundColor: C.navy },
  bannerIcon: { fontSize: 40 },
  bannerTitle: { fontSize: 26, fontWeight: '900', color: C.white },
  bannerSub: { fontSize: 13, color: 'rgba(255,255,255,0.7)', textAlign: 'center' },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  sectionLabel: { fontSize: 10, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 1 },

  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 5,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  summaryLabel: { fontSize: 13, color: C.muted },
  summaryVal: { fontSize: 13, fontWeight: '600', color: C.text, flex: 1, textAlign: 'right' },

  timeRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 16 },
  timeBlock: { alignItems: 'center', gap: 4 },
  timeLabel: { fontSize: 11, color: C.muted, fontWeight: '600' },
  timeVal: { fontSize: 22, fontWeight: '800', color: C.text },
  timeArrow: { alignItems: 'center' },
  timeArrowText: { fontSize: 22, color: C.muted },

  photoStats: { flexDirection: 'row', justifyContent: 'space-around' },
  photoStat: { alignItems: 'center', gap: 3 },
  photoStatNum: { fontSize: 28, fontWeight: '800', color: C.text },
  photoStatLabel: { fontSize: 11, color: C.muted },

  crewRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 4 },
  crewAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: C.navy,
    alignItems: 'center',
    justifyContent: 'center',
  },
  crewInitial: { fontSize: 13, fontWeight: '700', color: C.white },
  crewName: { flex: 1, fontSize: 14, fontWeight: '500', color: C.text },
  crewDone: { backgroundColor: C.green + '20', borderRadius: 12, width: 24, height: 24, alignItems: 'center', justifyContent: 'center' },
  crewDoneText: { fontSize: 13, color: C.green, fontWeight: '700' },

  clockOutBtn: {
    backgroundColor: C.red,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  clockOutBtnText: { fontSize: 16, fontWeight: '800', color: C.white },

  clockedConfirm: {
    backgroundColor: C.green + '15',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.green + '40',
  },
  clockedConfirmText: { fontSize: 15, fontWeight: '700', color: C.green },

  fmBtn: {
    backgroundColor: C.blue + '10',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.blue + '30',
  },
  fmBtnText: { fontSize: 14, fontWeight: '700', color: C.blue },

  resetBtn: {
    backgroundColor: C.bg,
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  resetBtnText: { fontSize: 12, color: C.muted },
});
