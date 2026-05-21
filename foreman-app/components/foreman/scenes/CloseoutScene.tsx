import React, { useState } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet, TextInput, Alert, Platform,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

type Step = 'inventory' | 'housekeeping' | 'photos' | 'review';

async function launchCamera(): Promise<boolean> {
  if (Platform.OS === 'web') return true;
  const { status } = await ImagePicker.requestCameraPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert('Camera Required', 'Enable camera access to take closeout photos.');
    return false;
  }
  const r = await ImagePicker.launchCameraAsync({ quality: 0.85 });
  return !r.canceled;
}

const STEP_LIST: Step[] = ['inventory', 'housekeeping', 'photos', 'review'];
const STEP_LABELS: Record<Step, string> = {
  inventory: 'Inventory',
  housekeeping: 'Housekeeping',
  photos: 'After Photos',
  review: 'Submit',
};

function Steps({ current }: { current: Step }) {
  const cur = STEP_LIST.indexOf(current);
  return (
    <View style={st.stepsRow}>
      {STEP_LIST.map((step, i) => {
        const done = i < cur;
        const active = i === cur;
        return (
          <React.Fragment key={step}>
            <View style={[st.stepDot, done && st.stepDotDone, active && st.stepDotActive]}>
              {done
                ? <Text style={st.stepDotCheck}>✓</Text>
                : <Text style={[st.stepDotNum, active && st.stepDotNumActive]}>{i + 1}</Text>
              }
            </View>
            {i < STEP_LIST.length - 1 && (
              <View style={[st.stepLine, i < cur && st.stepLineDone]} />
            )}
          </React.Fragment>
        );
      })}
    </View>
  );
}

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

  const wo = day.workOrders.find(w => w.id === day.selectedWorkOrderId);
  const heroAfter = day.photos.find(p => p.category === 'hero-after');
  const afterPhotos = day.photos.filter(p => p.category === 'after' || p.category === 'hero-after');

  const requiredHk = housekeeping.filter(h => h.required);
  const doneRequiredHk = requiredHk.filter(h => h.done);
  const allHkDone = doneRequiredHk.length === requiredHk.length;

  async function handleExcessPhoto() {
    const ok = await launchCamera();
    if (ok) captureExcessPhoto();
  }

  async function handleAfterPhoto(hero: boolean) {
    const ok = await launchCamera();
    if (ok) capturePhoto(hero ? 'hero-after' : 'after');
  }

  function handleSubmit() {
    if (!heroAfter) {
      Alert.alert('Required', 'Take the hero after photo before submitting.');
      return;
    }
    Alert.alert(
      'Submit Closeout',
      'This will mark the job as Awaiting QI.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Submit', style: 'default', onPress: submitCloseout },
      ]
    );
  }

  const canGoToHk = inventory.hasExcess !== null;
  const canGoToPhotos = allHkDone || inventory.hasMissing !== null;
  const canReview = !!heroAfter;

  return (
    <View style={st.root}>
      {/* Header */}
      <View style={st.header}>
        <View>
          <Text style={st.headerTitle}>Closeout</Text>
          {wo && <Text style={st.headerSub}>{wo.woNumber}  ·  {wo.subject}</Text>}
        </View>
        <View style={st.stepLabel}>
          <Text style={st.stepLabelText}>{STEP_LABELS[step]}</Text>
          <Text style={st.stepLabelCount}>{STEP_LIST.indexOf(step) + 1} / {STEP_LIST.length}</Text>
        </View>
      </View>

      {/* Step indicator */}
      <View style={st.stepsCard}>
        <Steps current={step} />
        <View style={st.stepsLabelRow}>
          {STEP_LIST.map((s2, i) => (
            <Text key={s2} style={[st.stepNameLabel, i === STEP_LIST.indexOf(step) && st.stepNameLabelActive]}>
              {STEP_LABELS[s2]}
            </Text>
          ))}
        </View>
      </View>

      {/* ── STEP 1: Inventory & Excess ── */}
      {step === 'inventory' && (
        <>
          <View style={st.card}>
            <Text style={st.sectionLabel}>Material Reconciliation</Text>
            {inventory.items.map(item => (
              <View key={item.id} style={st.invRow}>
                <View style={st.invInfo}>
                  <Text style={st.invLabel}>{item.label}</Text>
                  <Text style={st.invLoaded}>Loaded: {item.loaded} {item.unit}</Text>
                </View>
                <View style={st.invInputs}>
                  <View style={st.invField}>
                    <Text style={st.invFieldLabel}>Used</Text>
                    <TextInput
                      style={st.invInput}
                      keyboardType="numeric"
                      placeholder="—"
                      placeholderTextColor={C.muted}
                      value={item.used !== null ? String(item.used) : ''}
                      onChangeText={t => setInventoryUsed(item.id, t === '' ? null : Number(t))}
                    />
                  </View>
                  <View style={st.invField}>
                    <Text style={st.invFieldLabel}>Return</Text>
                    <TextInput
                      style={st.invInput}
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

          <View style={st.card}>
            <Text style={st.sectionLabel}>Excess Inventory on Site?</Text>
            <Text style={st.sectionSub}>Any leftover materials not returned to truck</Text>
            <View style={st.ynRow}>
              <TouchableOpacity
                style={[st.ynBtn, st.ynBtnGreen, inventory.hasExcess === false && st.ynBtnGreenActive]}
                onPress={() => setHasExcess(false)}
              >
                <Text style={[st.ynLabel, inventory.hasExcess === false && st.ynLabelActive]}>No Excess</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[st.ynBtn, st.ynBtnOrange, inventory.hasExcess === true && st.ynBtnOrangeActive]}
                onPress={() => setHasExcess(true)}
              >
                <Text style={[st.ynLabel, inventory.hasExcess === true && st.ynLabelActive]}>Yes, Has Excess</Text>
              </TouchableOpacity>
            </View>

            {inventory.hasExcess === true && (
              <View style={st.excessExpand}>
                <TextInput
                  style={st.textArea}
                  placeholder="Describe excess — what and how much..."
                  placeholderTextColor={C.muted}
                  value={inventory.excessDetails}
                  onChangeText={setExcessDetails}
                  multiline
                />
                <TouchableOpacity
                  style={[st.photoBtn, inventory.excessPhotoCaptured && st.photoBtnDone]}
                  onPress={handleExcessPhoto}
                >
                  <Text style={[st.photoBtnText, inventory.excessPhotoCaptured && st.photoBtnTextDone]}>
                    {inventory.excessPhotoCaptured ? '📷  Excess photo captured ✓' : '📷  Photo of excess'}
                  </Text>
                </TouchableOpacity>
              </View>
            )}
          </View>

          <TouchableOpacity
            style={[st.nextBtn, !canGoToHk && st.nextBtnOff]}
            onPress={() => canGoToHk && setStep('housekeeping')}
            disabled={!canGoToHk}
          >
            <Text style={st.nextBtnText}>Next: Housekeeping →</Text>
          </TouchableOpacity>
        </>
      )}

      {/* ── STEP 2: Housekeeping ── */}
      {step === 'housekeeping' && (
        <>
          <View style={st.card}>
            <Text style={st.sectionLabel}>Site Cleanup</Text>
            <Text style={st.sectionSub}>{doneRequiredHk.length} / {requiredHk.length} required items complete</Text>

            <View style={st.hkProgressBar}>
              <View
                style={[st.hkProgressFill, {
                  width: requiredHk.length > 0
                    ? `${Math.round((doneRequiredHk.length / requiredHk.length) * 100)}%` as any
                    : '100%',
                  backgroundColor: allHkDone ? C.green : C.blue,
                }]}
              />
            </View>

            {housekeeping.map(item => (
              <TouchableOpacity
                key={item.id}
                style={st.hkRow}
                onPress={() => toggleHousekeeping(item.id)}
                activeOpacity={0.7}
              >
                <View style={[st.hkBox, item.done && st.hkBoxDone]}>
                  {item.done && <Text style={st.hkCheck}>✓</Text>}
                </View>
                <Text style={[st.hkLabel, item.done && st.hkLabelDone]}>{item.label}</Text>
                {item.required && !item.done && <View style={st.reqDot} />}
              </TouchableOpacity>
            ))}
          </View>

          {!allHkDone && (
            <View style={st.card}>
              <Text style={st.sectionLabel}>Incomplete housekeeping?</Text>
              <View style={st.ynRow}>
                <TouchableOpacity
                  style={[st.ynBtn, st.ynBtnGreen, inventory.hasMissing === false && st.ynBtnGreenActive]}
                  onPress={() => setHasMissing(false)}
                >
                  <Text style={[st.ynLabel, inventory.hasMissing === false && st.ynLabelActive]}>All Done</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[st.ynBtn, st.ynBtnRed, inventory.hasMissing === true && st.ynBtnRedActive]}
                  onPress={() => setHasMissing(true)}
                >
                  <Text style={[st.ynLabel, inventory.hasMissing === true && st.ynLabelActive]}>Some Missing</Text>
                </TouchableOpacity>
              </View>
              {inventory.hasMissing === true && (
                <TextInput
                  style={st.textArea}
                  placeholder="Explain what's incomplete and why..."
                  placeholderTextColor={C.muted}
                  value={inventory.missingDetails}
                  onChangeText={setMissingDetails}
                  multiline
                />
              )}
            </View>
          )}

          <View style={st.navRow}>
            <TouchableOpacity style={st.backBtn} onPress={() => setStep('inventory')}>
              <Text style={st.backBtnText}>← Back</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[st.nextBtn, st.nextBtnFlex, !canGoToPhotos && st.nextBtnOff]}
              onPress={() => canGoToPhotos && setStep('photos')}
              disabled={!canGoToPhotos}
            >
              <Text style={st.nextBtnText}>After Photos →</Text>
            </TouchableOpacity>
          </View>
        </>
      )}

      {/* ── STEP 3: After Photos ── */}
      {step === 'photos' && (
        <>
          <View style={st.card}>
            <Text style={st.sectionLabel}>Hero After Photo  <Text style={{ color: C.red }}>*</Text></Text>
            <Text style={st.sectionSub}>Best overall shot of the completed work</Text>
            <TouchableOpacity
              style={[st.heroPicBtn, heroAfter && st.heroPicBtnDone]}
              onPress={() => handleAfterPhoto(true)}
              activeOpacity={0.8}
            >
              {heroAfter ? (
                <View style={st.picInner}>
                  <Text style={st.picCheck}>✓</Text>
                  <Text style={st.picCapturedLabel}>Hero photo captured</Text>
                  <Text style={st.picCapturedTime}>
                    {new Date(heroAfter.capturedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
                  </Text>
                </View>
              ) : (
                <View style={st.picInner}>
                  <Text style={st.picCamera}>📷</Text>
                  <Text style={st.picPlaceholder}>Tap to take hero photo</Text>
                </View>
              )}
            </TouchableOpacity>
          </View>

          <View style={st.card}>
            <Text style={st.sectionLabel}>Additional Photos</Text>
            <Text style={st.sectionSub}>{afterPhotos.filter(p => p.category === 'after').length} additional taken</Text>
            <TouchableOpacity style={st.addPhotoBtn} onPress={() => handleAfterPhoto(false)}>
              <Text style={st.addPhotoBtnText}>+ Add Photo</Text>
            </TouchableOpacity>
            {afterPhotos.filter(p => p.category === 'after').length > 0 && (
              <View style={st.thumbStrip}>
                {afterPhotos.filter(p => p.category === 'after').map((p, i) => (
                  <View key={p.id} style={st.thumb}>
                    <Text style={st.thumbIcon}>📷</Text>
                    <Text style={st.thumbNum}>#{i + 1}</Text>
                  </View>
                ))}
              </View>
            )}
          </View>

          <View style={st.navRow}>
            <TouchableOpacity style={st.backBtn} onPress={() => setStep('housekeeping')}>
              <Text style={st.backBtnText}>← Back</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[st.nextBtn, st.nextBtnFlex, !canReview && st.nextBtnOff]}
              onPress={() => canReview && setStep('review')}
              disabled={!canReview}
            >
              <Text style={st.nextBtnText}>Review →</Text>
            </TouchableOpacity>
          </View>
        </>
      )}

      {/* ── STEP 4: Review ── */}
      {step === 'review' && (
        <>
          <View style={st.card}>
            <Text style={st.sectionLabel}>Closeout Summary</Text>

            <View style={st.reviewRow}>
              <Text style={st.reviewKey}>Inventory</Text>
              <View style={[st.reviewPill, { backgroundColor: inventory.hasExcess ? C.orange + '20' : C.green + '15' }]}>
                <Text style={[st.reviewPillText, { color: inventory.hasExcess ? C.orange : C.green }]}>
                  {inventory.hasExcess ? '⚠ Excess noted' : '✓ No excess'}
                </Text>
              </View>
            </View>

            <View style={st.reviewRow}>
              <Text style={st.reviewKey}>Housekeeping</Text>
              <View style={[st.reviewPill, { backgroundColor: allHkDone ? C.green + '15' : C.orange + '20' }]}>
                <Text style={[st.reviewPillText, { color: allHkDone ? C.green : C.orange }]}>
                  {allHkDone ? `✓ ${housekeeping.length} items done` : `${doneRequiredHk.length}/${requiredHk.length} required`}
                </Text>
              </View>
            </View>

            <View style={st.reviewRow}>
              <Text style={st.reviewKey}>After Photos</Text>
              <View style={[st.reviewPill, { backgroundColor: C.green + '15' }]}>
                <Text style={[st.reviewPillText, { color: C.green }]}>
                  ✓ {afterPhotos.length} photo{afterPhotos.length !== 1 ? 's' : ''}
                </Text>
              </View>
            </View>

            <View style={[st.reviewRow, st.reviewRowFinal]}>
              <Text style={st.reviewKey}>Work Order Status</Text>
              <View style={[st.reviewPill, { backgroundColor: C.blue + '15' }]}>
                <Text style={[st.reviewPillText, { color: C.blue }]}>→ Awaiting QI</Text>
              </View>
            </View>
          </View>

          <View style={st.navRow}>
            <TouchableOpacity style={st.backBtn} onPress={() => setStep('photos')}>
              <Text style={st.backBtnText}>← Back</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[st.submitBtn, st.nextBtnFlex]} onPress={handleSubmit} activeOpacity={0.88}>
              <Text style={st.submitBtnText}>✓  Submit Closeout</Text>
            </TouchableOpacity>
          </View>
        </>
      )}
    </View>
  );
}

