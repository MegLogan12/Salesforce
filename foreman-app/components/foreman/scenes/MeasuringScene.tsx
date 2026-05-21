import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInput,
  ScrollView,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
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
    <View style={styles.measRow}>
      <View style={styles.measRowHeader}>
        <TextInput
          style={styles.areaNameInput}
          placeholder={`Area ${index + 1}`}
          placeholderTextColor={C.muted}
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
            placeholderTextColor={C.muted}
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
            placeholderTextColor={C.muted}
            value={m.widthFt !== null ? String(m.widthFt) : ''}
            onChangeText={t => onUpdate({ widthFt: t === '' ? null : Number(t) })}
          />
        </View>
        <View style={styles.resultBox}>
          <Text style={styles.resultLabel}>sq ft</Text>
          <Text style={styles.resultVal}>{sqft !== null ? sqft.toLocaleString() : '—'}</Text>
        </View>
      </View>
      {m.notes.length > 0 || true ? (
        <TextInput
          style={styles.notesInput}
          placeholder="Notes (optional)"
          placeholderTextColor={C.muted}
          value={m.notes}
          onChangeText={t => onUpdate({ notes: t })}
        />
      ) : null}
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

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.headerCard}>
        <Text style={styles.heading}>📐 Measuring Cup</Text>
        {wo && (
          <Text style={styles.subheading}>{wo.subject} · {wo.sodSpecies}</Text>
        )}
      </View>

      {/* Summary */}
      <View style={styles.summaryCard}>
        <View style={styles.summaryRow}>
          <View style={styles.summaryBlock}>
            <Text style={styles.summaryNum}>{totalMeasured.toLocaleString()}</Text>
            <Text style={styles.summarySub}>Measured sq ft</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryBlock}>
            <Text style={styles.summaryNum}>{targetSqft.toLocaleString()}</Text>
            <Text style={styles.summarySub}>WO Target sq ft</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryBlock}>
            <Text style={[styles.summaryNum, delta > 0 ? { color: C.orange } : delta < 0 ? { color: C.red } : { color: C.green }]}>
              {delta === 0 ? '—' : (delta > 0 ? '+' : '') + delta.toLocaleString()}
            </Text>
            <Text style={styles.summarySub}>Variance</Text>
          </View>
        </View>
        {targetSqft > 0 && (
          <View>
            <View style={styles.progressTrack}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${pct}%` as any },
                  pct >= 100 ? { backgroundColor: C.green } : { backgroundColor: C.blue },
                ]}
              />
            </View>
            <Text style={styles.progressLabel}>{pct}% of target measured</Text>
          </View>
        )}
      </View>

      {/* Measurements */}
      {measurements.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Areas</Text>
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

      {/* Add area */}
      <TouchableOpacity style={styles.addBtn} onPress={addMeasurement} activeOpacity={0.8}>
        <Text style={styles.addBtnText}>+ Add Area</Text>
      </TouchableOpacity>

      {/* Back */}
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
    borderRadius: 14,
    padding: 20,
    gap: 4,
  },
  heading: { fontSize: 22, fontWeight: '800', color: C.white },
  subheading: { fontSize: 13, color: 'rgba(255,255,255,0.6)' },

  summaryCard: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 12,
  },
  summaryRow: { flexDirection: 'row', alignItems: 'center' },
  summaryBlock: { flex: 1, alignItems: 'center' },
  summaryNum: { fontSize: 24, fontWeight: '800', color: C.text },
  summarySub: { fontSize: 10, color: C.muted, marginTop: 2, textAlign: 'center' },
  summaryDivider: { width: 1, height: 40, backgroundColor: C.border },
  progressTrack: {
    height: 8,
    backgroundColor: C.border,
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: { height: '100%', borderRadius: 4 },
  progressLabel: { fontSize: 11, color: C.muted, marginTop: 4, textAlign: 'right' },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
  },
  cardTitle: { fontSize: 13, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.8 },

  measRow: {
    backgroundColor: C.bg,
    borderRadius: 10,
    padding: 12,
    gap: 8,
    borderWidth: 1,
    borderColor: C.border,
  },
  measRowHeader: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  areaNameInput: {
    flex: 1,
    fontSize: 14,
    fontWeight: '600',
    color: C.text,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
    paddingBottom: 4,
  },
  removeBtn: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: C.red + '20',
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeBtnText: { fontSize: 13, color: C.red, fontWeight: '700' },

  dimRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  dimField: { flex: 1, gap: 3 },
  dimLabel: { fontSize: 10, fontWeight: '600', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.5 },
  dimInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 8,
    padding: 8,
    fontSize: 16,
    fontWeight: '700',
    color: C.text,
    backgroundColor: C.white,
    textAlign: 'center',
  },
  dimX: { fontSize: 20, color: C.muted, fontWeight: '300', marginTop: 12 },
  resultBox: {
    backgroundColor: C.navy,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
    alignItems: 'center',
    minWidth: 72,
    gap: 2,
  },
  resultLabel: { fontSize: 9, color: 'rgba(255,255,255,0.5)', textTransform: 'uppercase', letterSpacing: 0.5 },
  resultVal: { fontSize: 18, fontWeight: '800', color: C.white },

  notesInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 8,
    padding: 8,
    fontSize: 13,
    color: C.text,
    backgroundColor: C.white,
  },

  addBtn: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.blue,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  addBtnText: { fontSize: 15, fontWeight: '700', color: C.blue },

  backBtn: {
    backgroundColor: C.bg,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  backBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
});
