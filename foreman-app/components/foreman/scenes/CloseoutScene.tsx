import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInput,
  Alert,
  Platform,
  ScrollView,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';

type Step = 'inventory' | 'housekeeping' | 'photos' | 'review';

async function openCamera(): Promise<boolean> {
  if (Platform.OS === 'web') return true;
  const { status } = await ImagePicker.requestCameraPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert('Camera Required', 'Enable camera access to take after photos.');
    return false;
  }
  const result = await ImagePicker.launchCameraAsync({ quality: 0.85 });
  return !result.canceled;
}

function StepIndicator({ current }: { current: Step }) {
  const steps: Step[] = ['inventory', 'housekeeping', 'photos', 'review'];
  const labels = ['Inventory', 'Housekeeping', 'Photos', 'Review'];
  const cur = steps.indexOf(current);
  return (
    <View style={ind.row}>
      {steps.map((s, i) => (
        <React.Fragment key={s}>
          <View style={[ind.dot, i <= cur && ind.dotActive]}>
            <Text style={[ind.dotNum, i <= cur && ind.dotNumActive]}>{i + 1}</Text>
          </View>
          {i < steps.length - 1 && (
            <View style={[ind.line, i < cur && ind.lineActive]} />
          )}
        </React.Fragment>
      ))}
    </View>
  );
}

const ind = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8 },
  dot: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dotActive: { backgroundColor: C.blue },
  dotNum: { fontSize: 12, fontWeight: '700', color: C.muted },
  dotNumActive: { color: C.white },
  line: { flex: 1, height: 2, backgroundColor: C.border },
  lineActive: { backgroundColor: C.blue },
});

