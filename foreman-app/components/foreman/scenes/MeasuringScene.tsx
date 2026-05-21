import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInput,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';
import type { SfMeasurement } from '@/lib/foreman-types';

function MeasRow({
  m,
  index,
  onUpdate,
  onRemove,
}: {
  m: SfMeasurement;
  index: number;
  onUpdate: (patch: Partial<SfMeasurement>) => void;
  onRemove: () => void;
}) {
  const sqft = m.lengthFt && m.widthFt ? Math.round(m.lengthFt * m.widthFt) : null;

  return (
    <View style={styles.measCard}>
      <View style={styles.measCardHeader}>
        <TextInput
          style={styles.areaNameInput}
          placeholder={`Area ${index + 1}`}
          placeholderTextColor={C.subtle}
          value={m.label}
          onChangeText={t => onUpdate({ label: t })}
        />
        <TouchableOpacity onPress={onRemove} style={styles.removeBtn}>
          <Text style={styles.removeBtnText}>✕</Text>
        </TouchableOpacity>
      </View>
      <View style={styles.dimRow}>
        <View style={styles.dimField}>
          <Text style={styles.dimLabel}>Length (ft)</Text>
          <TextInput
            style={styles.dimInput}
            keyboardType="decimal-pad"
            placeholder="0"
            placeholderTextColor={C.subtle}
            value={m.lengthFt !== null ? String(m.lengthFt) : ''}
            onChangeText={t => onUpdate({ lengthFt: t === '' ? null : Number(t) })}
          />
        </View>
        <Text style={styles.dimX}>×</Text>
        <View style={styles.dimField}>
          <Text style={styles.dimLabel}>Width (ft)</Text>
          <TextInput
            style={styles.dimInput}
            keyboardType="decimal-pad"
            placeholder="0"
            placeholderTextColor={C.subtle}
            value={m.widthFt !== null ? String(m.widthFt) : ''}
            onChangeText={t => onUpdate({ widthFt: t === '' ? null : Number(t) })}
          />
        </View>
        <View style={styles.resultBox}>
          <Text style={styles.resultLabel}>sq ft</Text>
          <Text style={styles.resultVal}>{sqft !== null ? sqft.toLocaleString() : '—'}</Text>
        </View>
      </View>
      <TextInput
        style={styles.notesInput}
        placeholder="Notes (optional)"
        placeholderTextColor={C.subtle}
        value={m.notes}
        onChangeText={t => onUpdate({ notes: t })}
      />
    </View>
  );
}

