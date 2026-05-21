import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Platform,
  Linking,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
import type { CrewStatus } from '@/lib/foreman-types';

function statusColor(s: CrewStatus): string {
  switch (s) {
    case 'Clocked In': return C.green;
    case 'Confirmed': return C.orange;
    case 'On Break': return C.red;
    case 'Clocked Out': return C.muted;
  }
}

function useElapsed(startIso: string | null) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);
  if (!startIso) return '—';
  const mins = Math.floor((now - new Date(startIso).getTime()) / 60_000);
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

async function openCamera(): Promise<boolean> {
  if (Platform.OS === 'web') return true;
  const { status } = await ImagePicker.requestCameraPermissionsAsync();
  if (status !== 'granted') {
    Alert.alert('Camera Required', 'Enable camera access to capture job photos.');
    return false;
  }
  const result = await ImagePicker.launchCameraAsync({ quality: 0.85 });
  return !result.canceled;
}

export function ActiveScene() {
  const day = useForeman(s => s.day);
  const selectedWorkOrder = useForeman(s => s.selectedWorkOrder);
  const capturePhoto = useForeman(s => s.capturePhoto);
  const goScene = useForeman(s => s.goScene);
  const goLunch = useForeman(s => s.goLunch);

  const wo = selectedWorkOrder();
  const elapsed = useElapsed(day.jobStartedAt);

  const progressPhotos = day.photos.filter(p => p.category === 'progress');
  const beforePhoto = day.photos.find(p => p.category === 'before');

  const startedTime = day.jobStartedAt
    ? new Date(day.jobStartedAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : null;

  async function handleProgressPhoto() {
    const ok = await openCamera();
    if (ok) capturePhoto('progress');
  }

  function handleCloseJob() {
    Alert.alert(
      'Close Job',
      'Ready to close out this work order?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Start Closeout', style: 'default', onPress: () => goScene('closeout') },
      ]
    );
  }

  return (
    <View style={styles.root}>
      {/* Job status card */}
      <View style={styles.statusCard}>
        <View style={styles.statusRow}>
          <View style={styles.statusPulse} />
          <Text style={styles.statusLabel}>IN PROGRESS</Text>
          {startedTime && <Text style={styles.startedTime}>since {startedTime}</Text>}
        </View>
        <View style={styles.elapsedRow}>
          <Text style={styles.elapsedNum}>{elapsed}</Text>
          <Text style={styles.elapsedSub}>on site</Text>
          {wo && (
            <View style={styles.goalChip}>
              <Text style={styles.goalText}>Goal: {wo.goalHours}h</Text>
            </View>
          )}
        </View>
        {wo && (
          <>
            <Text style={styles.woSubject}>{wo.subject}</Text>
            <Text style={styles.woAddress}>📍 {wo.address}</Text>
            <View style={styles.woSpecsRow}>
              <Text style={styles.woSpec}>🌿 {wo.sodSqft.toLocaleString()} sq ft</Text>
              <Text style={styles.woSpec}>🌱 {wo.sodSpecies}</Text>
            </View>
          </>
        )}
      </View>

      {/* Crew */}
      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew on Site</Text>
        {day.crew.map(m => (
          <View key={m.id} style={styles.crewRow}>
            <View style={[styles.crewDot, { backgroundColor: statusColor(m.status) }]} />
            <Text style={styles.crewName}>{m.name}</Text>
            <Text style={[styles.crewStatus, { color: statusColor(m.status) }]}>{m.status}</Text>
          </View>
        ))}
      </View>

      {/* Quick actions */}
      <View style={styles.actionsGrid}>
        <TouchableOpacity style={styles.actionBtn} onPress={handleProgressPhoto}>
          <Text style={styles.actionIcon}>📷</Text>
          <Text style={styles.actionLabel}>Progress Photo</Text>
          {progressPhotos.length > 0 && (
            <Text style={styles.actionCount}>{progressPhotos.length}</Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionBtn} onPress={() => goScene('flag')}>
          <Text style={styles.actionIcon}>🚩</Text>
          <Text style={styles.actionLabel}>Flag Issue</Text>
          {day.flag.submitted && <Text style={[styles.actionCount, { backgroundColor: C.red }]}>!</Text>}
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionBtn} onPress={() => goScene('measuring')}>
          <Text style={styles.actionIcon}>📐</Text>
          <Text style={styles.actionLabel}>Measuring Cup</Text>
          {day.measurements.length > 0 && (
            <Text style={styles.actionCount}>{day.measurements.length}</Text>
          )}
        </TouchableOpacity>

        {wo?.fieldManager && (
          <TouchableOpacity
            style={styles.actionBtn}
            onPress={() => Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
          >
            <Text style={styles.actionIcon}>📞</Text>
            <Text style={styles.actionLabel}>Call FM</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Progress photos strip */}
      {progressPhotos.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.sectionLabel}>Progress Photos ({progressPhotos.length})</Text>
          <View style={styles.photoStrip}>
            {progressPhotos.map((p, i) => (
              <View key={p.id} style={styles.photoThumb}>
                <Text style={styles.photoThumbIcon}>📷</Text>
                <Text style={styles.photoThumbNum}>#{i + 1}</Text>
              </View>
            ))}
          </View>
        </View>
      )}

      {/* Lunch break */}
      <TouchableOpacity style={styles.lunchBtn} onPress={goLunch} activeOpacity={0.85}>
        <Text style={styles.lunchBtnText}>☀ Start Lunch Break</Text>
      </TouchableOpacity>

      {/* Close job */}
      <TouchableOpacity style={styles.closeBtn} onPress={handleCloseJob} activeOpacity={0.85}>
        <Text style={styles.closeBtnText}>Close Job →</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  statusCard: {
    backgroundColor: C.navy,
    borderRadius: 14,
    padding: 20,
    gap: 8,
  },
  statusRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  statusPulse: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#4ade80',
  },
  statusLabel: { fontSize: 11, fontWeight: '800', color: '#4ade80', letterSpacing: 1.5 },
  startedTime: { fontSize: 11, color: 'rgba(255,255,255,0.45)', marginLeft: 'auto' },
  elapsedRow: { flexDirection: 'row', alignItems: 'baseline', gap: 8, marginTop: 4 },
  elapsedNum: { fontSize: 42, fontWeight: '900', color: C.white },
  elapsedSub: { fontSize: 13, color: 'rgba(255,255,255,0.5)', marginBottom: 4 },
  goalChip: {
    marginLeft: 'auto',
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  goalText: { fontSize: 12, fontWeight: '600', color: 'rgba(255,255,255,0.7)' },
  woSubject: { fontSize: 15, fontWeight: '700', color: C.white, marginTop: 4 },
  woAddress: { fontSize: 12, color: 'rgba(255,255,255,0.55)' },
  woSpecsRow: { flexDirection: 'row', gap: 16 },
  woSpec: { fontSize: 12, color: 'rgba(255,255,255,0.65)', fontWeight: '500' },

  card: {
    backgroundColor: C.white,
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },

  crewRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 5 },
  crewDot: { width: 10, height: 10, borderRadius: 5 },
  crewName: { flex: 1, fontSize: 14, fontWeight: '500', color: C.text },
  crewStatus: { fontSize: 12, fontWeight: '600' },

  actionsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  actionBtn: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: C.white,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: C.border,
    paddingVertical: 16,
    paddingHorizontal: 12,
    alignItems: 'center',
    gap: 6,
    position: 'relative',
  },
  actionIcon: { fontSize: 28 },
  actionLabel: { fontSize: 12, fontWeight: '600', color: C.text, textAlign: 'center' },
  actionCount: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: C.blue,
    borderRadius: 10,
    paddingHorizontal: 6,
    paddingVertical: 2,
    fontSize: 10,
    fontWeight: '700',
    color: C.white,
    overflow: 'hidden',
  },

  photoStrip: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  photoThumb: {
    width: 60,
    height: 60,
    borderRadius: 8,
    backgroundColor: C.bg,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  photoThumbIcon: { fontSize: 20 },
  photoThumbNum: { fontSize: 9, color: C.muted, fontWeight: '600' },

  lunchBtn: {
    backgroundColor: C.orange,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  lunchBtnText: { fontSize: 15, fontWeight: '700', color: C.white },

  closeBtn: {
    backgroundColor: C.blue,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
  },
  closeBtnText: { fontSize: 15, fontWeight: '700', color: C.white },
});
