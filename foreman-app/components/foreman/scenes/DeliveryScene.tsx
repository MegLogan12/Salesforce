import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInput,
  Platform,
  Alert,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
import type { SfDeliveryLine, SfDeliveryQcResult, DeliveryQcVerdict } from '@/lib/foreman-types';

function DeliveryCard({
  line,
  qc,
  onVerdict,
  onQtyChange,
  onNoteChange,
  onPhoto,
  onSubmit,
}: {
  line: SfDeliveryLine;
  qc: SfDeliveryQcResult;
  onVerdict: (v: DeliveryQcVerdict) => void;
  onQtyChange: (qty: number | null) => void;
  onNoteChange: (note: string) => void;
  onPhoto: () => void;
  onSubmit: () => void;
}) {
  const submitResult = useForeman(s => s.submitDeliveryQc);
  const [submitError, setSubmitError] = useState<string | null>(null);

  function handleSubmit() {
    const result = submitResult(line.id);
    if (!result.ok) {
      const msgs: Record<string, string> = {
        'no-verdict': 'Select Confirmed or Issue verdict first.',
        'no-photo': 'A photo is required before submitting.',
        'no-note': 'Describe the issue before submitting.',
        'no-count': 'Enter the actual quantity counted.',
      };
      setSubmitError(msgs[result.reason ?? ''] ?? 'Unable to submit. Please review.');
      return;
    }
    setSubmitError(null);
    if (result.locked) {
      Alert.alert('Delivery On Hold', 'This delivery has an issue. Your FM has been notified.');
    }
  }

  const isLocked = qc.locked;
  const isSubmitted = !!qc.submittedAt;

  return (
    <View style={[styles.deliveryCard, isLocked && styles.deliveryCardLocked]}>
      {/* Line header */}
      <View style={styles.lineHeader}>
        <View style={styles.lineHeaderLeft}>
          <Text style={styles.productBadge}>{line.product}</Text>
          {line.species && <Text style={styles.speciesText}>{line.species}</Text>}
        </View>
        {isSubmitted && (
          <View style={[styles.statusBadge, qc.verdict === 'green' ? styles.statusGreen : styles.statusRed]}>
            <Text style={styles.statusBadgeText}>{qc.verdict === 'green' ? '✓ Confirmed' : '⚠ Issue'}</Text>
          </View>
        )}
      </View>

      <View style={styles.lineDetails}>
        <Text style={styles.detailRow}>📦 Expected: <Text style={styles.detailVal}>{line.expectedQty} {line.unit}</Text></Text>
        <Text style={styles.detailRow}>🏢 Vendor: <Text style={styles.detailVal}>{line.vendor}</Text></Text>
        <Text style={styles.detailRow}>📄 PO: <Text style={styles.detailVal}>{line.poNumber}</Text></Text>
        <Text style={styles.detailRow}>🕐 Scheduled: <Text style={styles.detailVal}>
          {new Date(line.scheduledIso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
        </Text></Text>
      </View>

      {isLocked ? (
        <View style={styles.lockedBanner}>
          <Text style={styles.lockedTitle}>🔒 Delivery On Hold</Text>
          <Text style={styles.lockedText}>This delivery has a reported issue. Your FM has been notified and must clear this before work can proceed.</Text>
        </View>
      ) : !isSubmitted ? (
        <>
          {/* Count input */}
          <View style={styles.countRow}>
            <Text style={styles.countLabel}>Actual Qty Received</Text>
            <TextInput
              style={styles.countInput}
              keyboardType="numeric"
              placeholder={`Expected: ${line.expectedQty}`}
              placeholderTextColor={C.muted}
              value={qc.verifiedQty !== null ? String(qc.verifiedQty) : ''}
              onChangeText={t => onQtyChange(t === '' ? null : Number(t))}
            />
          </View>

          {/* Verdict buttons */}
          <View style={styles.verdictRow}>
            <TouchableOpacity
              style={[styles.verdictBtn, styles.verdictGreen, qc.verdict === 'green' && styles.verdictActive]}
              onPress={() => onVerdict('green')}
            >
              <Text style={[styles.verdictText, qc.verdict === 'green' && styles.verdictTextActive]}>✓ Confirmed</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.verdictBtn, styles.verdictRed, qc.verdict === 'red' && styles.verdictActiveRed]}
              onPress={() => onVerdict('red')}
            >
              <Text style={[styles.verdictText, qc.verdict === 'red' && styles.verdictTextActive]}>⚠ Issue</Text>
            </TouchableOpacity>
          </View>

          {/* Issue form */}
          {qc.verdict === 'red' && (
            <View style={styles.issueForm}>
              <Text style={styles.issueFormLabel}>Describe the Issue *</Text>
              <TextInput
                style={styles.issueInput}
                multiline
                numberOfLines={3}
                placeholder="Short count, damage, wrong species..."
                placeholderTextColor={C.muted}
                value={qc.issueNote}
                onChangeText={onNoteChange}
              />
              <TouchableOpacity style={styles.photoBtn} onPress={onPhoto}>
                <Text style={styles.photoBtnText}>
                  {qc.photoId ? '📷 Photo Attached ✓' : '📷 Take Issue Photo'}
                </Text>
              </TouchableOpacity>
            </View>
          )}

          {/* Require photo for green too */}
          {qc.verdict === 'green' && (
            <TouchableOpacity style={styles.photoBtn} onPress={onPhoto}>
              <Text style={styles.photoBtnText}>
                {qc.photoId ? '📷 Photo Attached ✓' : '📷 Take Confirmation Photo'}
              </Text>
            </TouchableOpacity>
          )}

          {submitError && <Text style={styles.errorText}>{submitError}</Text>}

          <TouchableOpacity
            style={[styles.submitBtn, qc.verdict === 'pending' && styles.submitBtnDisabled]}
            onPress={handleSubmit}
            disabled={qc.verdict === 'pending'}
          >
            <Text style={styles.submitBtnText}>Submit Delivery QC</Text>
          </TouchableOpacity>
        </>
      ) : (
        <View style={styles.submittedBanner}>
          <Text style={styles.submittedText}>
            Submitted at {new Date(qc.submittedAt!).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
          </Text>
          {qc.verifiedQty !== null && (
            <Text style={styles.submittedQty}>Verified qty: {qc.verifiedQty} {line.unit}</Text>
          )}
        </View>
      )}
    </View>
  );
}

export function DeliveryScene() {
  const day = useForeman(s => s.day);
  const selectedWorkOrder = useForeman(s => s.selectedWorkOrder);
  const setDeliveryVerdict = useForeman(s => s.setDeliveryVerdict);
  const setDeliveryVerifiedQty = useForeman(s => s.setDeliveryVerifiedQty);
  const setDeliveryNote = useForeman(s => s.setDeliveryNote);
  const captureDeliveryPhoto = useForeman(s => s.captureDeliveryPhoto);
  const goScene = useForeman(s => s.goScene);

  const wo = selectedWorkOrder();
  const deliveries = wo?.deliveries ?? [];
  const qcResults = day.deliveryQc;

  const allNonLockedSubmitted = deliveries.every(d => {
    const qc = qcResults.find(r => r.deliveryLineId === d.id);
    return qc && (qc.submittedAt || qc.locked);
  });

  const anyLocked = qcResults.some(r => r.locked);

  async function handlePhoto(lineId: string) {
    if (Platform.OS === 'web') {
      captureDeliveryPhoto(lineId);
      return;
    }
    const { status } = await ImagePicker.requestCameraPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission Required', 'Camera access is needed to document deliveries.');
      return;
    }
    const result = await ImagePicker.launchCameraAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.8,
    });
    if (!result.canceled) {
      captureDeliveryPhoto(lineId);
    }
  }

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Delivery QC</Text>
        <Text style={styles.subtitle}>Verify all deliveries before starting work</Text>
        {wo && <Text style={styles.woRef}>{wo.woNumber} · {wo.address}</Text>}
      </View>

      {deliveries.length === 0 ? (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyText}>No deliveries expected for this work order.</Text>
          <TouchableOpacity style={styles.primaryBtn} onPress={() => goScene('active')}>
            <Text style={styles.primaryBtnText}>Start Work →</Text>
          </TouchableOpacity>
        </View>
      ) : (
        deliveries.map(line => {
          const qc = qcResults.find(r => r.deliveryLineId === line.id) ?? {
            deliveryLineId: line.id,
            verdict: 'pending' as const,
            verifiedQty: null,
            issueNote: '',
            locked: false,
          };
          return (
            <DeliveryCard
              key={line.id}
              line={line}
              qc={qc}
              onVerdict={v => setDeliveryVerdict(line.id, v)}
              onQtyChange={qty => setDeliveryVerifiedQty(line.id, qty)}
              onNoteChange={note => setDeliveryNote(line.id, note)}
              onPhoto={() => handlePhoto(line.id)}
              onSubmit={() => {}}
            />
          );
        })
      )}

      {/* Continue button */}
      {allNonLockedSubmitted && !anyLocked && (
        <TouchableOpacity style={styles.primaryBtn} onPress={() => goScene('active')} activeOpacity={0.85}>
          <Text style={styles.primaryBtnText}>Delivery Complete → Start Work</Text>
        </TouchableOpacity>
      )}

      {anyLocked && (
        <View style={styles.onHoldBanner}>
          <Text style={styles.onHoldTitle}>⚠ Work Order On Hold</Text>
          <Text style={styles.onHoldText}>A delivery issue is blocking this job. Contact your FM to resolve before proceeding.</Text>
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
  woRef: { fontSize: 12, color: C.blue, fontWeight: '600' },
  deliveryCard: {
    backgroundColor: C.white,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 3,
    gap: 10,
  },
  deliveryCardLocked: {
    borderColor: C.red + '80',
    backgroundColor: C.red + '05',
  },
  lineHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  lineHeaderLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  productBadge: {
    backgroundColor: C.navy,
    color: C.white,
    fontSize: 12,
    fontWeight: '700',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    overflow: 'hidden',
  },
  speciesText: { fontSize: 13, fontWeight: '600', color: C.text },
  statusBadge: {
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  statusGreen: { backgroundColor: C.green + '20' },
  statusRed: { backgroundColor: C.red + '20' },
  statusBadgeText: { fontSize: 12, fontWeight: '700', color: C.text },
  lineDetails: { gap: 4 },
  detailRow: { fontSize: 13, color: C.muted },
  detailVal: { fontWeight: '600', color: C.text },
  lockedBanner: {
    backgroundColor: C.red + '10',
    borderRadius: 8,
    padding: 12,
    borderWidth: 1,
    borderColor: C.red + '40',
    gap: 6,
  },
  lockedTitle: { fontSize: 14, fontWeight: '700', color: C.red },
  lockedText: { fontSize: 13, color: C.text, lineHeight: 18 },
  countRow: { gap: 6 },
  countLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  countInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 8,
    padding: 10,
    fontSize: 16,
    color: C.text,
    backgroundColor: C.bg,
  },
  verdictRow: { flexDirection: 'row', gap: 10 },
  verdictBtn: {
    flex: 1,
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
    borderWidth: 2,
  },
  verdictGreen: { borderColor: C.green, backgroundColor: C.green + '10' },
  verdictRed: { borderColor: C.red, backgroundColor: C.red + '10' },
  verdictActive: { backgroundColor: C.green },
  verdictActiveRed: { backgroundColor: C.red },
  verdictText: { fontSize: 14, fontWeight: '700', color: C.text },
  verdictTextActive: { color: C.white },
  issueForm: { gap: 8 },
  issueFormLabel: { fontSize: 12, fontWeight: '600', color: C.muted },
  issueInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 8,
    padding: 10,
    fontSize: 14,
    color: C.text,
    backgroundColor: C.bg,
    textAlignVertical: 'top',
    minHeight: 80,
  },
  photoBtn: {
    backgroundColor: C.navy + '10',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: C.navy + '30',
  },
  photoBtnText: { fontSize: 13, fontWeight: '700', color: C.navy },
  errorText: { fontSize: 12, color: C.red, fontWeight: '600' },
  submitBtn: {
    backgroundColor: C.blue,
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  submitBtnDisabled: { backgroundColor: C.border },
  submitBtnText: { fontSize: 14, fontWeight: '700', color: C.white },
  submittedBanner: {
    backgroundColor: C.green + '10',
    borderRadius: 8,
    padding: 10,
    gap: 3,
  },
  submittedText: { fontSize: 13, fontWeight: '600', color: C.green },
  submittedQty: { fontSize: 12, color: C.muted },
  emptyCard: {
    backgroundColor: C.white,
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    gap: 16,
  },
  emptyText: { fontSize: 14, color: C.muted },
  primaryBtn: {
    backgroundColor: C.blue,
    borderRadius: 10,
    padding: 14,
    alignItems: 'center',
  },
  primaryBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
  onHoldBanner: {
    backgroundColor: C.red + '10',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: C.red + '40',
    gap: 6,
  },
  onHoldTitle: { fontSize: 15, fontWeight: '700', color: C.red },
  onHoldText: { fontSize: 13, color: C.text, lineHeight: 18 },
});