export function MeasuringScene() {
  const day = useForeman(s => s.day);
  const selectedWorkOrder = useForeman(s => s.selectedWorkOrder);
  const addMeasurement = useForeman(s => s.addMeasurement);
  const updateMeasurement = useForeman(s => s.updateMeasurement);
  const removeMeasurement = useForeman(s => s.removeMeasurement);
  const goScene = useForeman(s => s.goScene);

  const wo = selectedWorkOrder();
  const measurements = day.measurements;

  const totalMeasured = measurements.reduce((sum, m) => {
    if (m.lengthFt && m.widthFt) return sum + Math.round(m.lengthFt * m.widthFt);
    return sum;
  }, 0);

  const targetSqft = wo?.sodSqft ?? 0;
  const delta = totalMeasured - targetSqft;
  const pct = targetSqft > 0 ? Math.min(100, Math.round((totalMeasured / targetSqft) * 100)) : 0;

  const deltaColor = delta === 0 ? C.green : delta > 0 ? C.orange : C.red;
  const deltaLabel = delta === 0 ? '—' : (delta > 0 ? '+' : '') + delta.toLocaleString();

  return (
    <View style={styles.root}>
      <View style={styles.headerCard}>
        <Text style={styles.headerTitle}>📐 Measuring Cup</Text>
        {wo && (
          <Text style={styles.headerSub}>{wo.subject} · {wo.sodSpecies}</Text>
        )}
      </View>

      <View style={styles.summaryCard}>
        <View style={styles.summaryRow}>
          <View style={styles.summaryCell}>
            <Text style={styles.summaryCellLabel}>MEASURED</Text>
            <Text style={styles.summaryCellVal}>{totalMeasured.toLocaleString()}</Text>
            <Text style={styles.summaryCellUnit}>sq ft</Text>
          </View>
          <View style={styles.summaryCellDivider} />
          <View style={styles.summaryCell}>
            <Text style={styles.summaryCellLabel}>TARGET</Text>
            <Text style={styles.summaryCellVal}>{targetSqft.toLocaleString()}</Text>
            <Text style={styles.summaryCellUnit}>sq ft</Text>
          </View>
          <View style={styles.summaryCellDivider} />
          <View style={styles.summaryCell}>
            <Text style={styles.summaryCellLabel}>VARIANCE</Text>
            <Text style={[styles.summaryCellVal, { color: deltaColor }]}>{deltaLabel}</Text>
            <Text style={styles.summaryCellUnit}>sq ft</Text>
          </View>
        </View>
        {targetSqft > 0 && (
          <View style={styles.progressGroup}>
            <View style={styles.progressTrack}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${pct}%` as any },
                  { backgroundColor: pct >= 100 ? C.green : C.blue },
                ]}
              />
            </View>
            <Text style={styles.progressLabel}>{pct}% of target measured</Text>
          </View>
        )}
      </View>

      {measurements.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.sectionLabel}>Areas</Text>
          {measurements.map((m, i) => (
            <MeasRow
              key={m.id}
              m={m}
              index={i}
              onUpdate={patch => updateMeasurement(m.id, patch)}
              onRemove={() => removeMeasurement(m.id)}
            />
          ))}
        </View>
      )}

      <TouchableOpacity style={styles.addBtn} onPress={addMeasurement} activeOpacity={0.8}>
        <Text style={styles.addBtnText}>+ Add Area</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.backBtn} onPress={() => goScene('active')} activeOpacity={0.85}>
        <Text style={styles.backBtnText}>← Back to Job</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  headerCard: {
    backgroundColor: C.navy,
    borderRadius: R.md,
    padding: 20,
    gap: 5,
    ...Sh.sm,
  },
  headerTitle: { fontSize: 22, fontWeight: '900', color: C.white },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.55)' },

  summaryCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 14,
    ...Sh.xs,
  },
  summaryRow: { flexDirection: 'row', alignItems: 'center' },
  summaryCell: { flex: 1, alignItems: 'center', gap: 2 },
  summaryCellLabel: {
    fontSize: 9,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },
  summaryCellVal: { fontSize: 22, fontWeight: '900', color: C.text },
  summaryCellUnit: { fontSize: 10, color: C.subtle },
  summaryCellDivider: { width: 1, height: 44, backgroundColor: C.border },

  progressGroup: { gap: 5 },
  progressTrack: {
    height: 10,
    backgroundColor: C.border,
    borderRadius: 5,
    overflow: 'hidden',
  },
  progressFill: { height: '100%', borderRadius: 5 },
  progressLabel: { fontSize: 11, color: C.muted, textAlign: 'right', fontWeight: '600' },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    ...Sh.xs,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },

  measCard: {
    backgroundColor: C.bg,
    borderRadius: R.sm,
    padding: 12,
    gap: 8,
    borderWidth: 1,
    borderColor: C.border,
  },
  measCardHeader: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  areaNameInput: {
    flex: 1,
    fontSize: 14,
    fontWeight: '600',
    color: C.text,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
    paddingBottom: 5,
  },
  removeBtn: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: C.red + '18',
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeBtnText: { fontSize: 13, color: C.red, fontWeight: '700' },

  dimRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  dimField: { flex: 1, gap: 4 },
  dimLabel: {
    fontSize: 9,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  dimInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: R.sm,
    padding: 8,
    fontSize: 17,
    fontWeight: '700',
    color: C.text,
    backgroundColor: C.white,
    textAlign: 'center',
  },
  dimX: { fontSize: 20, color: C.muted, fontWeight: '300', marginTop: 14 },
  resultBox: {
    backgroundColor: C.navy,
    borderRadius: R.sm,
    paddingHorizontal: 10,
    paddingVertical: 8,
    alignItems: 'center',
    minWidth: 74,
    gap: 2,
  },
  resultLabel: {
    fontSize: 9,
    color: 'rgba(255,255,255,0.45)',
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  resultVal: { fontSize: 18, fontWeight: '900', color: C.white },

  notesInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: R.sm,
    padding: 8,
    fontSize: 13,
    color: C.text,
    backgroundColor: C.white,
  },

  addBtn: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.blue,
    borderRadius: R.md,
    height: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addBtnText: { fontSize: 15, fontWeight: '700', color: C.blue },

  backBtn: {
    backgroundColor: C.bg,
    borderRadius: R.md,
    height: 50,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  backBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
});
