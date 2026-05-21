import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInput,
  Alert,
  Platform,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';

const ISSUE_TYPES = [
  'Wrong species delivered',
  'Short delivery count',
  'Soil grade issue',
  'Irrigation conflict',
  'Underground obstruction',
  'Lot boundary unclear',
  'Other',
];

export function FlagScene() {
  const flag = useForeman(s => s.day.flag);
  const setSpecies = useForeman(s => s.setFlagSpecies);
  const setSqft = useForeman(s => s.setFlagSqft);
  const submitFlag = useForeman(s => s.submitFlag);
  const capturePhoto = useForeman(s => s.capturePhoto);
  const goScene = useForeman(s => s.goScene);

  const [photoTaken, setPhotoTaken] = useState(false);
  const [customNote, setCustomNote] = useState('');

  async function handlePhoto() {
    if (Platform.OS === 'web') { setPhotoTaken(true); capturePhoto('flag'); return; }
    const { status } = await ImagePicker.requestCameraPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Camera Required', 'Enable camera access to document the issue.');
      return;
    }
    const result = await ImagePicker.launchCameraAsync({ quality: 0.85 });
    if (!result.canceled) { setPhotoTaken(true); capturePhoto('flag'); }
  }

  function handleSubmit() {
    if (!flag.speciesDiscovered.trim() && !customNote.trim()) {
      Alert.alert('Required', 'Describe the issue before submitting.');
      return;
    }
    submitFlag();
  }

  if (flag.submitted) {
    return (
      <View style={styles.root}>
        <View style={styles.submittedCard}>
          <Text style={styles.submittedIcon}>🚩</Text>
          <Text style={styles.submittedTitle}>Flag Submitted</Text>
          <Text style={styles.submittedText}>
            {flag.speciesDiscovered || customNote}
            {flag.extraSqft ? `\n+${flag.extraSqft.toLocaleString()} sq ft additional` : ''}
          </Text>
          <Text style={styles.submittedNote}>Your FM has been notified.</Text>
          <TouchableOpacity style={styles.backBtn} onPress={() => goScene('active')}>
            <Text style={styles.backBtnText}>← Back to Job</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <View style={styles.headerCard}>
        <Text style={styles.headerTitle}>🚩 Flag Issue</Text>
        <Text style={styles.headerSub}>Report a site or delivery problem to your FM</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardLabel}>Issue Type</Text>
        <View style={styles.chipsGrid}>
          {ISSUE_TYPES.map(f => (
            <TouchableOpacity
              key={f}
              style={[styles.chip, flag.speciesDiscovered === f && styles.chipActive]}
              onPress={() => setSpecies(f)}
            >
              <Text style={[styles.chipText, flag.speciesDiscovered === f && styles.chipTextActive]}>
                {f}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardLabel}>Details</Text>
        <TextInput
          style={styles.noteInput}
          multiline
          numberOfLines={4}
          placeholder="Describe the issue in detail..."
          placeholderTextColor={C.subtle}
          value={customNote}
          onChangeText={setCustomNote}
          textAlignVertical="top"
        />
      </View>

      <View style={styles.card}>
        <Text style={styles.cardLabel}>Additional Sq Ft (if applicable)</Text>
        <TextInput
          style={styles.sqftInput}
          keyboardType="numeric"
          placeholder="0"
          placeholderTextColor={C.subtle}
          value={flag.extraSqft !== null ? String(flag.extraSqft) : ''}
          onChangeText={t => setSqft(t === '' ? null : Number(t))}
        />
      </View>

      <TouchableOpacity
        style={[styles.photoBtn, photoTaken && styles.photoBtnDone]}
        onPress={handlePhoto}
        activeOpacity={0.8}
      >
        <Text style={[styles.photoBtnText, photoTaken && styles.photoBtnTextDone]}>
          {photoTaken ? '📷 Photo Attached ✓' : '📷 Take Issue Photo'}
        </Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.submitBtn} onPress={handleSubmit} activeOpacity={0.85}>
        <Text style={styles.submitBtnText}>Submit Flag</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.cancelBtn} onPress={() => goScene('active')} activeOpacity={0.8}>
        <Text style={styles.cancelBtnText}>Cancel</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  headerCard: {
    backgroundColor: C.red,
    borderRadius: R.md,
    padding: 20,
    gap: 5,
    ...Sh.sm,
  },
  headerTitle: { fontSize: 22, fontWeight: '900', color: C.white },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.7)' },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    ...Sh.xs,
  },
  cardLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },

  chipsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderWidth: 1.5,
    borderColor: C.border,
    backgroundColor: C.bg,
  },
  chipActive: { borderColor: C.red, backgroundColor: C.red + '0E' },
  chipText: { fontSize: 13, color: C.muted, fontWeight: '500' },
  chipTextActive: { color: C.red, fontWeight: '700' },

  noteInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: R.sm,
    padding: 12,
    fontSize: 14,
    color: C.text,
    backgroundColor: C.bg,
    minHeight: 100,
  },

  sqftInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: R.sm,
    padding: 12,
    fontSize: 20,
    fontWeight: '700',
    color: C.text,
    backgroundColor: C.bg,
  },

  photoBtn: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.border,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: C.white,
  },
  photoBtnDone: { borderStyle: 'solid', borderColor: C.green, backgroundColor: C.green + '08' },
  photoBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
  photoBtnTextDone: { color: C.green, fontWeight: '700' },

  submitBtn: {
    backgroundColor: C.red,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.xs,
  },
  submitBtnText: { fontSize: 16, fontWeight: '900', color: C.white },

  cancelBtn: {
    backgroundColor: C.bg,
    borderRadius: R.md,
    height: 50,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: C.border,
  },
  cancelBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },

  submittedCard: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 28,
    borderWidth: 1,
    borderColor: C.red + '35',
    alignItems: 'center',
    gap: 10,
    ...Sh.sm,
  },
  submittedIcon: { fontSize: 48 },
  submittedTitle: { fontSize: 22, fontWeight: '800', color: C.text },
  submittedText: { fontSize: 14, color: C.text, textAlign: 'center', lineHeight: 20 },
  submittedNote: { fontSize: 12, color: C.muted, fontStyle: 'italic' },
  backBtn: {
    backgroundColor: C.blue,
    borderRadius: R.sm,
    paddingHorizontal: 24,
    paddingVertical: 12,
    marginTop: 8,
  },
  backBtnText: { fontSize: 14, fontWeight: '700', color: C.white },
});
