import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInput,
  Alert,
  Platform,
  Linking,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
import type { SfDeliveryLine, SfDeliveryQcResult, DeliveryQcVerdict } from '@/lib/foreman-types';

async function openCamera(): Promise<boolean> {
  if (Platform.OS === 'web') return true;
  const { status } = await ImagePicker.requestCameraPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert('Camera Required', 'Enable camera access in Settings to take site photos.');
    return false;
  }
  const result = await ImagePicker.launchCameraAsync({ quality: 0.85 });
  return !result.canceled;
}

function DeliveryQcCard({
  line,
  qc,
}: {
  line: SfDeliveryLine;
  qc: SfDeliveryQcResult;
}) {
  const setVerdict = useForeman(s => s.setDeliveryVerdict);
  const setQty = useForeman(s => s.setDeliveryVerifiedQty);
  const setNote = useForeman(s => s.setDeliveryNote);
  const capturePhoto = useForeman(s => s.captureDeliveryPhoto);
  const submitQc = useForeman(s => s.submitDeliveryQc);
  const [error, setError] = useState('');

  const submitted = !!qc.submittedAt;
  const locked = qc.locked;

  async function handlePhoto() {
    const ok = await openCamera();
    if (ok) capturePhoto(line.id);
  }

  function handleSubmit() {
    const r = submitQc(line.id);
    if (!r.ok) {
      const msgs: Record<string, string> = {
        'no-verdict': 'Select Confirmed or Issue.',
        'no-photo': 'Photo required.',
        'no-note': 'Describe the issue.',
        'no-count': 'Enter actual quantity received.',
      };
      setError(msgs[r.reason ?? ''] ?? 'Check all fields.');
      return;
    }
    setError('');
    if (r.locked) Alert.alert('Delivery On Hold', 'Your FM has been notified of the issue.');
  }

  return (
    <View style={[styles.deliveryCard, locked && styles.deliveryCardRed, submitted && !locked && styles.deliveryCardGreen]}>
      <View style={styles.deliveryCardHeader}>
        <View style={styles.productTag}>
          <Text style={styles.productTagText}>{line.product}</Text>
        </View>
        {line.species && <Text style={styles.speciesText}>{line.species}</Text>}
        {submitted && !locked && (
          <View style={styles.confirmedBadge}><Text style={styles.confirmedBadgeText}>✓ Confirmed</Text></View>
        )}
        {locked && (
          <View style={styles.issueBadge}><Text style={styles.issueBadgeText}>⚠ On Hold</Text></View>
        )}
      </View>

      <View style={styles.deliveryMeta}>
        <Text style={styles.metaItem}>Expected <Text style={styles.metaVal}>{line.expectedQty} {line.unit}</Text></Text>
        <Text style={styles.metaItem}>Vendor <Text style={styles.metaVal}>{line.vendor}</Text></Text>
        <Text style={styles.metaItem}>PO <Text style={styles.metaVal}>{line.poNumber}</Text></Text>
      </View>

      {locked ? (
        <View style={styles.onHoldBox}>
          <Text style={styles.onHoldTitle}>🔒 Delivery On Hold</Text>
          <Text style={styles.onHoldText}>FM must clear this before work can start.</Text>
        </View>
      ) : submitted ? (
        <Text style={styles.submittedNote}>
          Verified {qc.verifiedQty} {line.unit} · submitted {new Date(qc.submittedAt!).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
        </Text>
      ) : (
        <>
          {/* Count */}
          <View style={styles.fieldGroup}>
            <Text style={styles.fieldLabel}>Actual qty received *</Text>
            <TextInput
              style={styles.input}
              keyboardType="numeric"
              placeholder={`Expected: ${line.expectedQty}`}
              placeholderTextColor={C.muted}
              value={qc.verifiedQty !== null ? String(qc.verifiedQty) : ''}
              onChangeText={t => setQty(line.id, t === '' ? null : Number(t))}
            />
          </View>

          {/* Verdict */}
          <View style={styles.verdictRow}>
            <TouchableOpacity
              style={[styles.verdictBtn, styles.verdictGreen, qc.verdict === 'green' && styles.verdictActiveGreen]}
              onPress={() => setVerdict(line.id, 'green')}
            >
              <Text style={[styles.verdictLabel, qc.verdict === 'green' && styles.verdictLabelActive]}>✓ Confirmed</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.verdictBtn, styles.verdictRed, qc.verdict === 'red' && styles.verdictActiveRed]}
              onPress={() => setVerdict(line.id, 'red')}
            >
              <Text style={[styles.verdictLabel, qc.verdict === 'red' && styles.verdictLabelActive]}>⚠ Issue</Text>
            </TouchableOpacity>
          </View>

          {/* Issue note */}
          {qc.verdict === 'red' && (
            <View style={styles.fieldGroup}>
              <Text style={styles.fieldLabel}>Describe issue *</Text>
              <TextInput
                style={[styles.input, styles.inputMulti]}
                multiline
                numberOfLines={3}
                placeholder="Short count, wrong species, damage..."
                placeholderTextColor={C.muted}
                value={qc.issueNote}
                onChangeText={n => setNote(line.id, n)}
              />
            </View>
          )}

          {/* Photo */}
          <TouchableOpacity
            style={[styles.photoBtn, qc.photoId && styles.photoBtnDone]}
            onPress={handlePhoto}
          >
            <Text style={[styles.photoBtnText, qc.photoId && styles.photoBtnTextDone]}>
              {qc.photoId ? '📷 Photo Captured ✓' : '📷 Take Delivery Photo *'}
            </Text>
          </TouchableOpacity>

          {error ? <Text style={styles.errorText}>{error}</Text> : null}

          <TouchableOpacity
            style={[styles.submitBtn, qc.verdict === 'pending' && styles.submitBtnDisabled]}
            onPress={handleSubmit}
            disabled={qc.verdict === 'pending'}
          >
            <Text style={styles.submitBtnText}>Submit QC</Text>
          </TouchableOpacity>
        </>
      )}
    </View>
  );
}

