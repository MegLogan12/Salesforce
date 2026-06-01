import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

type Phase = 'vehicleIntro' | 'vehicle' | 'vehicleDone' | 'loaded' | 'allDone';

function itemIcon(label: string): string {
  const l = label.toLowerCase();
  if (l.includes('tire') || l.includes('light')) return '🛞';
  if (l.includes('fluid') || l.includes('fuel')) return '⛽';
  if (l.includes('trailer') || l.includes('hitch') || l.includes('chain')) return '🔗';
  if (l.includes('first aid') || l.includes('fire ext')) return '🏥';
  if (l.includes('brake')) return '🔴';
  if (l.includes('mirror') || l.includes('windshield')) return '🪞';
  if (l.includes('wiper') || l.includes('horn')) return '🌧';
  if (l.includes('sod') || l.includes('pallet')) return '🌱';
  if (l.includes('fertilizer')) return '🧪';
  if (l.includes('tool') || l.includes('cutter') || l.includes('edger')) return '🔧';
  if (l.includes('water') || l.includes('ice') || l.includes('cooler')) return '💧';
  if (l.includes('mulch')) return '🪵';
  return '✅';
}

export function MorningScene() {
  const vehicleChecklist = useForeman(s => s.day.vehicleChecklist);
  const loadedChecklist = useForeman(s => s.day.loadedChecklist);
  const toggleChecklistItem = useForeman(s => s.toggleChecklistItem);
  const goScene = useForeman(s => s.goScene);

  const [phase, setPhase] = useState<Phase>('vehicleIntro');
  const [step, setStep] = useState(0);

  const vehicleTotal = vehicleChecklist.length;
  const vehicleDone = vehicleChecklist.filter(i => i.done).length;
  const loadedTotal = loadedChecklist.length;
  const loadedDone = loadedChecklist.filter(i => i.done).length;

  const currentItem =
    phase === 'vehicle' ? vehicleChecklist[step] :
    phase === 'loaded' ? loadedChecklist[step] :
    null;

  function handleMark() {
    if (!currentItem) return;
    const cat = phase === 'vehicle' ? 'vehicle' : 'loaded';
    if (!currentItem.done) toggleChecklistItem(cat, currentItem.id);

    const list = phase === 'vehicle' ? vehicleChecklist : loadedChecklist;
    if (step < list.length - 1) {
      setStep(s => s + 1);
    } else if (phase === 'vehicle') {
      setPhase('vehicleDone');
      setStep(0);
    } else {
      setPhase('allDone');
    }
  }

  function handleUndo() {
    if (!currentItem) return;
    const cat = phase === 'vehicle' ? 'vehicle' : 'loaded';
    if (currentItem.done) toggleChecklistItem(cat, currentItem.id);
  }

  function handleBack() {
    if (phase === 'vehicle' && step === 0) {
      setPhase('vehicleIntro');
    } else if (phase === 'vehicle') {
      setStep(s => s - 1);
    } else if (phase === 'vehicleDone') {
      setPhase('vehicle');
      setStep(vehicleTotal - 1);
    } else if (phase === 'loaded' && step === 0) {
      setPhase('vehicleDone');
    } else if (phase === 'loaded') {
      setStep(s => s - 1);
    } else if (phase === 'allDone') {
      setPhase('loaded');
      setStep(loadedTotal - 1);
    }
  }

  // ── VEHICLE INTRO ────────────────────────────────────────────────────────────
  if (phase === 'vehicleIntro') {
    const allVehicleDone = vehicleDone === vehicleTotal;
    return (
      <View style={styles.root}>
        <View style={styles.introCard}>
          <Text style={styles.bigIcon}>🚚</Text>
          <Text style={styles.introTitle}>Vehicle Safety Check</Text>
          <Text style={styles.introSub}>Truck T-007 · {vehicleTotal} items</Text>
          <Text style={styles.introDesc}>
            Walk around the truck and confirm each item before departing the depot.
          </Text>
        </View>

        <View style={styles.progressCard}>
          <View style={styles.progressRow}>
            <Text style={styles.progressLabel}>Vehicle Check Progress</Text>
            <Text style={styles.progressFrac}>{vehicleDone}/{vehicleTotal}</Text>
          </View>
          <View style={styles.track}>
            <View
              style={[
                styles.fill,
                {
                  width: vehicleTotal > 0 ? `${(vehicleDone / vehicleTotal) * 100}%` as any : '0%',
                  backgroundColor: allVehicleDone ? C.green : C.orange,
                },
              ]}
            />
          </View>
          {allVehicleDone && (
            <Text style={styles.allClearText}>All vehicle items confirmed ✓</Text>
          )}
        </View>

        <TouchableOpacity
          style={[styles.primaryBtn, allVehicleDone && { backgroundColor: C.green }]}
          onPress={() => { setStep(0); setPhase('vehicle'); }}
          activeOpacity={0.85}
        >
          <Text style={styles.primaryBtnText}>
            {allVehicleDone ? '✓ Review Vehicle Check' : '▶ Start Vehicle Check'}
          </Text>
        </TouchableOpacity>
      </View>
    );
  }

  // ── PER-ITEM SCREEN ──────────────────────────────────────────────────────────
  if ((phase === 'vehicle' || phase === 'loaded') && currentItem) {
    const list = phase === 'vehicle' ? vehicleChecklist : loadedChecklist;
    const total = list.length;
    const pct = ((step + 1) / total) * 100;
    const title = phase === 'vehicle' ? 'Vehicle Safety Check' : 'Load Verification';
    const icon = itemIcon(currentItem.label);
    const isDone = currentItem.done;

    return (
      <View style={styles.root}>
        {/* Step header */}
        <View style={styles.stepHeader}>
          <TouchableOpacity onPress={handleBack} hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}>
            <Text style={styles.backText}>‹ Back</Text>
          </TouchableOpacity>
          <Text style={styles.stepCount}>{step + 1} of {total}</Text>
        </View>

        {/* Progress bar */}
        <View style={styles.track2}>
          <View style={[styles.fill, { width: `${pct}%` as any, backgroundColor: isDone ? C.green : C.blue }]} />
        </View>

        {/* Item card */}
        <View style={[styles.itemCard, isDone && styles.itemCardDone]}>
          <Text style={styles.itemIcon}>{icon}</Text>
          <Text style={styles.categoryLabel}>{title}</Text>
          <Text style={[styles.itemLabel, isDone && { color: C.green }]}>{currentItem.label}</Text>
          {currentItem.required && !isDone && (
            <View style={styles.requiredBadge}>
              <Text style={styles.requiredBadgeText}>Required</Text>
            </View>
          )}
          {isDone && (
            <View style={styles.doneBadge}>
              <Text style={styles.doneBadgeText}>Confirmed ✓</Text>
            </View>
          )}
        </View>

        {/* Action button */}
        <TouchableOpacity
          style={[styles.primaryBtn, isDone && { backgroundColor: C.green }]}
          onPress={handleMark}
          activeOpacity={0.85}
        >
          <Text style={styles.primaryBtnText}>
            {isDone ? '✓ Continue →' : 'Mark as Checked →'}
          </Text>
        </TouchableOpacity>

        {isDone && (
          <TouchableOpacity style={styles.undoBtn} onPress={handleUndo} activeOpacity={0.7}>
            <Text style={styles.undoText}>Undo</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  }

  // ── VEHICLE DONE / LOAD INTRO ────────────────────────────────────────────────
  if (phase === 'vehicleDone') {
    const allLoadedDone = loadedDone === loadedTotal;
    return (
      <View style={styles.root}>
        <View style={[styles.introCard, styles.successCard]}>
          <Text style={styles.bigIcon}>✅</Text>
          <Text style={[styles.introTitle, { color: C.white }]}>Vehicle Check Complete!</Text>
          <Text style={[styles.introSub, { color: 'rgba(255,255,255,0.8)' }]}>
            {vehicleTotal}/{vehicleTotal} items confirmed
          </Text>
        </View>

        <View style={styles.progressCard}>
          <View style={styles.progressRow}>
            <Text style={styles.progressLabel}>Load Verification Progress</Text>
            <Text style={styles.progressFrac}>{loadedDone}/{loadedTotal}</Text>
          </View>
          <View style={styles.track}>
            <View
              style={[
                styles.fill,
                {
                  width: loadedTotal > 0 ? `${(loadedDone / loadedTotal) * 100}%` as any : '0%',
                  backgroundColor: allLoadedDone ? C.green : C.orange,
                },
              ]}
            />
          </View>
          {allLoadedDone && (
            <Text style={styles.allClearText}>All load items confirmed ✓</Text>
          )}
        </View>

        <TouchableOpacity
          style={[styles.primaryBtn, allLoadedDone && { backgroundColor: C.green }]}
          onPress={() => { setStep(0); setPhase('loaded'); }}
          activeOpacity={0.85}
        >
          <Text style={styles.primaryBtnText}>
            {allLoadedDone ? '✓ Review Load Check' : '▶ Start Load Check'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.ghostBtn} onPress={handleBack} activeOpacity={0.7}>
          <Text style={styles.ghostBtnText}>‹ Back to Vehicle Check</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // ── ALL DONE ─────────────────────────────────────────────────────────────────
  if (phase === 'allDone') {
    return (
      <View style={styles.root}>
        <View style={[styles.introCard, { backgroundColor: C.navy }]}>
          <Text style={styles.bigIcon}>🚀</Text>
          <Text style={[styles.introTitle, { color: C.white }]}>Ready to Roll!</Text>
          <Text style={[styles.introSub, { color: 'rgba(255,255,255,0.75)' }]}>
            All {vehicleTotal + loadedTotal} pre-shift items complete
          </Text>
        </View>

        <View style={styles.summaryCard}>
          <View style={styles.summaryRow}>
            <Text style={styles.summaryIcon}>🚚</Text>
            <Text style={styles.summaryLabel}>Vehicle Safety</Text>
            <Text style={[styles.summaryValue, { color: C.green }]}>{vehicleTotal}/{vehicleTotal} ✓</Text>
          </View>
          <View style={styles.divider} />
          <View style={styles.summaryRow}>
            <Text style={styles.summaryIcon}>📦</Text>
            <Text style={styles.summaryLabel}>Load Verification</Text>
            <Text style={[styles.summaryValue, { color: C.green }]}>{loadedTotal}/{loadedTotal} ✓</Text>
          </View>
        </View>

        <TouchableOpacity
          style={[styles.primaryBtn, { backgroundColor: C.green, height: 60 }]}
          onPress={() => goScene('drive')}
          activeOpacity={0.85}
        >
          <Text style={[styles.primaryBtnText, { fontSize: 18 }]}>Head to Site →</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.ghostBtn} onPress={handleBack} activeOpacity={0.7}>
          <Text style={styles.ghostBtnText}>‹ Back to Load Check</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return null;
}

const styles = StyleSheet.create({
  root: { gap: 16 },

  // Intro / section header cards
  introCard: {
    backgroundColor: C.white,
    borderRadius: R.lg,
    padding: 28,
    alignItems: 'center',
    gap: 6,
    ...Sh.sm,
  },
  successCard: {
    backgroundColor: C.green,
  },
  bigIcon: { fontSize: 60, marginBottom: 6 },
  introTitle: { fontSize: 22, fontWeight: '800', color: C.text, textAlign: 'center' },
  introSub: { fontSize: 14, color: C.muted, textAlign: 'center' },
  introDesc: {
    fontSize: 13,
    color: C.muted,
    textAlign: 'center',
    lineHeight: 20,
    marginTop: 4,
  },

  // Progress
  progressCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    gap: 10,
    ...Sh.xs,
  },
  progressRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  progressLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  progressFrac: { fontSize: 15, fontWeight: '800', color: C.text },
  track: { height: 10, backgroundColor: C.border, borderRadius: 5, overflow: 'hidden' },
  fill: { height: '100%', borderRadius: 5 },
  allClearText: { fontSize: 12, fontWeight: '700', color: C.green },

  // Step header
  stepHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: -4,
  },
  backText: { fontSize: 16, color: C.blue, fontWeight: '600' },
  stepCount: { fontSize: 13, fontWeight: '700', color: C.muted },
  track2: { height: 6, backgroundColor: C.border, borderRadius: 3, overflow: 'hidden' },

  // Per-item card
  itemCard: {
    backgroundColor: C.white,
    borderRadius: R.lg,
    padding: 32,
    alignItems: 'center',
    gap: 10,
    minHeight: 240,
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
    ...Sh.sm,
  },
  itemCardDone: {
    borderColor: C.green + '60',
    backgroundColor: '#F8FDF9',
  },
  itemIcon: { fontSize: 64, marginBottom: 4 },
  categoryLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.5,
  },
  itemLabel: {
    fontSize: 22,
    fontWeight: '800',
    color: C.text,
    textAlign: 'center',
    lineHeight: 30,
  },
  requiredBadge: {
    backgroundColor: '#FEE2E2',
    borderRadius: R.sm,
    paddingHorizontal: 12,
    paddingVertical: 4,
    marginTop: 4,
  },
  requiredBadgeText: { fontSize: 11, fontWeight: '700', color: C.red },
  doneBadge: {
    backgroundColor: '#D1FAE5',
    borderRadius: R.sm,
    paddingHorizontal: 12,
    paddingVertical: 4,
    marginTop: 4,
  },
  doneBadgeText: { fontSize: 11, fontWeight: '700', color: C.green },

  // Buttons
  primaryBtn: {
    backgroundColor: C.blue,
    borderRadius: R.md,
    height: 56,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.sm,
  },
  primaryBtnText: { fontSize: 16, fontWeight: '800', color: C.white },

  ghostBtn: {
    height: 46,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: R.md,
    borderWidth: 1,
    borderColor: C.border,
    backgroundColor: C.white,
  },
  ghostBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },

  undoBtn: { alignItems: 'center', paddingVertical: 10 },
  undoText: { fontSize: 13, color: C.muted, fontWeight: '500' },

  // Summary card (allDone)
  summaryCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    gap: 10,
    ...Sh.xs,
  },
  summaryRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  summaryIcon: { fontSize: 22 },
  summaryLabel: { flex: 1, fontSize: 14, fontWeight: '600', color: C.text },
  summaryValue: { fontSize: 14, fontWeight: '800' },
  divider: { height: 1, backgroundColor: C.divider },
});
