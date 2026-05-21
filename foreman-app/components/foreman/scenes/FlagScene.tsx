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
import { C } from '@/constants/loving';

const COMMON_FLAGS = [
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
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>🚩 Flag Issue</Text>
        <Text style={styles.headerSub}>Report a site or delivery problem to your FM</Text>
      </View>

      {/* Quick select */}
      <View style={styles.card}>
        <Text style={styles.cardLabel}>Issue Type</Text>
        <View style={styles.flagGrid}>
          {COMMON_FLAGS.map(f => (
            <TouchableOpacity
              key={f}
              style={[styles.flagChip, flag.speciesDiscovered === f && styles.flagChipActive]}
              onPress={() => setSpecies(f)}
            >
              <Text style={[styles.flagChipText, flag.speciesDiscovered === f && styles.flagChipTextActive]}>
                {f}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Custom note */}
      <View style={styles.card}>
        <Text style={styles.cardLabel}>Details</Text>
        <TextInput
          style={styles.noteInput}
          multiline
          numberOfLines={4}
          placeholder="Describe the issue in detail..."
          placeholderTextColor={C.muted}
          value={customNote}
          onChangeText={setCustomNote}
        />
      </View>

      {/* Extra sqft */}
      <View style={styles.card}>
        <Text style={styles.cardLabel}>Additional Sq Ft (if applicable)</Text>
        <TextInput
          style={styles.sqftInput}
          keyboardType="numeric"
          placeholder="0"
          placeholderTextColor={C.muted}
          value={flag.extraSqft !== null ? String(flag.extraSqft) : ''}
          onChangeText={t => setSqft(t === '' ? null : Number(t))}
        />
      </View>

      {/* Photo */}
      <TouchableOpacity
        style={[styles.photoBtn, photoTaken && styles.photoBtnDone]}
        onPress={handlePhoto}
        activeOpacity={0.8}
      >
        <Text style={[styles.photoBtnText, photoTaken && styles.photoBtnTextDone]}>
          {photoTaken ? '📷 Photo Attached ✓' : '📷 Take Issue Photo'}
        </Text>
      </TouchableOpacity>

      {/* Actions */}
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

  header: {
    backgroundColor: C.red,
    borderRadius: 14,
    padding: 20,
    gap: 4,
  },
  headerTitle: { fontSize: 22, fontWeight: '800', color: C.white },
  headerSub: { fontSize: 13, color: 'rgba(255,255,255,0.75)' },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
  },
  cardLabel: { fontSize: 11, fontWeight: '700', color: C.muted, textTransform: 'uppercase', letterSpacing: 0.8 },

  flagGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  flagChip: {
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderWidth: 1.5,
    borderColor: C.border,
    backgroundColor: C.bg,
  },
  flagChipActive: { borderColor: C.red, backgroundColor: C.red + '10' },
  flagChipText: { fontSize: 13, color: C.muted, fontWeight: '500' },
  flagChipTextActive: { color: C.red, fontWeight: '700' },

  noteInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 10,
    padding: 12,
    fontSize: 14,
    color: C.text,
    backgroundColor: C.bg,
    textAlignVertical: 'top',
    minHeight: 100,
  },

  sqftInput: {
    borderWidth: 1,
    borderColor: C.border,
    borderRadius: 10,
    padding: 12,
    fontSize: 18,
    fontWeight: '700',
    color: C.text,
    backgroundColor: C.bg,
  },

  photoBtn: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderColor: C.border,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    backgroundColor: C.white,
  },
  photoBtnDone: { borderStyle: 'solid', borderColor: C.green, backgroundColor: C.green + '08' },
  photoBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },
  photoBtnTextDone: { color: C.green },

  submitBtn: { backgroundColor: C.red, borderRadius: 12, padding: 16, alignItems: 'center' },
  submitBtnText: { fontSize: 16, fontWeight: '800', color: C.white },

  cancelBtn: { backgroundColor: C.bg, borderRadius: 12, padding: 14, alignItems: 'center', borderWidth: 1, borderColor: C.border },
  cancelBtnText: { fontSize: 14, fontWeight: '600', color: C.muted },

  submittedCard: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 28,
    borderWidth: 1,
    borderColor: C.red + '40',
    alignItems: 'center',
    gap: 10,
  },
  submittedIcon: { fontSize: 48 },
  submittedTitle: { fontSize: 22, fontWeight: '800', color: C.text },
  submittedText: { fontSize: 14, color: C.text, textAlign: 'center', lineHeight: 20 },
  submittedNote: { fontSize: 12, color: C.muted, fontStyle: 'italic' },
  backBtn: { backgroundColor: C.blue, borderRadius: 10, paddingHorizontal: 24, paddingVertical: 12, marginTop: 8 },
  backBtnText: { fontSize: 14, fontWeight: '700', color: C.white },
});
