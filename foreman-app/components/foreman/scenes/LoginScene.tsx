import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

function getGreeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

export function LoginScene() {
  const foremanName = useForeman(s => s.day.foremanName);
  const lang = useForeman(s => s.lang);
  const toggleLang = useForeman(s => s.toggleLang);
  const goScene = useForeman(s => s.goScene);
  const workOrders = useForeman(s => s.day.workOrders);
  const crew = useForeman(s => s.day.crew);
  const day = useForeman(s => s.day);

  const greeting = lang === 'en' ? getGreeting() : 'Buenos días';
  const firstWO = workOrders[0];
  const todayFormatted = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });

  return (
    <View style={styles.root}>
      <View style={styles.langRow}>
        <TouchableOpacity
          style={[styles.langBtn, lang === 'en' && styles.langBtnActive]}
          onPress={() => toggleLang()}
        >
          <Text style={[styles.langText, lang === 'en' && styles.langTextActive]}>EN</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.langBtn, lang === 'es' && styles.langBtnActive]}
          onPress={() => toggleLang()}
        >
          <Text style={[styles.langText, lang === 'es' && styles.langTextActive]}>ES</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.greetingArea}>
        <Text style={styles.greeting}>{greeting},</Text>
        <Text style={styles.foremanName}>{foremanName}</Text>
        <Text style={styles.dateText}>{todayFormatted}</Text>
      </View>

      <View style={styles.sfBadge}>
        <View style={styles.sfDotOuter}>
          <View style={styles.sfDot} />
        </View>
        <View style={styles.sfBadgeBody}>
          <Text style={styles.sfBadgeTitle}>Salesforce Connected</Text>
          <Text style={styles.sfBadgeSub}>LOVING Production Org · Synced</Text>
        </View>
        <Text style={styles.sfBadgeIcon}>☁</Text>
      </View>

      <View style={styles.summaryCard}>
        <Text style={styles.sectionLabel}>Today's Assignment</Text>

        <View style={styles.summaryRow}>
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{workOrders.length}</Text>
            <Text style={styles.statLabel}>{lang === 'en' ? 'Work Orders' : 'Órdenes'}</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{crew.length}</Text>
            <Text style={styles.statLabel}>{lang === 'en' ? 'Crew' : 'Tripulantes'}</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{firstWO?.goalHours ?? 0}h</Text>
            <Text style={styles.statLabel}>{lang === 'en' ? 'Goal' : 'Meta'}</Text>
          </View>
        </View>

        {firstWO && (
          <View style={styles.firstJobRow}>
            <Text style={styles.firstJobLabel}>FIRST JOB</Text>
            <Text style={styles.firstJobAddr}>{firstWO.address}</Text>
            <View style={styles.woTypePill}>
              <Text style={styles.woTypeText}>{firstWO.workOrderType}</Text>
            </View>
            {firstWO.sodSqft > 0 && (
              <Text style={styles.sqftText}>{firstWO.sodSqft.toLocaleString()} sq ft · {firstWO.sodSpecies}</Text>
            )}
          </View>
        )}

        {day.clockedInAt && (
          <View style={styles.clockRow}>
            <Text style={styles.clockLabel}>Clock In</Text>
            <Text style={styles.clockTime}>
              {new Date(day.clockedInAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
            </Text>
          </View>
        )}
      </View>

      <View style={styles.depotCard}>
        <Text style={styles.depotEmoji}>🏭</Text>
        <View style={styles.depotBody}>
          <Text style={styles.depotLabel}>Depot</Text>
          <Text style={styles.depotAddr}>{day.depot}</Text>
        </View>
      </View>

      <TouchableOpacity
        style={styles.startBtn}
        onPress={() => goScene('myDay')}
        activeOpacity={0.85}
      >
        <Text style={styles.startBtnText}>
          {lang === 'en' ? 'Start My Day →' : 'Iniciar Mi Día →'}
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: C.navy,
    padding: 20,
    paddingTop: 16,
  },
  langRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 6,
    marginBottom: 24,
  },
  langBtn: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: R.sm,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.18)',
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
  langBtnActive: {
    backgroundColor: C.blue,
    borderColor: C.blue,
  },
  langText: { fontSize: 12, fontWeight: '700', color: 'rgba(255,255,255,0.5)' },
  langTextActive: { color: C.white },
  greetingArea: { marginBottom: 20 },
  greeting: { fontSize: 18, fontWeight: '400', color: 'rgba(255,255,255,0.55)' },
  foremanName: { fontSize: 34, fontWeight: '900', color: C.white, marginTop: 2, letterSpacing: -0.5 },
  dateText: { fontSize: 13, color: 'rgba(255,255,255,0.4)', marginTop: 4 },
  sfBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: 'rgba(46,132,74,0.18)',
    borderRadius: R.md,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: 'rgba(46,132,74,0.35)',
  },
  sfDotOuter: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: 'rgba(46,132,74,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sfDot: { width: 9, height: 9, borderRadius: 5, backgroundColor: C.green },
  sfBadgeBody: { flex: 1 },
  sfBadgeTitle: { fontSize: 13, color: C.green, fontWeight: '700' },
  sfBadgeSub: { fontSize: 11, color: 'rgba(46,132,74,0.8)', marginTop: 1 },
  sfBadgeIcon: { fontSize: 18, opacity: 0.6 },
  summaryCard: {
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    marginBottom: 12,
    gap: 12,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.4)',
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },
  summaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statBlock: { flex: 1, alignItems: 'center' },
  statNum: { fontSize: 30, fontWeight: '900', color: C.white },
  statLabel: { fontSize: 11, color: 'rgba(255,255,255,0.45)', marginTop: 2 },
  statDivider: { width: 1, height: 36, backgroundColor: 'rgba(255,255,255,0.12)' },
  firstJobRow: {
    gap: 4,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.1)',
    paddingTop: 12,
  },
  firstJobLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.4)',
    letterSpacing: 1.2,
  },
  firstJobAddr: { fontSize: 15, fontWeight: '600', color: C.white },
  woTypePill: {
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(1,118,211,0.25)',
    borderRadius: R.sm,
    paddingHorizontal: 8,
    paddingVertical: 3,
    marginTop: 2,
    borderWidth: 1,
    borderColor: 'rgba(1,118,211,0.4)',
  },
  woTypeText: { fontSize: 10, fontWeight: '700', color: '#7EC8FF' },
  sqftText: { fontSize: 12, color: 'rgba(255,255,255,0.45)', marginTop: 2 },
  clockRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: 'rgba(255,255,255,0.1)',
    paddingTop: 10,
  },
  clockLabel: { fontSize: 12, color: 'rgba(255,255,255,0.45)' },
  clockTime: { fontSize: 14, fontWeight: '800', color: C.green },
  depotCard: {
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: R.md,
    padding: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 28,
  },
  depotEmoji: { fontSize: 20 },
  depotBody: { flex: 1 },
  depotLabel: { fontSize: 10, fontWeight: '700', color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: 1 },
  depotAddr: { fontSize: 13, fontWeight: '600', color: 'rgba(255,255,255,0.8)', marginTop: 2 },
  startBtn: {
    backgroundColor: C.orange,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.md,
  },
  startBtnText: { fontSize: 16, fontWeight: '800', color: C.white, letterSpacing: 0.3 },
});