export function CloseoutScene() {
  const [step, setStep] = useState<Step>('inventory');

  const inventory = useForeman(s => s.day.inventory);
  const housekeeping = useForeman(s => s.day.housekeeping);
  const day = useForeman(s => s.day);
  const setHasExcess = useForeman(s => s.setHasExcess);
  const setExcessDetails = useForeman(s => s.setExcessDetails);
  const captureExcessPhoto = useForeman(s => s.captureExcessPhoto);
  const setHasMissing = useForeman(s => s.setHasMissing);
  const setMissingDetails = useForeman(s => s.setMissingDetails);
  const toggleHousekeeping = useForeman(s => s.toggleHousekeeping);
  const capturePhoto = useForeman(s => s.capturePhoto);
  const submitCloseout = useForeman(s => s.submitCloseout);
  const setInventoryUsed = useForeman(s => s.setInventoryUsed);
  const setInventoryReturned = useForeman(s => s.setInventoryReturned);

  const heroAfter = day.photos.find(p => p.category === 'hero-after');
  const afterPhotos = day.photos.filter(p => p.category === 'after' || p.category === 'hero-after');
  const wo = day.workOrders.find(w => w.id === day.selectedWorkOrderId);

  const requiredHk = housekeeping.filter(h => h.required);
  const doneRequiredHk = requiredHk.filter(h => h.done);
  const allHkDone = doneRequiredHk.length === requiredHk.length;

  async function handleExcessPhoto() {
    const ok = await openCamera();
    if (ok) captureExcessPhoto();
  }

  async function handleAfterPhoto(hero: boolean) {
    const ok = await openCamera();
    if (ok) capturePhoto(hero ? 'hero-after' : 'after');
  }

  function handleSubmit() {
    if (!heroAfter) {
      Alert.alert('Required', 'Take the hero after photo before submitting.');
      return;
    }
    Alert.alert(
      'Submit Closeout',
      'This will mark the job as Awaiting QI. Are you sure?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Submit', onPress: submitCloseout },
      ]
    );
  }

  const stepLabels: Record<Step, string> = {
    inventory: 'Inventory & Excess',
    housekeeping: 'Housekeeping',
    photos: 'After Photos',
    review: 'Review & Submit',
  };

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.headerCard}>
        <Text style={styles.headerTitle}>Closeout</Text>
        {wo && <Text style={styles.headerSub}>{wo.woNumber} · {wo.subject}</Text>}
      </View>

      {/* Step indicator */}
      <View style={styles.card}>
        <StepIndicator current={step} />
        <Text style={styles.stepName}>{stepLabels[step]}</Text>
      </View>

      {/* ─── STEP 1: Inventory & Excess ─── */}
      {step === 'inventory' && (
        <>
          {/* Inventory items */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Material Reconciliation</Text>
            {inventory.items.map(item => (
              <View key={item.id} style={styles.invRow}>
                <View style={styles.invInfo}>
                  <Text style={styles.invLabel}>{item.label}</Text>
                  <Text style={styles.invLoaded}>Loaded: {item.loaded} {item.unit}</Text>
                </View>
                <View style={styles.invInputs}>
                  <View style={styles.invField}>
                    <Text style={styles.invFieldLabel}>Used</Text>
                    <TextInput
                      style={styles.invInput}
                      keyboardType="numeric"
                      placeholder="—"
                      placeholderTextColor={C.muted}
                      value={item.used !== null ? String(item.used) : ''}
                      onChangeText={t => setInventoryUsed(item.id, t === '' ? null : Number(t))}
                    />
                  </View>
                  <View style={styles.invField}>
                    <Text style={styles.invFieldLabel}>Return</Text>
                    <TextInput
                      style={styles.invInput}
                      keyboardType="numeric"
                      placeholder="—"
                      placeholderTextColor={C.muted}
                      value={item.returned !== null ? String(item.returned) : ''}
                      onChangeText={t => setInventoryReturned(item.id, t === '' ? null : Number(t))}
                    />
                  </View>
                </View>
              </View>
            ))}
          </View>

          {/* Excess question */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Any excess inventory on site?</Text>
            <Text style={styles.cardSub}>Leftover materials that weren't used or returned</Text>
            <View style={styles.yesNoRow}>
              <TouchableOpacity
                style={[styles.yesNoBtn, inventory.hasExcess === false && styles.yesNoBtnActive, { borderColor: C.green }]}
                onPress={() => setHasExcess(false)}
              >
                <Text style={[styles.yesNoBtnText, inventory.hasExcess === false && { color: C.white }]}>No Excess</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.yesNoBtn, inventory.hasExcess === true && styles.yesNoBtnActiveRed, { borderColor: C.orange }]}
                onPress={() => setHasExcess(true)}
              >
                <Text style={[styles.yesNoBtnText, inventory.hasExcess === true && { color: C.white }]}>Yes, Has Excess</Text>
              </TouchableOpacity>
            </View>
            {inventory.hasExcess === true && (
              <View style={styles.excessForm}>
                <TextInput
                  style={styles.noteInput}
                  placeholder="Describe excess (what, how much)..."
                  placeholderTextColor={C.muted}
                  value={inventory.excessDetails}
                  onChangeText={setExcessDetails}
                  multiline
                />
                <TouchableOpacity
                  style={[styles.photoBtn, inventory.excessPhotoCaptured && styles.photoBtnDone]}
                  onPress={handleExcessPhoto}
                >
                  <Text style={[styles.photoBtnText, inventory.excessPhotoCaptured && styles.photoBtnTextDone]}>
                    {inventory.excessPhotoCaptured ? '📷 Excess Photo Captured ✓' : '📷 Photo of Excess'}
                  </Text>
                </TouchableOpacity>
              </View>
            )}
          </View>

          <TouchableOpacity
            style={[styles.nextBtn, inventory.hasExcess === null && styles.nextBtnDisabled]}
            onPress={() => inventory.hasExcess !== null && setStep('housekeeping')}
            disabled={inventory.hasExcess === null}
          >
            <Text style={styles.nextBtnText}>Next: Housekeeping →</Text>
          </TouchableOpacity>
        </>
      )}

      {/* ─── STEP 2: Housekeeping ─── */}
      {step === 'housekeeping' && (
        <>
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Site Cleanup Checklist</Text>
            <Text style={styles.cardSub}>{doneRequiredHk.length} / {requiredHk.length} required items done</Text>
            {housekeeping.map(item => (
              <TouchableOpacity
                key={item.id}
                style={styles.hkRow}
                onPress={() => toggleHousekeeping(item.id)}
                activeOpacity={0.7}
              >
                <View style={[styles.hkCheck, item.done && styles.hkCheckDone]}>
                  {item.done && <Text style={styles.hkCheckMark}>✓</Text>}
                </View>
                <Text style={[styles.hkLabel, item.done && styles.hkLabelDone]}>{item.label}</Text>
                {item.required && !item.done && <Text style={styles.hkRequired}>*</Text>}
              </TouchableOpacity>
            ))}
          </View>

          {/* Missing housekeeping question */}
          {!allHkDone && (
            <View style={styles.card}>
              <Text style={styles.cardTitle}>Incomplete housekeeping items?</Text>
              <View style={styles.yesNoRow}>
                <TouchableOpacity
                  style={[styles.yesNoBtn, inventory.hasMissing === false && styles.yesNoBtnActive, { borderColor: C.green }]}
                  onPress={() => setHasMissing(false)}
                >
                  <Text style={[styles.yesNoBtnText, inventory.hasMissing === false && { color: C.white }]}>All Done</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.yesNoBtn, inventory.hasMissing === true && styles.yesNoBtnActiveRed, { borderColor: C.red }]}
                  onPress={() => setHasMissing(true)}
                >
                  <Text style={[styles.yesNoBtnText, inventory.hasMissing === true && { color: C.white }]}>Items Missing</Text>
                </TouchableOpacity>
              </View>
              {inventory.hasMissing === true && (
                <TextInput
                  style={styles.noteInput}
                  placeholder="Explain what's missing or why..."
                  placeholderTextColor={C.muted}
                  value={inventory.missingDetails}
                  onChangeText={setMissingDetails}
                  multiline
                />
              )}
            </View>
          )}

          <View style={styles.navRow}>
            <TouchableOpacity style={styles.prevBtn} onPress={() => setStep('inventory')}>
              <Text style={styles.prevBtnText}>← Back</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.nextBtn, styles.nextBtnFlex, (!allHkDone && inventory.hasMissing === null) && styles.nextBtnDisabled]}
              onPress={() => (allHkDone || inventory.hasMissing !== null) && setStep('photos')}
              disabled={!allHkDone && inventory.hasMissing === null}
            >
              <Text style={styles.nextBtnText}>Next: After Photos →</Text>
            </TouchableOpacity>
          </View>
        </>
      )}

      {/* ─── STEP 3: After Photos ─── */}
      {step === 'photos' && (
        <>
          {/* Hero after */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Hero After Photo *</Text>
            <Text style={styles.cardSub}>Best overall shot showing the completed work</Text>
            <TouchableOpacity
              style={[styles.heroPhotoBtn, heroAfter && styles.heroPhotoBtnDone]}
              onPress={() => handleAfterPhoto(true)}
              activeOpacity={0.8}
            >
              {heroAfter ? (
                <View style={styles.photoInner}>
                  <Text style={styles.photoCheck}>✓</Text>
                  <Text style={styles.photoCapturedLabel}>Hero photo captured</Text>
                  <Text style={styles.photoCapturedTime}>
                    {new Date(heroAfter.capturedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
                  </Text>
                </View>
              ) : (
                <View style={styles.photoInner}>
                  <Text style={styles.photoCameraIcon}>📷</Text>
                  <Text style={styles.photoCaptureLabel}>Tap to take hero photo</Text>
                </View>
              )}
            </TouchableOpacity>
          </View>

          {/* Additional after photos */}
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Additional After Photos</Text>
            <Text style={styles.cardSub}>{afterPhotos.length - (heroAfter ? 1 : 0)} additional taken</Text>
            <TouchableOpacity style={styles.addPhotoBtn} onPress={() => handleAfterPhoto(false)}>
              <Text style={styles.addPhotoBtnText}>+ Add After Photo</Text>
            </TouchableOpacity>
            {afterPhotos.length > 1 && (
              <View style={styles.photoStrip}>
                {afterPhotos.filter(p => p.category === 'after').map((p, i) => (
                  <View key={p.id} style={styles.photoThumb}>
                    <Text style={styles.photoThumbIcon}>📷</Text>
                    <Text style={styles.photoThumbNum}>#{i + 1}</Text>
                  </View>
                ))}
              </View>
            )}
          </View>

          <View style={styles.navRow}>
            <TouchableOpacity style={styles.prevBtn} onPress={() => setStep('housekeeping')}>
              <Text style={styles.prevBtnText}>← Back</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.nextBtn, styles.nextBtnFlex, !heroAfter && styles.nextBtnDisabled]}
              onPress={() => heroAfter && setStep('review')}
              disabled={!heroAfter}
            >
              <Text style={styles.nextBtnText}>Review →</Text>
            </TouchableOpacity>
          </View>
        </>
      )}

      {/* ─── STEP 4: Review & Submit ─── */}
      {step === 'review' && (
        <>
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Closeout Summary</Text>

            <View style={styles.reviewRow}>
              <Text style={styles.reviewLabel}>Inventory</Text>
              <Text style={[styles.reviewVal, { color: C.green }]}>
                {inventory.hasExcess ? '⚠ Excess noted' : '✓ No excess'}
              </Text>
            </View>

            <View style={styles.reviewRow}>
              <Text style={styles.reviewLabel}>Housekeeping</Text>
              <Text style={[styles.reviewVal, { color: allHkDone ? C.green : C.orange }]}>
                {allHkDone ? `✓ All ${housekeeping.length} items done` : `${doneRequiredHk.length}/${requiredHk.length} required done`}
              </Text>
            </View>

            <View style={styles.reviewRow}>
              <Text style={styles.reviewLabel}>After Photos</Text>
              <Text style={[styles.reviewVal, { color: heroAfter ? C.green : C.red }]}>
                {heroAfter ? `✓ ${afterPhotos.length} photo${afterPhotos.length !== 1 ? 's' : ''}` : '✕ Hero photo missing'}
              </Text>
            </View>

            {wo && (
              <View style={[styles.reviewRow, { borderTopWidth: 1, borderTopColor: C.border, paddingTop: 10, marginTop: 4 }]}>
                <Text style={styles.reviewLabel}>Work Order</Text>
                <Text style={[styles.reviewVal, { color: C.blue }]}>→ Awaiting QI</Text>
              </View>
            )}
          </View>

          <View style={styles.navRow}>
            <TouchableOpacity style={styles.prevBtn} onPress={() => setStep('photos')}>
              <Text style={styles.prevBtnText}>← Back</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.submitBtn, styles.nextBtnFlex]}
              onPress={handleSubmit}
              activeOpacity={0.85}
            >
              <Text style={styles.submitBtnText}>Submit Closeout ✓</Text>
            </TouchableOpacity>
          </View>
        </>
      )}
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
  headerTitle: { fontSize: 24, fontWeight: '900', color: C.white },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.6)' },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  cardTitle: { fontSize: 14, fontWeight: '700', color: C.text },
  cardSub: { fontSize: 12, color: C.muted, marginTop: -4 },

  stepName: { fontSize: 13, fontWeight: '600', color: C.muted, textAlign: 'center', marginTop: 4 },

  // Inventory
  invRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
    gap: 10,
  },
  invInfo: { flex: 1, gap: 2 },
  invLabel: { fontSize: 13, fontWeight: '600', color: C.text },
  invLoaded: { fontSize: 11, color: C.muted },
  invInputs: { flexDirection: 'row', gap: 8 },
  invField: { alignItems: 'center', gap: 3 },
  invFieldLabel: { fontSize: 9, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.5 },
  invInput: {
    width: 60,
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 8,
    padding: 6,
    fontSize: 14,
    fontWeight: '700',
    color: C.text,
    textAlign: 'center',
    backgroundColor: C.bg,
  },

  yesNoRow: { flexDirection: 'row', gap: 10 },
  yesNoBtn: {
    flex: 1,
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
    borderWidth: 2,
    backgroundColor: C.bg,
  },
  yesNoBtnActive: { backgroundColor: C.green, borderColor: C.green },
  yesNoBtnActiveRed: { backgroundColor: C.red, borderColor: C.red },
  yesNoBtnText: { fontSize: 13, fontWeight: '700', color: C.text },

  excessForm: { gap: 8, marginTop: 4 },
  noteInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 10,
    padding: 12,
    fontSize: 14,
    color: C.text,
    backgroundColor: C.bg,
    textAlignVertical: 'top',
    minHeight: 80,
  },
  photoBtn: {
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
    backgroundColor: C.white,
  },
  photoBtnDone: { borderColor: C.green, backgroundColor: C.green + '10' },
  photoBtnText: { fontSize: 13, fontWeight: '600', color: C.muted },
  photoBtnTextDone: { color: C.green },

  // Housekeeping
  hkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: C.border,
    gap: 12,
  },
  hkCheck: {
    width: 24,
    height: 24,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hkCheckDone: { backgroundColor: C.green, borderColor: C.green },
  hkCheckMark: { fontSize: 13, fontWeight: '800', color: C.white },
  hkLabel: { flex: 1, fontSize: 14, color: C.text, fontWeight: '500' },
  hkLabelDone: { color: C.muted, textDecorationLine: 'line-through' },
  hkRequired: { fontSize: 16, fontWeight: '700', color: C.red },

  // Photos
  heroPhotoBtn: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.border,
    borderRadius: 12,
    paddingVertical: 36,
    alignItems: 'center',
    backgroundColor: C.bg,
  },
  heroPhotoBtnDone: { borderStyle: 'solid', borderColor: C.green, backgroundColor: C.green + '08' },
  photoInner: { alignItems: 'center', gap: 6 },
  photoCheck: { fontSize: 40, color: C.green },
  photoCameraIcon: { fontSize: 40 },
  photoCapturedLabel: { fontSize: 14, fontWeight: '600', color: C.green },
  photoCaptureLabel: { fontSize: 14, fontWeight: '600', color: C.muted },
  photoCapturedTime: { fontSize: 11, color: C.muted },

  addPhotoBtn: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.blue + '60',
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: 'center',
  },
  addPhotoBtnText: { fontSize: 14, fontWeight: '600', color: C.blue },
  photoStrip: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  photoThumb: {
    width: 56,
    height: 56,
    borderRadius: 8,
    backgroundColor: C.bg,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  photoThumbIcon: { fontSize: 18 },
  photoThumbNum: { fontSize: 9, color: C.muted, fontWeight: '600' },

  // Review
  reviewRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 6 },
  reviewLabel: { fontSize: 13, color: C.muted, fontWeight: '500' },
  reviewVal: { fontSize: 13, fontWeight: '700' },

  // Nav
  navRow: { flexDirection: 'row', gap: 10 },
  prevBtn: {
    backgroundColor: C.bg,
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
  },
  prevBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
  nextBtn: {
    backgroundColor: C.blue,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  nextBtnFlex: { flex: 1 },
  nextBtnDisabled: { backgroundColor: C.border },
  nextBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
  submitBtn: {
    backgroundColor: C.green,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  submitBtnText: { fontSize: 15, fontWeight: '800', color: C.white },
});
