import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
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
        <Text style={styles.required}>*</Text>
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
  const totalDone = checklist.filter(i => i.done).length;
  const allRequiredDone = doneRequired === totalRequired;

  const vehicleTotal = vehicleChecklist.length;
  const vehicleDone = vehicleChecklist.filter(i => i.done).length;
  const loadedTotal = loadedChecklist.length;
  const loadedDone = loadedChecklist.filter(i => i.done).length;

  const progressPct = totalRequired > 0 ? (doneRequired / totalRequired) * 100 : 0;

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Morning Checklist</Text>
        <Text style={styles.subtitle}>Complete all required items before departing depot</Text>
      </View>

      {/* Progress bar */}
      <View style={styles.progressCard}>
        <View style={styles.progressHeader}>
          <Text style={styles.progressLabel}>Required Items</Text>
          <Text style={styles.progressCount}>{doneRequired} / {totalRequired}</Text>
        </View>
        <View style={styles.progressTrack}>
          <View style={[styles.progressFill, { width: `${progressPct}%` as any, backgroundColor: allRequiredDone ? C.green : C.blue }]} />
        </View>
        {allRequiredDone && (
          <Text style={styles.progressComplete}>All required items complete ✓</Text>
        )}
      </View>

      {/* Tabs */}
      <View style={styles.tabBar}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'vehicle' && styles.tabActive]}
          onPress={() => setActiveTab('vehicle')}
        >
          <Text style={[styles.tabText, activeTab === 'vehicle' && styles.tabTextActive]}>
            Vehicle ({vehicleDone}/{vehicleTotal})
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'loaded' && styles.tabActive]}
          onPress={() => setActiveTab('loaded')}
        >
          <Text style={[styles.tabText, activeTab === 'loaded' && styles.tabTextActive]}>
            Loaded ({loadedDone}/{loadedTotal})
          </Text>
        </TouchableOpacity>
      </View>

      {/* Checklist */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>
          {activeTab === 'vehicle' ? 'Vehicle Safety Check' : 'Load Verification'}
        </Text>
        <Text style={styles.requiredNote}>* Required items must be completed</Text>
        {checklist.map(item => (
          <ChecklistItemRow
            key={item.id}
            item={item}
            onToggle={() => toggleChecklistItem(activeTab, item.id)}
          />
        ))}
      </View>

      {/* Action */}
      {allRequiredDone && vehicleChecklist.filter(i => i.required && i.done).length === vehicleChecklist.filter(i => i.required).length && loadedChecklist.filter(i => i.required && i.done).length === loadedChecklist.filter(i => i.required).length ? (
        <TouchableOpacity style={styles.primaryBtn} onPress={() => goScene('drive')} activeOpacity={0.85}>
          <Text style={styles.primaryBtnText}>Head to Job Site →</Text>
        </TouchableOpacity>
      ) : (
        <View style={styles.disabledBtn}>
          <Text style={styles.disabledBtnText}>
            Complete all required items to continue
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },
  header: {
    backgroundColor: C.white,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 4,
  },
  title: { fontSize: 20, fontWeight: '800', color: C.text },
  subtitle: { fontSize: 13, color: C.muted },
  progressCard: {
    backgroundColor: C.white,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    gap: 8,
  },
  progressHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  progressLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  progressCount: { fontSize: 13, fontWeight: '700', color: C.text },
  progressTrack: {
    height: 8,
    backgroundColor: C.border,
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 4,
  },
  progressComplete: { fontSize: 12, fontWeight: '600', color: C.green },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: C.white,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: C.border,
    overflow: 'hidden',
  },
  tab: { flex: 1, paddingVertical: 12, alignItems: 'center' },
  tabActive: { backgroundColor: C.navy },
  tabText: { fontSize: 13, fontWeight: '600', color: C.muted },
  tabTextActive: { color: C.white },
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
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    marginBottom: 4,
  },
  requiredNote: { fontSize: 11, color: C.red, marginBottom: 8 },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 6,
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
  checkmark: { fontSize: 13, fontWeight: '800', color: C.white },
  itemLabel: { flex: 1, fontSize: 14, color: C.text, fontWeight: '500' },
  itemLabelDone: { color: C.muted, textDecorationLine: 'line-through' },
  required: { fontSize: 16, fontWeight: '700', color: C.red },
  primaryBtn: {
    backgroundColor: C.blue,
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  primaryBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
  disabledBtn: {
    backgroundColor: C.border,
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  disabledBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
});
