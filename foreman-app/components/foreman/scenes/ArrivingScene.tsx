import React, { useState } from 'react';
import {
  View, Text, TouchableOpacity, StyleSheet, TextInput, Alert, Platform, Linking,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';
import type { SfDeliveryLine, SfDeliveryQcResult, DeliveryQcVerdict } from '@/lib/foreman-types';

async function launchCamera(): Promise<boolean> {
  if (Platform.OS === 'web') return true;
  const { status } = await ImagePicker.requestCameraPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert('Camera Required', 'Enable camera access in Settings.');
    return false;
  }
  const r = await ImagePicker.launchCameraAsync({ quality: 0.85 });
  return !r.canceled;
}

function QcCard({ line, qc }: { line: SfDeliveryLine; qc: SfDeliveryQcResult }) {
  const setVerdict = useForeman(s => s.setDeliveryVerdict);
  const setQty = useForeman(s => s.setDeliveryVerifiedQty);
  const setNote = useForeman(s => s.setDeliveryNote);
  const capturePhoto = useForeman(s => s.captureDeliveryPhoto);
  const submitQc = useForeman(s => s.submitDeliveryQc);
  const [err, setErr] = useState('');

  const done = !!qc.submittedAt;
  const locked = qc.locked;

  async function handlePhoto() {
    const ok = await launchCamera();
    if (ok) capturePhoto(line.id);
  }

  function handleSubmit() {
    const r = submitQc(line.id);
    if (!r.ok) {
      const m: Record<string, string> = {
        'no-verdict': 'Select Confirmed or Issue.',
        'no-photo': 'Photo is required.',
        'no-note': 'Describe the issue.',
        'no-count': 'Enter actual quantity received.',
      };
      setErr(m[r.reason ?? ''] ?? 'Check all fields.');
      return;
    }
    setErr('');
    if (r.locked) Alert.alert('On Hold', 'Issue logged — your FM has been notified.');
  }

  return (
    <View style={[
      s.qcCard,
      locked && s.qcCardRed,
      done && !locked && s.qcCardGreen,
    ]}>
      <View style={s.qcCardAccent} style={[s.qcCardAccent, { backgroundColor: locked ? C.red : done ? C.green : C.orange }]} />

      <View style={s.qcHeader}>
        <View style={s.qcHeaderLeft}>
          <Text style={s.qcProduct}>{line.product}</Text>
          {line.species && <Text style={s.qcSpecies}>{line.species}</Text>}
        </View>
        {done && !locked && (
          <View style={s.confirmedPill}><Text style={s.confirmedPillText}>✓ CONFIRMED</Text></View>
        )}
        {locked && (
          <View style={s.issuePill}><Text style={s.issuePillText}>⚠ ON HOLD</Text></View>
        )}
      </View>

      <View style={s.qcMeta}>
        <Text style={s.qcMetaItem}>Expected <Text style={s.qcMetaVal}>{line.expectedQty} {line.unit}</Text></Text>
        <Text style={s.qcMetaItem}>Vendor <Text style={s.qcMetaVal}>{line.vendor}</Text></Text>
        <Text style={s.qcMetaItem}>PO# <Text style={s.qcMetaVal}>{line.poNumber}</Text></Text>
      </View>

      {locked ? (
        <View style={s.onHoldBox}>
          <Text style={s.onHoldTitle}>🔒 Delivery On Hold</Text>
          <Text style={s.onHoldBody}>FM must clear this before work can start.</Text>
        </View>
      ) : done ? (
        <Text style={s.doneNote}>
          Verified {qc.verifiedQty} {line.unit} ·{' '}
          {new Date(qc.submittedAt!).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
        </Text>
      ) : (
        <>
          <View style={s.fieldGroup}>
            <Text style={s.fieldLabel}>Actual qty received</Text>
            <TextInput
              style={s.input}
              keyboardType="numeric"
              placeholder={`Expected: ${line.expectedQty}`}
              placeholderTextColor={C.muted}
              value={qc.verifiedQty !== null ? String(qc.verifiedQty) : ''}
              onChangeText={t => setQty(line.id, t === '' ? null : Number(t))}
            />
          </View>

          <View style={s.verdictRow}>
            <TouchableOpacity
              style={[s.verdictBtn, s.verdictBtnGreen, qc.verdict === 'green' && s.verdictBtnGreenActive]}
              onPress={() => setVerdict(line.id, 'green')}
            >
              <Text style={[s.verdictLabel, qc.verdict === 'green' && s.verdictLabelActive]}>✓ Confirmed</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[s.verdictBtn, s.verdictBtnRed, qc.verdict === 'red' && s.verdictBtnRedActive]}
              onPress={() => setVerdict(line.id, 'red')}
            >
              <Text style={[s.verdictLabel, qc.verdict === 'red' && s.verdictLabelActive]}>⚠ Issue</Text>
            </TouchableOpacity>
          </View>

          {qc.verdict === 'red' && (
            <TextInput
              style={[s.input, s.inputMulti]}
              multiline
              placeholder="Short count, wrong species, damage..."
              placeholderTextColor={C.muted}
              value={qc.issueNote}
              onChangeText={n => setNote(line.id, n)}
            />
          )}

          <TouchableOpacity
            style={[s.photoBtn, qc.photoId && s.photoBtnDone]}
            onPress={handlePhoto}
          >
            <Text style={[s.photoBtnText, qc.photoId && s.photoBtnTextDone]}>
              {qc.photoId ? '📷  Photo captured ✓' : '📷  Take delivery photo *'}
            </Text>
          </TouchableOpacity>

          {!!err && <Text style={s.errText}>{err}</Text>}

          <TouchableOpacity
            style={[s.submitQcBtn, qc.verdict === 'pending' && s.submitQcBtnOff]}
            onPress={handleSubmit}
            disabled={qc.verdict === 'pending'}
          >
            <Text style={s.submitQcBtnText}>Submit QC</Text>
          </TouchableOpacity>
        </>
      )}
    </View>
  );
}

