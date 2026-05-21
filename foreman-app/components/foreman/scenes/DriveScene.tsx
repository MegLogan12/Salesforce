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

export function DriveScene() {
  const day = useForeman(s => s.day);
  const goScene = useForeman(s => s.goScene);
  const selectedWorkOrder = useForeman(s => s.selectedWorkOrder);
  const wo = selectedWorkOrder();

  const address = wo?.address ?? day.workOrders[0]?.address ?? 'Job Site';
  const fm = wo?.fieldManager ?? day.workOrders[0]?.fieldManager;

  const sa = day.serviceAppointments.find(a => a.parentWorkOrderId === (wo?.id ?? day.selectedWorkOrderId));
  const scheduledStart = sa
    ? new Date(sa.scheduledStartIso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.heroCard}>
        <Text style={styles.sectionLabel}>Navigating To</Text>
        <Text style={styles.addressText}>{address}</Text>
        {wo && (
          <Text style={styles.woLabel}>{wo.woNumber} · {wo.subject}</Text>
        )}
        {scheduledStart && (
          <View style={styles.schedRow}>
            <View style={styles.schedBadge}>
              <Text style={styles.schedText}>🕐 Scheduled arrival: {scheduledStart}</Text>
            </View>
          </View>
        )}
        {fm && (
          <TouchableOpacity
            style={styles.callFmBtn}
            onPress={() => Linking.openURL(`tel:${fm.phone.replace(/\s/g, '')}`)}
            activeOpacity={0.8}
          >
            <Text style={styles.callFmText}>📞 Call FM · {fm.name}</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Directions */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Turn-by-Turn</Text>
        {day.directions.map((step, idx) => (
          <View key={idx} style={[styles.stepRow, idx < day.directions.length - 1 && styles.stepRowBorder]}>
            <View style={styles.stepIconWrap}>
              <Text style={styles.stepIcon}>{step.icon}</Text>
            </View>
            <View style={styles.stepBody}>
              <Text style={styles.stepInstruction}>{step.instruction}</Text>
              <Text style={styles.stepDistance}>{step.distance}</Text>
            </View>
            {idx === day.directions.length - 1 && (
              <View style={styles.destBadge}>
                <Text style={styles.destBadgeText}>DEST</Text>
              </View>
            )}
          </View>
        ))}
      </View>

      {/* Estimated time */}
      <View style={styles.etaCard}>
        <Text style={styles.etaLabel}>Estimated Drive Time</Text>
        <Text style={styles.etaValue}>~22 min</Text>
        <Text style={styles.etaSub}>Based on current traffic</Text>
      </View>

      {/* Arrived button */}
      <TouchableOpacity style={styles.arrivedBtn} onPress={() => goScene('arriving')} activeOpacity={0.85}>
        <Text style={styles.arrivedBtnText}>Mark Arrived 📍</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },
  heroCard: {
    backgroundColor: C.navy,
    borderRadius: 12,
    padding: 20,
    gap: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 6,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.5)',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  addressText: {
    fontSize: 20,
    fontWeight: '800',
    color: C.white,
    lineHeight: 26,
  },
  woLabel: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.65)',
  },
  schedRow: { flexDirection: 'row' },
  schedBadge: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  schedText: { fontSize: 12, color: 'rgba(255,255,255,0.8)', fontWeight: '600' },
  callFmBtn: {
    backgroundColor: C.blue,
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
    alignItems: 'center',
    marginTop: 4,
  },
  callFmText: { fontSize: 14, fontWeight: '700', color: C.white },
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
    gap: 4,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    gap: 12,
  },
  stepRowBorder: {
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  stepIconWrap: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: C.bg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepIcon: { fontSize: 18 },
  stepBody: { flex: 1, gap: 2 },
  stepInstruction: { fontSize: 14, fontWeight: '500', color: C.text },
  stepDistance: { fontSize: 12, color: C.muted },
  destBadge: {
    backgroundColor: C.green + '22',
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderWidth: 1,
    borderColor: C.green + '55',
  },
  destBadgeText: { fontSize: 10, fontWeight: '700', color: C.green },
  etaCard: {
    backgroundColor: C.white,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  etaLabel: { flex: 1, fontSize: 13, fontWeight: '600', color: C.muted },
  etaValue: { fontSize: 22, fontWeight: '800', color: C.text },
  etaSub: { fontSize: 11, color: C.muted },
  arrivedBtn: {
    backgroundColor: C.green,
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  arrivedBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
});