const st = StyleSheet.create({
  root: { gap: 12 },

  header: {
    backgroundColor: C.navy,
    borderRadius: R.lg,
    padding: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    ...Sh.sm,
  },
  headerTitle: { fontSize: 24, fontWeight: '900', color: C.white },
  headerSub: { fontSize: 12, color: 'rgba(255,255,255,0.5)', marginTop: 3 },
  stepLabel: { alignItems: 'flex-end' },
  stepLabelText: { fontSize: 13, fontWeight: '700', color: C.orange },
  stepLabelCount: { fontSize: 10, color: 'rgba(255,255,255,0.4)', marginTop: 2 },

  stepsCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 8,
    ...Sh.xs,
  },
  stepsRow: { flexDirection: 'row', alignItems: 'center' },
  stepDot: {
    width: 28, height: 28, borderRadius: 14,
    backgroundColor: C.border, alignItems: 'center', justifyContent: 'center',
  },
  stepDotDone: { backgroundColor: C.green },
  stepDotActive: { backgroundColor: C.blue },
  stepDotCheck: { fontSize: 12, fontWeight: '800', color: C.white },
  stepDotNum: { fontSize: 12, fontWeight: '700', color: C.muted },
  stepDotNumActive: { color: C.white },
  stepLine: { flex: 1, height: 2, backgroundColor: C.border },
  stepLineDone: { backgroundColor: C.green },
  stepsLabelRow: { flexDirection: 'row', justifyContent: 'space-between' },
  stepNameLabel: { fontSize: 9, color: C.muted, textAlign: 'center', flex: 1 },
  stepNameLabelActive: { color: C.blue, fontWeight: '700' },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    ...Sh.xs,
  },
  sectionLabel: { fontSize: 10, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 1.2 },
  sectionSub: { fontSize: 12, color: C.muted, marginTop: -4 },

  invRow: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: C.divider, gap: 10,
  },
  invInfo: { flex: 1, gap: 2 },
  invLabel: { fontSize: 13, fontWeight: '600', color: C.text },
  invLoaded: { fontSize: 11, color: C.muted },
  invInputs: { flexDirection: 'row', gap: 8 },
  invField: { alignItems: 'center', gap: 3 },
  invFieldLabel: { fontSize: 9, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.5 },
  invInput: {
    width: 64, borderWidth: 1, borderColor: C.border,
    borderRadius: R.sm, padding: 8, fontSize: 15,
    fontWeight: '700', color: C.text, textAlign: 'center', backgroundColor: C.bg,
  },

  ynRow: { flexDirection: 'row', gap: 10 },
  ynBtn: { flex: 1, borderRadius: R.sm, paddingVertical: 12, alignItems: 'center', borderWidth: 2 },
  ynBtnGreen: { borderColor: C.green, backgroundColor: C.green + '0d' },
  ynBtnGreenActive: { backgroundColor: C.green },
  ynBtnOrange: { borderColor: C.orange, backgroundColor: C.orange + '0d' },
  ynBtnOrangeActive: { backgroundColor: C.orange },
  ynBtnRed: { borderColor: C.red, backgroundColor: C.red + '0d' },
  ynBtnRedActive: { backgroundColor: C.red },
  ynLabel: { fontSize: 13, fontWeight: '700', color: C.text2 },
  ynLabelActive: { color: C.white },

  excessExpand: { gap: 8 },
  textArea: {
    borderWidth: 1, borderColor: C.border, borderRadius: R.sm,
    padding: 12, fontSize: 14, color: C.text,
    backgroundColor: C.bg, textAlignVertical: 'top', minHeight: 80,
  },
  photoBtn: {
    borderRadius: R.sm, paddingVertical: 11, alignItems: 'center',
    borderWidth: 1, borderColor: C.border, backgroundColor: C.white,
  },
  photoBtnDone: { borderColor: C.green, backgroundColor: C.green + '0d' },
  photoBtnText: { fontSize: 13, fontWeight: '600', color: C.muted },
  photoBtnTextDone: { color: C.green },

  hkProgressBar: { height: 6, backgroundColor: C.divider, borderRadius: 3, overflow: 'hidden' },
  hkProgressFill: { height: '100%', borderRadius: 3 },
  hkRow: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 11, borderBottomWidth: 1, borderBottomColor: C.divider, gap: 12,
  },
  hkBox: {
    width: 24, height: 24, borderRadius: R.xs,
    borderWidth: 2, borderColor: C.border,
    alignItems: 'center', justifyContent: 'center',
  },
  hkBoxDone: { backgroundColor: C.green, borderColor: C.green },
  hkCheck: { fontSize: 13, fontWeight: '800', color: C.white },
  hkLabel: { flex: 1, fontSize: 14, color: C.text, fontWeight: '500' },
  hkLabelDone: { color: C.muted, textDecorationLine: 'line-through' },
  reqDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: C.red },

  heroPicBtn: {
    borderWidth: 2, borderStyle: 'dashed', borderColor: C.border,
    borderRadius: R.md, paddingVertical: 36, alignItems: 'center', backgroundColor: C.bg,
  },
  heroPicBtnDone: { borderStyle: 'solid', borderColor: C.green, backgroundColor: C.green + '08' },
  picInner: { alignItems: 'center', gap: 6 },
  picCamera: { fontSize: 40 },
  picCheck: { fontSize: 42, color: C.green },
  picCapturedLabel: { fontSize: 14, fontWeight: '700', color: C.green },
  picCapturedTime: { fontSize: 11, color: C.muted },
  picPlaceholder: { fontSize: 14, fontWeight: '600', color: C.muted },
  addPhotoBtn: {
    borderWidth: 2, borderStyle: 'dashed', borderColor: C.blue + '60',
    borderRadius: R.sm, paddingVertical: 12, alignItems: 'center',
  },
  addPhotoBtnText: { fontSize: 14, fontWeight: '600', color: C.blue },
  thumbStrip: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  thumb: {
    width: 56, height: 56, borderRadius: R.sm,
    backgroundColor: C.bg, borderWidth: 1, borderColor: C.border,
    alignItems: 'center', justifyContent: 'center', gap: 2,
  },
  thumbIcon: { fontSize: 18 },
  thumbNum: { fontSize: 9, color: C.muted, fontWeight: '600' },

  reviewRow: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8,
    borderBottomWidth: 1, borderBottomColor: C.divider,
  },
  reviewRowFinal: { borderBottomWidth: 0 },
  reviewKey: { fontSize: 13, color: C.muted },
  reviewPill: { borderRadius: R.xs, paddingHorizontal: 8, paddingVertical: 4 },
  reviewPillText: { fontSize: 12, fontWeight: '700' },

  navRow: { flexDirection: 'row', gap: 10 },
  backBtn: {
    backgroundColor: C.bg, borderRadius: R.md,
    paddingVertical: 14, paddingHorizontal: 18,
    borderWidth: 1, borderColor: C.border, alignItems: 'center',
  },
  backBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
  nextBtn: {
    backgroundColor: C.blue, borderRadius: R.md,
    paddingVertical: 14, alignItems: 'center',
    paddingHorizontal: 18,
  },
  nextBtnFlex: { flex: 1 },
  nextBtnOff: { backgroundColor: C.border },
  nextBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
  submitBtn: { backgroundColor: C.green, borderRadius: R.md, paddingVertical: 16, alignItems: 'center', ...Sh.sm },
  submitBtnText: { fontSize: 16, fontWeight: '800', color: C.white, letterSpacing: 0.3 },
});
