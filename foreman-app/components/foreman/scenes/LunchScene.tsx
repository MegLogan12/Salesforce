import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';

function useLunchElapsed(startIso: string | null) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 15_000);
    return () => clearInterval(id);
  }, []);
  if (!startIso) return { mins: 0, display: '0m' };
  const mins = Math.floor((now - new Date(startIso).getTime()) / 60_000);
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return { mins, display: h > 0 ? `${h}h ${m}m` : `${m}m` };
}

export function LunchScene() {
  const day = useForeman(s => s.day);
  const endLunch = useForeman(s => s.endLunch);

  const { mins, display } = useLunchElapsed(day.lunchStartAt);

  const lunchStartDisplay = day.lunchStartAt
    ? new Date(day.lunchStartAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  const overThirty = mins >= 30;
  const overSixty = mins >= 60;

  return (
    <View style={styles.root}>
      {/* Hero */}
      <View style={styles.heroCard}>
        <Text style={styles.heroEmoji}>☀</Text>
        <Text style={styles.heroTitle}>Lunch Break</Text>
        {lunchStartDisplay && (
          <Text style={styles.heroSub}>Started at {lunchStartDisplay}</Text>
        )}
      </View>

      {/* Timer */}
      <View style={[styles.timerCard, overSixty && styles.timerCardWarn]}>
        <Text style={styles.timerLabel}>Elapsed</Text>
        <Text style={[styles.timerVal, overSixty && styles.timerValWarn]}>{display}</Text>
        {overThirty && !overSixty && (
          <Text style={styles.timerNote}>30 min passed — wrapping up soon?</Text>
        )}
        {overSixty && (
          <Text style={[styles.timerNote, styles.timerNoteWarn]}>Over 1 hour — ready to resume?</Text>
        )}
      </View>

      {/* Crew status */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew</Text>
        {day.crew.map(m => (
          <View key={m.id} style={styles.crewRow}>
            <View style={styles.crewDot} />
            <Text style={styles.crewName}>{m.name}</Text>
            <Text style={styles.crewStatusText}>On Break</Text>
          </View>
        ))}
      </View>

      {/* End lunch */}
      <TouchableOpacity style={styles.endBtn} onPress={endLunch} activeOpacity={0.85}>
        <Text style={styles.endBtnText}>End Lunch → Back to Work</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  heroCard: {
    backgroundColor: C.orange,
    borderRadius: 14,
    padding: 28,
    alignItems: 'center',
    gap: 6,
  },
  heroEmoji: { fontSize: 48 },
  heroTitle: { fontSize: 26, fontWeight: '800', color: C.white },
  heroSub: { fontSize: 13, color: 'rgba(255,255,255,0.75)' },

  timerCard: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 24,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    gap: 6,
  },
  timerCardWarn: { borderColor: C.red + '60', backgroundColor: C.red + '05' },
  timerLabel: { fontSize: 11, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 1 },
  timerVal: { fontSize: 56, fontWeight: '900', color: C.text },
  timerValWarn: { color: C.red },
  timerNote: { fontSize: 13, color: C.muted },
  timerNoteWarn: { color: C.red, fontWeight: '600' },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 8,
  },
  sectionLabel: { fontSize: 10, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 1 },
  crewRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 5 },
  crewDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: C.orange },
  crewName: { flex: 1, fontSize: 14, fontWeight: '500', color: C.text },
  crewStatusText: { fontSize: 12, fontWeight: '600', color: C.orange },

  endBtn: {
    backgroundColor: C.green,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  endBtnText: { fontSize: 16, fontWeight: '800', color: C.white },
});