export function ArrivingScene() {
  const day = useForeman(sd => sd.day);
  const wo = useForeman(sd => sd.selectedWorkOrder)();
  const startJob = useForeman(sd => sd.startJob);
  const capturePhoto = useForeman(sd => sd.capturePhoto);
  const anyDeliveryLocked = useForeman(sd => sd.anyDeliveryLocked);
  const allDeliveriesCleared = useForeman(sd => sd.allDeliveriesCleared);

  const deliveries = wo?.deliveries ?? [];
  const qcResults = day.deliveryQc;
  const beforePhoto = day.photos.find(p => p.category === 'before');

  const locked = anyDeliveryLocked();
  const cleared = allDeliveriesCleared();
  const canStart = !!beforePhoto && cleared && !locked;

  async function handleBeforePhoto() {
    const ok = await launchCamera();
    if (ok) capturePhoto('before');
  }

  const arrivedTime = day.arrivedAt
    ? new Date(day.arrivedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  return (
    <View style={s.root}>
      {/* Job card */}
      <View style={s.jobCard}>
        <View style={s.jobCardRow}>
          <View style={{ flex: 1 }}>
            <Text style={s.jobCardLabel}>On Site</Text>
            <Text style={s.jobCardAddress}>{wo?.address ?? '—'}</Text>
            <Text style={s.jobCardSubject}>{wo?.subject}</Text>
          </View>
          {arrivedTime && (
            <View style={s.arrivedBadge}>
              <Text style={s.arrivedBadgeTime}>{arrivedTime}</Text>
              <Text style={s.arrivedBadgeLabel}>arrived</Text>
            </View>
          )}
        </View>

        <View style={s.jobBadgeRow}>
          {wo && <Text style={s.jobBadge}>{wo.woNumber}</Text>}
          {wo && <Text style={s.jobBadge}>{wo.workOrderType}</Text>}
          {wo && <Text style={s.jobBadge}>{wo.sodSqft.toLocaleString()} sq ft</Text>}
        </View>

        {wo?.fieldManager && (
          <TouchableOpacity
            style={s.callFmRow}
            onPress={() => Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
          >
            <Text style={s.callFmText}>📞  {wo.fieldManager.name}  ·  {wo.fieldManager.phone}</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Before photo */}
      <View style={s.card}>
        <Text style={s.sectionLabel}>Before Site Photo</Text>
        <TouchableOpacity
          style={[s.photoCapture, beforePhoto && s.photoCaptureDone]}
          onPress={handleBeforePhoto}
          activeOpacity={0.8}
        >
          {beforePhoto ? (
            <View style={s.photoCaptureInner}>
              <Text style={s.photoCheck}>✓</Text>
              <Text style={s.photoCaptureLabel}>Before photo captured</Text>
              <Text style={s.photoCaptureTime}>
                {new Date(beforePhoto.capturedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
              </Text>
            </View>
          ) : (
            <View style={s.photoCaptureInner}>
              <Text style={s.photoCameraIcon}>📷</Text>
              <Text style={s.photoCaptureLabel}>Tap to capture before-site photo</Text>
            </View>
          )}
        </TouchableOpacity>
      </View>

      {/* Delivery QC */}
      {deliveries.length > 0 && (
        <View style={s.card}>
          <Text style={s.sectionLabel}>Delivery Quality Check</Text>
          <Text style={s.sectionSub}>Verify each delivery before starting work</Text>
          {deliveries.map(line => {
            const qc = qcResults.find(r => r.deliveryLineId === line.id) ?? {
              deliveryLineId: line.id, verdict: 'pending' as const,
              verifiedQty: null, issueNote: '', locked: false,
            };
            return <QcCard key={line.id} line={line} qc={qc} />;
          })}
        </View>
      )}

      {locked && (
        <View style={s.holdBanner}>
          <Text style={s.holdBannerTitle}>⚠  Work Order On Hold</Text>
          <Text style={s.holdBannerText}>A delivery issue is blocking this job. Your FM must clear it before work begins.</Text>
        </View>
      )}

      {canStart ? (
        <TouchableOpacity style={s.startBtn} onPress={startJob} activeOpacity={0.88}>
          <Text style={s.startBtnText}>Start Job →</Text>
        </TouchableOpacity>
      ) : (
        <View style={s.startBtnOff}>
          <Text style={s.startBtnOffText}>
            {!beforePhoto ? 'Take before photo to continue'
              : locked ? 'Resolve delivery issue to continue'
              : 'Complete all delivery QC to continue'}
          </Text>
        </View>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  root: { gap: 12 },

  jobCard: {
    backgroundColor: C.navy,
    borderRadius: R.lg,
    padding: 20,
    gap: 12,
    ...Sh.md,
  },
  jobCardRow: { flexDirection: 'row', gap: 12 },
  jobCardLabel: { fontSize: 10, fontWeight: '700', color: 'rgba(255,255,255,0.45)', textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 4 },
  jobCardAddress: { fontSize: 19, fontWeight: '800', color: C.white, lineHeight: 25 },
  jobCardSubject: { fontSize: 13, color: 'rgba(255,255,255,0.6)', marginTop: 3 },
  arrivedBadge: { backgroundColor: C.green, borderRadius: R.sm, paddingHorizontal: 12, paddingVertical: 8, alignItems: 'center', justifyContent: 'center', gap: 2 },
  arrivedBadgeTime: { fontSize: 17, fontWeight: '800', color: C.white },
  arrivedBadgeLabel: { fontSize: 9, fontWeight: '700', color: 'rgba(255,255,255,0.7)', textTransform: 'uppercase', letterSpacing: 0.8 },
  jobBadgeRow: { flexDirection: 'row', gap: 6, flexWrap: 'wrap' },
  jobBadge: { backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: R.xs, paddingHorizontal: 8, paddingVertical: 3, fontSize: 11, fontWeight: '600', color: 'rgba(255,255,255,0.8)' },
  callFmRow: { backgroundColor: C.blue, borderRadius: R.sm, paddingVertical: 10, alignItems: 'center' },
  callFmText: { fontSize: 13, fontWeight: '700', color: C.white },

  card: {
    backgroundColor: C.card,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    ...Sh.xs,
  },
  sectionLabel: { fontSize: 10, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 1.2 },
  sectionSub: { fontSize: 12, color: C.muted, marginTop: -4 },

  photoCapture: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.border,
    borderRadius: R.md,
    paddingVertical: 30,
    alignItems: 'center',
    backgroundColor: C.bg,
  },
  photoCaptureDone: { borderStyle: 'solid', borderColor: C.green, backgroundColor: C.green + '0d' },
  photoCaptureInner: { alignItems: 'center', gap: 6 },
  photoCameraIcon: { fontSize: 34 },
  photoCheck: { fontSize: 38, color: C.green },
  photoCaptureLabel: { fontSize: 14, fontWeight: '600', color: C.muted },
  photoCaptureTime: { fontSize: 11, color: C.muted },

  qcCard: {
    borderRadius: R.sm,
    borderWidth: 1,
    borderColor: C.border,
    overflow: 'hidden',
    backgroundColor: C.bg,
    gap: 0,
  },
  qcCardRed: { borderColor: C.red + '50' },
  qcCardGreen: { borderColor: C.green + '50' },
  qcCardAccent: { height: 4, width: '100%' } as any,
  qcHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, padding: 12, paddingBottom: 6 },
  qcHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 8, flex: 1 },
  qcProduct: { backgroundColor: C.navy, color: C.white, fontSize: 11, fontWeight: '700', borderRadius: 4, paddingHorizontal: 7, paddingVertical: 3, overflow: 'hidden' },
  qcSpecies: { fontSize: 13, fontWeight: '600', color: C.text, flex: 1 },
  confirmedPill: { backgroundColor: C.green + '20', borderRadius: 4, paddingHorizontal: 7, paddingVertical: 3 },
  confirmedPillText: { fontSize: 10, fontWeight: '800', color: C.green, letterSpacing: 0.5 },
  issuePill: { backgroundColor: C.red + '20', borderRadius: 4, paddingHorizontal: 7, paddingVertical: 3 },
  issuePillText: { fontSize: 10, fontWeight: '800', color: C.red, letterSpacing: 0.5 },
  qcMeta: { paddingHorizontal: 12, paddingBottom: 10, gap: 2 },
  qcMetaItem: { fontSize: 12, color: C.muted },
  qcMetaVal: { fontWeight: '600', color: C.text },
  onHoldBox: { margin: 12, backgroundColor: C.red + '0d', borderRadius: R.xs, padding: 10, gap: 3 },
  onHoldTitle: { fontSize: 13, fontWeight: '700', color: C.red },
  onHoldBody: { fontSize: 12, color: C.text2 },
  doneNote: { paddingHorizontal: 12, paddingBottom: 12, fontSize: 12, color: C.green, fontWeight: '600' },

  fieldGroup: { paddingHorizontal: 12, gap: 4 },
  fieldLabel: { fontSize: 11, fontWeight: '600', color: C.muted },
  input: {
    borderWidth: 1, borderColor: C.border, borderRadius: R.sm,
    padding: 10, fontSize: 15, color: C.text, backgroundColor: C.white,
  },
  inputMulti: { minHeight: 70, textAlignVertical: 'top', marginHorizontal: 12, marginTop: 4 },
  verdictRow: { flexDirection: 'row', gap: 8, paddingHorizontal: 12, paddingTop: 4 },
  verdictBtn: { flex: 1, borderRadius: R.sm, paddingVertical: 10, alignItems: 'center', borderWidth: 2 },
  verdictBtnGreen: { borderColor: C.green, backgroundColor: C.green + '0d' },
  verdictBtnGreenActive: { backgroundColor: C.green },
  verdictBtnRed: { borderColor: C.red, backgroundColor: C.red + '0d' },
  verdictBtnRedActive: { backgroundColor: C.red },
  verdictLabel: { fontSize: 13, fontWeight: '700', color: C.text2 },
  verdictLabelActive: { color: C.white },
  photoBtn: { marginHorizontal: 12, borderRadius: R.sm, paddingVertical: 10, alignItems: 'center', borderWidth: 1, borderColor: C.border, backgroundColor: C.white },
  photoBtnDone: { borderColor: C.green, backgroundColor: C.green + '0d' },
  photoBtnText: { fontSize: 13, fontWeight: '600', color: C.muted },
  photoBtnTextDone: { color: C.green },
  errText: { paddingHorizontal: 12, fontSize: 12, color: C.red, fontWeight: '600' },
  submitQcBtn: { margin: 12, marginTop: 4, backgroundColor: C.blue, borderRadius: R.sm, paddingVertical: 11, alignItems: 'center' },
  submitQcBtnOff: { backgroundColor: C.border },
  submitQcBtnText: { fontSize: 14, fontWeight: '700', color: C.white },

  holdBanner: { backgroundColor: C.red + '0d', borderRadius: R.md, padding: 16, borderWidth: 1, borderColor: C.red + '40', gap: 4 },
  holdBannerTitle: { fontSize: 14, fontWeight: '700', color: C.red },
  holdBannerText: { fontSize: 13, color: C.text2, lineHeight: 18 },

  startBtn: { backgroundColor: C.green, borderRadius: R.md, paddingVertical: 16, alignItems: 'center', ...Sh.sm },
  startBtnText: { fontSize: 17, fontWeight: '800', color: C.white, letterSpacing: 0.3 },
  startBtnOff: { backgroundColor: C.divider, borderRadius: R.md, paddingVertical: 16, alignItems: 'center', borderWidth: 1, borderColor: C.border },
  startBtnOffText: { fontSize: 14, fontWeight: '600', color: C.muted },
});
