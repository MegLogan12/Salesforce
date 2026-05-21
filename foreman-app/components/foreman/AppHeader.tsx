import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';

export function AppHeader({ insetTop = 0 }: { insetTop?: number }) {
  const name = useForeman(s => s.day.foremanName);
  const synced = useForeman(s => s.syncedAtIso);
  const today = new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  const syncTime = new Date(synced).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });

  return (
    <View style={[styles.header, { paddingTop: insetTop + 10 }]}>
      <View style={styles.brand}>
        <Text style={styles.logo}>LOVING</Text>
        <Text style={styles.sub}>Field App</Text>
      </View>
      <View style={styles.right}>
        <Text style={styles.name}>{name}</Text>
        <Text style={styles.date}>{today}</Text>
      </View>
      <View style={styles.syncIndicator}>
        <View style={styles.syncDot} />
        <Text style={styles.syncLabel}>{syncTime}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    backgroundColor: C.navy,
    paddingHorizontal: 16,
    paddingBottom: 12,
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 12,
  },
  brand: { flex: 1 },
  logo: { fontSize: 20, fontWeight: '800', color: C.white, letterSpacing: 2 },
  sub: { fontSize: 10, color: 'rgba(255,255,255,0.6)', letterSpacing: 1, marginTop: 1 },
  right: { alignItems: 'flex-end' },
  name: { fontSize: 13, fontWeight: '600', color: C.white },
  date: { fontSize: 11, color: 'rgba(255,255,255,0.6)', marginTop: 2 },
  syncIndicator: { alignItems: 'center', gap: 3 },
  syncDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: '#4ade80' },
  syncLabel: { fontSize: 9, color: 'rgba(255,255,255,0.45)', letterSpacing: 0.3 },
});
