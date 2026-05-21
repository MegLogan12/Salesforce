import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';
import type { SfChecklistItem } from '@/lib/foreman-types';

type Tab = 'vehicle' | 'loaded';

function ChecklistItemRow({
  item,
  onToggle,
}: {
  item: SfChecklistItem;
  onToggle: () => void;
}) {
  return (
    <TouchableOpacity style={styles.itemRow} onPress={onToggle} activeOpacity={0.7}>
      <View style={[styles.checkbox, item.done && styles.checkboxDone]}>
        {item.done && <Text style={styles.checkmark}>✓</Text>}
      </View>
      <Text style={[styles.itemLabel, item.done && styles.itemLabelDone]}>
        {item.label}
      </Text>
      {item.required && !item.done && (
        <View style={styles.requiredPip} />
      )}
    </TouchableOpacity>
  );
}

export function MorningScene() {
  const [activeTab, setActiveTab] = useState<Tab>('vehicle');
  const vehicleChecklist = useForeman(s => s.day.vehicleChecklist);
  const loadedChecklist = useForeman(s => s.day.loadedChecklist);
  const toggleChecklistItem = useForeman(s => s.toggleChecklistItem);
  const goScene = useForeman(s => s.goScene);

  const checklist = activeTab === 'vehicle' ? vehicleChecklist : loadedChecklist;
  const totalRequired = checklist.filter(i => i.required).length;
  const doneRequired = checklist.filter(i => i.required && i.done).length;
  const allTabDone = doneRequired === totalRequired;

  const vehicleRequired = vehicleChecklist.filter(i => i.required).length;
  const vehicleDoneReq = vehicleChecklist.filter(i => i.required && i.done).length;
  const loadedRequired = loadedChecklist.filter(i => i.required).length;
  const loadedDoneReq = loadedChecklist.filter(i => i.required && i.done).length;
  const vehicleDone = vehicleChecklist.filter(i => i.done).length;
  const loadedDone = loadedChecklist.filter(i => i.done).length;

  const allBothDone =
    vehicleDoneReq === vehicleRequired && loadedDoneReq === loadedRequired;

  const progressPct = totalRequired > 0 ? (doneRequired / totalRequired) * 100 : 0;

  return (
    <View style={styles.root}>
      <View style={styles.headerCard}>
        <Text style={styles.headerTitle}>Morning Checklist</Text>
        <Text style={styles.headerSub}>Complete all required items before departing depot</Text>
      </View>

      <View style={styles.progressCard}>
        <View style={styles.progressTopRow}>
          <Text style={styles.progressLabel}>
            {activeTab === 'vehicle' ? 'Vehicle' : 'Load'} Progress
          </Text>
          <Text style={styles.progressFraction}>{doneRequired} / {totalRequired}</Text>
        </View>
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${progressPct}%` as any },
              { backgroundColor: allTabDone ? C.green : C.blue },
            ]}
          />
        </View>
        {allTabDone && (
          <Text style={styles.progressComplete}>All required items complete ✓</Text>
        )}
      </View>

      <View style={styles.tabBar}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'vehicle' && styles.tabActive]}
          onPress={() => setActiveTab('vehicle')}
        >
          {vehicleDoneReq === vehicleRequired && vehicleRequired > 0 && (
            <View style={styles.tabCheckDot} />
          )}
          <Text style={[styles.tabText, activeTab === 'vehicle' && styles.tabTextActive]}>
            Vehicle ({vehicleDone}/{vehicleChecklist.length})
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'loaded' && styles.tabActive]}
          onPress={() => setActiveTab('loaded')}
        >
          {loadedDoneReq === loadedRequired && loadedRequired > 0 && (
            <View style={styles.tabCheckDot} />
          )}
          <Text style={[styles.tabText, activeTab === 'loaded' && styles.tabTextActive]}>
            Loaded ({loadedDone}/{loadedChecklist.length})
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>
          {activeTab === 'vehicle' ? 'Vehicle Safety Check' : 'Load Verification'}
        </Text>
        {checklist.map(item => (
          <ChecklistItemRow
            key={item.id}
            item={item}
            onToggle={() => toggleChecklistItem(activeTab, item.id)}
          />
        ))}
      </View>

      {allBothDone ? (
        <TouchableOpacity style={styles.readyBtn} onPress={() => goScene('drive')} activeOpacity={0.85}>
          <Text style={styles.readyBtnText}>Head to Site →</Text>
        </TouchableOpacity>
      ) : (
        <View style={styles.disabledBtn}>
          <Text style={styles.disabledBtnText}>Complete all required items to continue</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  headerCard: {
    backgroundColor: C.navy,
    borderRadius: R.md,
    padding: 18,
    gap: 4,
    ...Sh.sm,
  },
  headerTitle: { fontSize: 20, fontWeight: '800', color: C.white },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.55)' },

  progressCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 8,
    ...Sh.xs,
  },
  progressTopRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  progressLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  progressFraction: { fontSize: 14, fontWeight: '800', color: C.text },
  progressTrack: {
    height: 10,
    backgroundColor: C.border,
    borderRadius: 5,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 5,
  },
  progressComplete: { fontSize: 12, fontWeight: '700', color: C.green },

  tabBar: {
    flexDirection: 'row',
    backgroundColor: C.white,
    borderRadius: R.md,
    borderWidth: 1,
    borderColor: C.border,
    overflow: 'hidden',
  },
  tab: {
    flex: 1,
    paddingVertical: 13,
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
  },
  tabActive: { backgroundColor: C.navy },
  tabCheckDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: C.green },
  tabText: { fontSize: 13, fontWeight: '600', color: C.muted },
  tabTextActive: { color: C.white },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 2,
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

  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    minHeight: 44,
    paddingVertical: 8,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: C.divider,
  },
  checkbox: {
    width: 26,
    height: 26,
    borderRadius: R.xs,
    borderWidth: 2,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: C.white,
  },
  checkboxDone: {
    backgroundColor: C.green,
    borderColor: C.green,
  },
  checkmark: { fontSize: 14, fontWeight: '900', color: C.white },
  itemLabel: { flex: 1, fontSize: 14, color: C.text, fontWeight: '500' },
  itemLabelDone: { color: C.subtle, textDecorationLine: 'line-through' },
  requiredPip: {
    width: 7,
    height: 7,
    borderRadius: 4,
    backgroundColor: C.red,
  },

  readyBtn: {
    backgroundColor: C.green,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.sm,
  },
  readyBtnText: { fontSize: 16, fontWeight: '800', color: C.white },
  disabledBtn: {
    backgroundColor: C.border,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },
  disabledBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
});
