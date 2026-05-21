import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

function useLunchElapsed(startIso: string | null) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 60_000);
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
      <View style={styles.heroCard}>
        <View style={styles.heroTopRow}>
          <Text style={styles.heroEmoji}>☀</Text>
          <Text style={styles.heroTitle}>Lunch Break</Text>
        </View>
        {lunchStartDisplay && (
          <Text style={styles.heroSub}>Started at {lunchStartDisplay}</Text>
        )}
        <Text style={styles.heroNote}>All crew are on break</Text>
      </View>

      <View style={[styles.timerCard, overSixty && styles.timerCardWarn]}>
        <Text style={styles.timerLabel}>ELAPSED</Text>
        <Text style={[styles.timerVal, overSixty && styles.timerValWarn]}>{display}</Text>
        {overThirty && !overSixty && (
          <Text style={styles.timerNote}>30 min passed — wrapping up soon?</Text>
        )}
        {overSixty && (
          <Text style={[styles.timerNote, styles.timerNoteWarn]}>Over 1 hour — ready to resume?</Text>
        )}
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew Status</Text>
        {day.crew.map(m => (
          <View key={m.id} style={styles.crewRow}>
            <View style={styles.crewAvatar}>
              <Text style={styles.crewInitial}>{m.name.charAt(0)}</Text>
            </View>
            <Text style={styles.crewName}>{m.name}</Text>
            <View style={styles.breakBadge}>
              <View style={styles.breakDot} />
              <Text style={styles.breakBadgeText}>On Break</Text>
            </View>
          </View>
        ))}
      </View>

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
    borderRadius: R.md,
    padding: 24,
    gap: 6,
    ...Sh.sm,
  },
  heroTopRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  heroEmoji: { fontSize: 32 },
  heroTitle: { fontSize: 26, fontWeight: '900', color: C.white },
  heroSub: { fontSize: 13, color: 'rgba(255,255,255,0.75)' },
  heroNote: { fontSize: 12, color: 'rgba(255,255,255,0.6)', fontWeight: '500' },

  timerCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    paddingVertical: 28,
    paddingHorizontal: 20,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    gap: 6,
    ...Sh.xs,
  },
  timerCardWarn: { borderColor: C.red + '55', backgroundColor: C.red + '04' },
  timerLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.5,
  },
  timerVal: { fontSize: 72, fontWeight: '900', color: C.text, lineHeight: 80 },
  timerValWarn: { color: C.red },
  timerNote: { fontSize: 13, color: C.muted, textAlign: 'center' },
  timerNoteWarn: { color: C.red, fontWeight: '600' },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 8,
    ...Sh.xs,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },
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
  breakBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: C.orange + '14',
    borderRadius: R.xs,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderWidth: 1,
    borderColor: C.orange + '35',
  },
  breakDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: C.orange },
  breakBadgeText: { fontSize: 11, fontWeight: '700', color: C.orange },

  endBtn: {
    backgroundColor: C.green,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.sm,
  },
  endBtnText: { fontSize: 16, fontWeight: '900', color: C.white },
});