export function ArrivingScene() {
  const day = useForeman(s => s.day);
  const selectedWorkOrder = useForeman(s => s.selectedWorkOrder);
  const startJob = useForeman(s => s.startJob);
  const capturePhoto = useForeman(s => s.capturePhoto);
  const anyDeliveryLocked = useForeman(s => s.anyDeliveryLocked);
  const allDeliveriesCleared = useForeman(s => s.allDeliveriesCleared);

  const wo = selectedWorkOrder();
  const deliveries = wo?.deliveries ?? [];
  const qcResults = day.deliveryQc;

  const beforePhoto = day.photos.find(p => p.category === 'before');
  const hasAllDeliveriesCleared = allDeliveriesCleared();
  const hasDeliveryIssue = anyDeliveryLocked();
  const canStart = !!beforePhoto && hasAllDeliveriesCleared && !hasDeliveryIssue;

  async function handleBeforePhoto() {
    const ok = await openCamera();
    if (ok) capturePhoto('before');
  }

  const arrivedTime = day.arrivedAt
    ? new Date(day.arrivedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  return (
    <View style={styles.root}>
      {/* Hero job card */}
      <View style={styles.heroCard}>
        <View style={styles.heroRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.heroLabel}>Arrived On Site</Text>
            <Text style={styles.heroAddress}>{wo?.address ?? '—'}</Text>
            <Text style={styles.heroSubject}>{wo?.subject}</Text>
          </View>
          {arrivedTime && (
            <View style={styles.arrivedBadge}>
              <Text style={styles.arrivedBadgeLabel}>IN</Text>
              <Text style={styles.arrivedBadgeTime}>{arrivedTime}</Text>
            </View>
          )}
        </View>
        {wo && (
          <View style={styles.woBadgeRow}>
            <View style={styles.woBadge}><Text style={styles.woBadgeText}>{wo.woNumber}</Text></View>
            <View style={styles.woBadge}><Text style={styles.woBadgeText}>{wo.workOrderType}</Text></View>
            <View style={styles.woBadge}><Text style={styles.woBadgeText}>{wo.sodSqft.toLocaleString()} sq ft</Text></View>
          </View>
        )}
        {wo?.fieldManager && (
          <TouchableOpacity
            style={styles.callFmBtn}
            onPress={() => Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
          >
            <Text style={styles.callFmText}>📞 {wo.fieldManager.name}</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Before site photo */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Before Site Photo</Text>
        <Text style={styles.cardSub}>Take one photo of the site before any work begins</Text>
        <TouchableOpacity
          style={[styles.photoCapture, beforePhoto && styles.photoCaptureDone]}
          onPress={handleBeforePhoto}
          activeOpacity={0.8}
        >
          {beforePhoto ? (
            <View style={styles.photoCaptureInner}>
              <Text style={styles.photoCheck}>✓</Text>
              <Text style={styles.photoCaptureLabel}>Before photo captured</Text>
              <Text style={styles.photoCaptureTime}>
                {new Date(beforePhoto.capturedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
              </Text>
            </View>
          ) : (
            <View style={styles.photoCaptureInner}>
              <Text style={styles.photoCameraIcon}>📷</Text>
              <Text style={styles.photoCaptureLabel}>Tap to take before photo</Text>
            </View>
          )}
        </TouchableOpacity>
      </View>

      {/* Delivery QC — inline */}
      {deliveries.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Delivery Quality Check</Text>
          <Text style={styles.cardSub}>Verify each delivery before starting work</Text>
          {deliveries.map(line => {
            const qc = qcResults.find(r => r.deliveryLineId === line.id) ?? {
              deliveryLineId: line.id,
              verdict: 'pending' as const,
              verifiedQty: null,
              issueNote: '',
              locked: false,
            };
            return <DeliveryQcCard key={line.id} line={line} qc={qc} />;
          })}
        </View>
      )}

      {/* On Hold notice */}
      {hasDeliveryIssue && (
        <View style={styles.onHoldBanner}>
          <Text style={styles.onHoldBannerTitle}>⚠ Work Order On Hold</Text>
          <Text style={styles.onHoldBannerText}>
            A delivery issue is blocking this job. Your FM must clear it before work can begin.
          </Text>
        </View>
      )}

      {/* Start job CTA */}
      {canStart ? (
        <TouchableOpacity style={styles.startBtn} onPress={startJob} activeOpacity={0.85}>
          <Text style={styles.startBtnText}>Start Job →</Text>
        </TouchableOpacity>
      ) : (
        <View style={styles.startBtnDisabled}>
          <Text style={styles.startBtnDisabledText}>
            {!beforePhoto
              ? 'Take before photo to continue'
              : hasDeliveryIssue
              ? 'Resolve delivery issue to continue'
              : 'Complete delivery QC to continue'}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  heroCard: {
    backgroundColor: C.navy,
    borderRadius: 14,
    padding: 20,
    gap: 12,
  },
  heroRow: { flexDirection: 'row', gap: 12 },
  heroLabel: { fontSize: 10, fontWeight: '700', color: 'rgba(255,255,255,0.5)', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 },
  heroAddress: { fontSize: 18, fontWeight: '800', color: C.white, lineHeight: 24 },
  heroSubject: { fontSize: 13, color: 'rgba(255,255,255,0.65)', marginTop: 2 },
  arrivedBadge: { backgroundColor: C.green, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 8, alignItems: 'center', justifyContent: 'center' },
  arrivedBadgeLabel: { fontSize: 9, fontWeight: '700', color: 'rgba(255,255,255,0.7)', letterSpacing: 1 },
  arrivedBadgeTime: { fontSize: 16, fontWeight: '800', color: C.white },
  woBadgeRow: { flexDirection: 'row', gap: 6, flexWrap: 'wrap' },
  woBadge: { backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: 6, paddingHorizontal: 8, paddingVertical: 4 },
  woBadgeText: { fontSize: 11, fontWeight: '600', color: 'rgba(255,255,255,0.85)' },
  callFmBtn: { backgroundColor: C.blue, borderRadius: 8, paddingVertical: 10, alignItems: 'center' },
  callFmText: { fontSize: 14, fontWeight: '700', color: C.white },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
  },
  cardTitle: { fontSize: 15, fontWeight: '700', color: C.text },
  cardSub: { fontSize: 12, color: C.muted, marginTop: -4 },

  photoCapture: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.border,
    borderRadius: 12,
    paddingVertical: 28,
    alignItems: 'center',
    backgroundColor: C.bg,
  },
  photoCaptureDone: {
    borderStyle: 'solid',
    borderColor: C.green,
    backgroundColor: C.green + '0d',
  },
  photoCaptureInner: { alignItems: 'center', gap: 6 },
  photoCameraIcon: { fontSize: 36 },
  photoCheck: { fontSize: 36, color: C.green },
  photoCaptureLabel: { fontSize: 14, fontWeight: '600', color: C.muted },
  photoCaptureTime: { fontSize: 11, color: C.muted },

  // Delivery card
  deliveryCard: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: C.border,
    padding: 14,
    gap: 10,
    backgroundColor: C.bg,
  },
  deliveryCardRed: { borderColor: C.red + '60', backgroundColor: C.red + '08' },
  deliveryCardGreen: { borderColor: C.green + '60', backgroundColor: C.green + '08' },
  deliveryCardHeader: { flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' },
  productTag: { backgroundColor: C.navy, borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3 },
  productTagText: { fontSize: 11, fontWeight: '700', color: C.white },
  speciesText: { fontSize: 13, fontWeight: '600', color: C.text, flex: 1 },
  confirmedBadge: { backgroundColor: C.green + '20', borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3 },
  confirmedBadgeText: { fontSize: 11, fontWeight: '700', color: C.green },
  issueBadge: { backgroundColor: C.red + '20', borderRadius: 6, paddingHorizontal: 8, paddingVertical: 3 },
  issueBadgeText: { fontSize: 11, fontWeight: '700', color: C.red },
  deliveryMeta: { gap: 3 },
  metaItem: { fontSize: 12, color: C.muted },
  metaVal: { fontWeight: '600', color: C.text },
  onHoldBox: { backgroundColor: C.red + '10', borderRadius: 8, padding: 10, gap: 3 },
  onHoldTitle: { fontSize: 13, fontWeight: '700', color: C.red },
  onHoldText: { fontSize: 12, color: C.text },
  submittedNote: { fontSize: 12, color: C.green, fontWeight: '600' },
  fieldGroup: { gap: 5 },
  fieldLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  input: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 8,
    padding: 10,
    fontSize: 15,
    color: C.text,
    backgroundColor: C.white,
  },
  inputMulti: { minHeight: 70, textAlignVertical: 'top' },
  verdictRow: { flexDirection: 'row', gap: 8 },
  verdictBtn: { flex: 1, borderRadius: 8, paddingVertical: 10, alignItems: 'center', borderWidth: 2 },
  verdictGreen: { borderColor: C.green, backgroundColor: C.green + '10' },
  verdictRed: { borderColor: C.red, backgroundColor: C.red + '10' },
  verdictActiveGreen: { backgroundColor: C.green },
  verdictActiveRed: { backgroundColor: C.red },
  verdictLabel: { fontSize: 13, fontWeight: '700', color: C.text },
  verdictLabelActive: { color: C.white },
  photoBtn: {
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.border,
    backgroundColor: C.white,
  },
  photoBtnDone: { borderColor: C.green, backgroundColor: C.green + '10' },
  photoBtnText: { fontSize: 13, fontWeight: '600', color: C.muted },
  photoBtnTextDone: { color: C.green },
  errorText: { fontSize: 12, color: C.red, fontWeight: '600' },
  submitBtn: { backgroundColor: C.blue, borderRadius: 8, paddingVertical: 10, alignItems: 'center' },
  submitBtnDisabled: { backgroundColor: C.border },
  submitBtnText: { fontSize: 14, fontWeight: '700', color: C.white },

  onHoldBanner: {
    backgroundColor: C.red + '10',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.red + '40',
    gap: 6,
  },
  onHoldBannerTitle: { fontSize: 15, fontWeight: '700', color: C.red },
  onHoldBannerText: { fontSize: 13, color: C.text, lineHeight: 18 },

  startBtn: { backgroundColor: C.green, borderRadius: 12, padding: 16, alignItems: 'center' },
  startBtnText: { fontSize: 16, fontWeight: '800', color: C.white },
  startBtnDisabled: { backgroundColor: C.border, borderRadius: 12, padding: 16, alignItems: 'center' },
  startBtnDisabledText: { fontSize: 14, fontWeight: '600', color: C.muted },
});
