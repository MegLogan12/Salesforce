import React, { useRef, useEffect, useState } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh } from '@/constants/loving';

function LiveClock() {
  const [time, setTime] = useState(
    new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  );
  useEffect(() => {
    const tick = () =>
      setTime(new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }));
    const id = setInterval(tick, 30_000);
    return () => clearInterval(id);
  }, []);
  return <Text style={s.clock}>{time}</Text>;
}

function SyncDot() {
  const pulse = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 0.25, duration: 1100, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 1, duration: 1100, useNativeDriver: true }),
      ])
    ).start();
  }, []);
  return (
    <View style={s.syncRow}>
      <Animated.View style={[s.syncDot, { opacity: pulse }]} />
      <Text style={s.syncLabel}>Live</Text>
    </View>
  );
}

function subStatusBg(status: string): string {
  switch (status) {
    case 'In Progress': return C.orange;
    case 'Complete': return C.green;
    case 'On Hold': return C.red;
    case 'Awaiting QI': return '#7F5AF0';
    default: return 'rgba(255,255,255,0.2)';
  }
}

export function AppHeader({ insetTop = 0 }: { insetTop?: number }) {
  const name = useForeman(s => s.day.foremanName);
  const scene = useForeman(s => s.scene);
  const wo = useForeman(s => s.selectedWorkOrder)();

  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });

  const showWO = ['arriving', 'active', 'lunch', 'closeout', 'measuring', 'flag'].includes(scene) && wo;

  return (
    <View style={[s.header, { paddingTop: insetTop + 10 }]}>
      <View style={s.topRow}>
        <View style={s.brand}>
          <Text style={s.logo}>LOVING</Text>
          <View style={s.fieldBadge}><Text style={s.fieldBadgeText}>FIELD</Text></View>
        </View>
        <View style={s.rightCluster}>
          <SyncDot />
          <LiveClock />
        </View>
      </View>

      <View style={s.bottomRow}>
        <View>
          <Text style={s.foremanName}>{name}</Text>
          <Text style={s.dateText}>{today}</Text>
        </View>
        {showWO && (
          <View style={s.woPill}>
            <Text style={s.woPillNum}>{wo.woNumber}</Text>
            <View style={[s.woPillStatus, { backgroundColor: subStatusBg(wo.subStatus) }]}>
              <Text style={s.woPillStatusText}>{wo.subStatus}</Text>
            </View>
          </View>
        )}
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  header: {
    backgroundColor: C.navy,
    paddingHorizontal: 16,
    paddingBottom: 14,
    gap: 10,
    ...Sh.md,
  },
  topRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  logo: { fontSize: 22, fontWeight: '900', color: C.white, letterSpacing: 3 },
  fieldBadge: { backgroundColor: C.orange, borderRadius: 4, paddingHorizontal: 6, paddingVertical: 2 },
  fieldBadgeText: { fontSize: 9, fontWeight: '800', color: C.white, letterSpacing: 1.5 },
  rightCluster: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  syncRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  syncDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: '#4ade80' },
  syncLabel: { fontSize: 10, fontWeight: '700', color: 'rgba(255,255,255,0.45)', letterSpacing: 0.5 },
  clock: { fontSize: 13, fontWeight: '600', color: 'rgba(255,255,255,0.65)' },
  bottomRow: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between' },
  foremanName: { fontSize: 16, fontWeight: '700', color: C.white },
  dateText: { fontSize: 11, color: 'rgba(255,255,255,0.4)', marginTop: 1 },
  woPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.15)',
  },
  woPillNum: { fontSize: 11, fontWeight: '700', color: 'rgba(255,255,255,0.85)' },
  woPillStatus: { borderRadius: 3, paddingHorizontal: 5, paddingVertical: 1 },
  woPillStatusText: { fontSize: 9, fontWeight: '800', color: C.white, letterSpacing: 0.3 },
});
