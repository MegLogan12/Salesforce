import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';

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
    year: 'numeric',
  });

  return (
    <View style={styles.root}>
      {/* Language toggle */}
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

      {/* Greeting */}
      <View style={styles.greetingArea}>
        <Text style={styles.greeting}>{greeting},</Text>
        <Text style={styles.foremanName}>{foremanName}</Text>
        <Text style={styles.dateText}>{todayFormatted}</Text>
      </View>

      {/* SF Connected badge */}
      <View style={styles.sfBadge}>
        <View style={styles.sfDot} />
        <Text style={styles.sfText}>Salesforce Connected · LOVING Production</Text>
      </View>

      {/* Today's summary card */}
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
            <Text style={styles.statLabel}>{lang === 'en' ? 'Crew Members' : 'Tripulantes'}</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statBlock}>
            <Text style={styles.statNum}>{firstWO?.goalHours ?? 0}h</Text>
            <Text style={styles.statLabel}>{lang === 'en' ? 'Goal' : 'Meta'}</Text>
          </View>
        </View>

        {firstWO && (
          <View style={styles.firstJobRow}>
            <Text style={styles.firstJobLabel}>📍 First Job</Text>
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
            <Text style={styles.clockLabel}>⏰ Clocked in (Rippling)</Text>
            <Text style={styles.clockTime}>
              {new Date(day.clockedInAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
            </Text>
          </View>
        )}
      </View>

      {/* Depot */}
      <View style={styles.depotCard}>
        <Text style={styles.depotLabel}>🏭 Depot</Text>
        <Text style={styles.depotAddr}>{day.depot}</Text>
      </View>

      {/* CTA */}
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
    backgroundColor: C.bg,
    padding: 20,
    paddingTop: 16,
  },
  langRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 6,
    marginBottom: 20,
  },
  langBtn: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: C.border,
    backgroundColor: C.white,
  },
  langBtnActive: {
    backgroundColor: C.navy,
    borderColor: C.navy,
  },
  langText: { fontSize: 12, fontWeight: '700', color: C.muted },
  langTextActive: { color: C.white },
  greetingArea: { marginBottom: 16 },
  greeting: { fontSize: 20, fontWeight: '400', color: C.muted },
  foremanName: { fontSize: 32, fontWeight: '800', color: C.text, marginTop: 2 },
  dateText: { fontSize: 13, color: C.muted, marginTop: 4 },
  sfBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: 'rgba(4,132,75,0.08)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
    alignSelf: 'flex-start',
    marginBottom: 20,
    borderWidth: 1,
    borderColor: 'rgba(4,132,75,0.2)',
  },
  sfDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: C.green },
  sfText: { fontSize: 11, color: C.green, fontWeight: '600' },
  summaryCard: {
    backgroundColor: C.card,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    marginBottom: 12,
  },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 12,
  },
  summaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 14,
  },
  statBlock: { flex: 1, alignItems: 'center' },
  statNum: { fontSize: 28, fontWeight: '800', color: C.text },
  statLabel: { fontSize: 11, color: C.muted, marginTop: 2 },
  statDivider: { width: 1, height: 36, backgroundColor: C.border },
  firstJobRow: { gap: 4, borderTopWidth: 1, borderTopColor: C.border, paddingTop: 12 },
  firstJobLabel: { fontSize: 11, fontWeight: '700', color: C.muted },
  firstJobAddr: { fontSize: 15, fontWeight: '600', color: C.text },
  woTypePill: {
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(0,112,210,0.1)',
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 3,
    marginTop: 2,
  },
  woTypeText: { fontSize: 10, fontWeight: '700', color: C.blue },
  sqftText: { fontSize: 12, color: C.muted, marginTop: 2 },
  clockRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 10,
    borderTopWidth: 1,
    borderTopColor: C.border,
    paddingTop: 10,
  },
  clockLabel: { fontSize: 12, color: C.muted },
  clockTime: { fontSize: 13, fontWeight: '700', color: C.green },
  depotCard: {
    backgroundColor: C.card,
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: C.border,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 24,
  },
  depotLabel: { fontSize: 12, color: C.muted, fontWeight: '600' },
  depotAddr: { fontSize: 13, fontWeight: '600', color: C.text, flex: 1 },
  startBtn: {
    backgroundColor: C.blue,
    borderRadius: 10,
    padding: 16,
    alignItems: 'center',
  },
  startBtnText: { fontSize: 16, fontWeight: '700', color: C.white, letterSpacing: 0.3 },
});
