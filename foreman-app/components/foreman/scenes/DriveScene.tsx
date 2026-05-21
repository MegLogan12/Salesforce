import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Linking,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

function useEta(scheduledStartIso: string | null): string {
  const [now] = useState(Date.now());
  if (!scheduledStartIso) return '—';
  const diff = new Date(scheduledStartIso).getTime() - now;
  if (diff <= 0) return 'Arriving now';
  const mins = Math.round(diff / 60_000);
  if (mins < 60) return `~${mins} min`;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return m > 0 ? `~${h}h ${m}m` : `~${h}h`;
}

export function DriveScene() {
  const day = useForeman(s => s.day);
  const goScene = useForeman(s => s.goScene);
  const selectedWorkOrder = useForeman(s => s.selectedWorkOrder);
  const wo = selectedWorkOrder();

  const address = wo?.address ?? day.workOrders[0]?.address ?? 'Job Site';
  const fm = wo?.fieldManager ?? day.workOrders[0]?.fieldManager;

  const sa = day.serviceAppointments.find(
    a => a.parentWorkOrderId === (wo?.id ?? day.selectedWorkOrderId)
  );

  const scheduledStart = sa
    ? new Date(sa.scheduledStartIso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  const eta = useEta(sa?.scheduledStartIso ?? null);

  return (
    <View style={styles.root}>
      <View style={styles.heroCard}>
        <Text style={styles.heroLabel}>NAVIGATING TO</Text>
        <Text style={styles.heroAddress}>{address}</Text>
        {wo && (
          <Text style={styles.heroWoLabel}>{wo.woNumber} · {wo.subject}</Text>
        )}
        {scheduledStart && (
          <View style={styles.schedBadge}>
            <Text style={styles.schedBadgeLabel}>SCHEDULED ARRIVAL</Text>
            <Text style={styles.schedBadgeTime}>{scheduledStart}</Text>
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

      <View style={styles.etaCard}>
        <View style={styles.etaLeft}>
          <Text style={styles.etaLabel}>Estimated Drive Time</Text>
          <Text style={styles.etaSub}>Based on scheduled start</Text>
        </View>
        <Text style={styles.etaValue}>{eta}</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Turn-by-Turn</Text>
        {day.directions.map((step, idx) => (
          <View
            key={idx}
            style={[styles.stepRow, idx < day.directions.length - 1 && styles.stepRowBorder]}
          >
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

      <TouchableOpacity
        style={styles.arrivedBtn}
        onPress={() => goScene('arriving')}
        activeOpacity={0.85}
      >
        <Text style={styles.arrivedBtnText}>I've Arrived 📍</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  heroCard: {
    backgroundColor: C.navy,
    borderRadius: R.md,
    padding: 20,
    gap: 8,
    ...Sh.md,
  },
  heroLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.4)',
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  heroAddress: {
    fontSize: 22,
    fontWeight: '900',
    color: C.white,
    lineHeight: 28,
  },
  heroWoLabel: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.55)',
  },
  schedBadge: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: R.sm,
    paddingHorizontal: 12,
    paddingVertical: 8,
    alignSelf: 'flex-start',
    gap: 1,
    marginTop: 2,
  },
  schedBadgeLabel: {
    fontSize: 9,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.45)',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  schedBadgeTime: {
    fontSize: 18,
    fontWeight: '900',
    color: C.white,
  },
  callFmBtn: {
    backgroundColor: C.blue,
    borderRadius: R.sm,
    paddingHorizontal: 14,
    paddingVertical: 10,
    alignItems: 'center',
    marginTop: 4,
  },
  callFmText: { fontSize: 14, fontWeight: '700', color: C.white },

  etaCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    ...Sh.xs,
  },
  etaLeft: { flex: 1 },
  etaLabel: { fontSize: 13, fontWeight: '600', color: C.text },
  etaSub: { fontSize: 11, color: C.muted, marginTop: 2 },
  etaValue: { fontSize: 26, fontWeight: '900', color: C.navy },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 4,
    ...Sh.xs,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginBottom: 6,
  },
  stepRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    gap: 12,
  },
  stepRowBorder: {
    borderBottomWidth: 1,
    borderBottomColor: C.divider,
  },
  stepIconWrap: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: C.bg,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  stepIcon: { fontSize: 17 },
  stepBody: { flex: 1, gap: 2 },
  stepInstruction: { fontSize: 14, fontWeight: '500', color: C.text },
  stepDistance: { fontSize: 12, color: C.muted },
  destBadge: {
    backgroundColor: C.green + '20',
    borderRadius: R.xs,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderWidth: 1,
    borderColor: C.green + '50',
  },
  destBadgeText: { fontSize: 10, fontWeight: '700', color: C.green },

  arrivedBtn: {
    backgroundColor: C.green,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.sm,
  },
  arrivedBtnText: { fontSize: 16, fontWeight: '800', color: C.white },
});
