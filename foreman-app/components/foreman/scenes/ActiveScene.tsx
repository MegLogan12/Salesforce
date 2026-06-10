import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Platform,
  Linking,
  Animated,
  ScrollView,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useForeman } from '@/lib/foreman-store';
import { C, Sh, R } from '@/constants/loving';
import type { CrewStatus } from '@/lib/foreman-types';

function crewStatusColor(s: CrewStatus): string {
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
    const id = setInterval(() => setNow(Date.now()), 60_000);
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

  const pulseAnim = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, { toValue: 0.25, duration: 900, useNativeDriver: true }),
        Animated.timing(pulseAnim, { toValue: 1, duration: 900, useNativeDriver: true }),
      ])
    ).start();
  }, []);

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
      <View style={styles.statusCard}>
        <View style={styles.statusTopRow}>
          <View style={styles.statusLeftCol}>
            <View style={styles.statusLabelRow}>
              <Animated.View style={[styles.pulseDot, { opacity: pulseAnim }]} />
              <Text style={styles.statusLabel}>IN PROGRESS</Text>
            </View>
            <Text style={styles.elapsedTimer}>{elapsed}</Text>
            <Text style={styles.elapsedSub}>on site</Text>
          </View>
          {wo && (
            <View style={styles.goalChip}>
              <Text style={styles.goalChipLabel}>GOAL</Text>
              <Text style={styles.goalChipValue}>{wo.goalHours}h</Text>
            </View>
          )}
        </View>
        {wo && (
          <View style={styles.woInfoRow}>
            <Text style={styles.woNumber}>{wo.woNumber}</Text>
            <Text style={styles.woSubject}>{wo.subject}</Text>
          </View>
        )}
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionLabel}>Crew on Site</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.crewScroll}>
          {day.crew.map(m => (
            <View key={m.id} style={styles.crewAvatarCol}>
              <View style={[styles.crewAvatar, { borderColor: crewStatusColor(m.status) }]}>
                <Text style={styles.crewInitial}>{m.name.split(' ').map(p => p.charAt(0)).join('')}</Text>
              </View>
              <View style={[styles.crewStatusDot, { backgroundColor: crewStatusColor(m.status) }]} />
              <Text style={styles.crewName}>{m.name.split(' ')[0]}</Text>
              <Text style={[styles.crewStatusText, { color: crewStatusColor(m.status) }]}>{m.status}</Text>
            </View>
          ))}
        </ScrollView>
      </View>

      <View style={styles.actionsGrid}>
        <TouchableOpacity style={styles.actionCard} onPress={handleProgressPhoto}>
          <Text style={styles.actionIcon}>📷</Text>
          <Text style={styles.actionLabel}>Progress Photo</Text>
          {progressPhotos.length > 0 && (
            <View style={styles.actionBadge}>
              <Text style={styles.actionBadgeText}>{progressPhotos.length}</Text>
            </View>
          )}
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionCard} onPress={() => goScene('flag')}>
          <Text style={styles.actionIcon}>🚩</Text>
          <Text style={styles.actionLabel}>Flag Issue</Text>
          {day.flag.submitted && (
            <View style={[styles.actionBadge, { backgroundColor: C.red }]}>
              <Text style={styles.actionBadgeText}>!</Text>
            </View>
          )}
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionCard} onPress={() => goScene('measuring')}>
          <Text style={styles.actionIcon}>📐</Text>
          <Text style={styles.actionLabel}>Measuring Cup</Text>
          {day.measurements.length > 0 && (
            <View style={styles.actionBadge}>
              <Text style={styles.actionBadgeText}>{day.measurements.length}</Text>
            </View>
          )}
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionCard}
          onPress={() => wo?.fieldManager && Linking.openURL(`tel:${wo.fieldManager.phone.replace(/\s/g, '')}`)}
        >
          <Text style={styles.actionIcon}>📞</Text>
          <Text style={styles.actionLabel}>Call FM</Text>
        </TouchableOpacity>
      </View>

      {progressPhotos.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.sectionLabel}>Progress Photos ({progressPhotos.length})</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.photoStrip}>
            {progressPhotos.map((p, i) => (
              <View key={p.id} style={styles.photoThumb}>
                <Text style={styles.photoThumbIcon}>📷</Text>
                <Text style={styles.photoThumbNum}>#{i + 1}</Text>
              </View>
            ))}
          </ScrollView>
        </View>
      )}

      <View style={styles.bottomRow}>
        <TouchableOpacity style={styles.lunchBtn} onPress={goLunch} activeOpacity={0.85}>
          <Text style={styles.lunchBtnText}>☀ Lunch</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.closeBtn} onPress={handleCloseJob} activeOpacity={0.85}>
          <Text style={styles.closeBtnText}>Close Job →</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 12 },

  statusCard: {
    backgroundColor: C.navy,
    borderRadius: R.md,
    padding: 20,
    gap: 12,
    ...Sh.md,
  },
  statusTopRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
  },
  statusLeftCol: { gap: 2 },
  statusLabelRow: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  pulseDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#4ade80',
  },
  statusLabel: {
    fontSize: 11,
    fontWeight: '800',
    color: '#4ade80',
    letterSpacing: 1.8,
  },
  elapsedTimer: {
    fontSize: 60,
    fontWeight: '900',
    color: C.white,
    lineHeight: 66,
    marginTop: 4,
  },
  elapsedSub: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.45)',
    marginTop: -2,
  },
  goalChip: {
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: R.sm,
    paddingHorizontal: 12,
    paddingVertical: 8,
    alignItems: 'center',
    gap: 2,
  },
  goalChipLabel: {
    fontSize: 9,
    fontWeight: '700',
    color: 'rgba(255,255,255,0.4)',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  goalChipValue: { fontSize: 18, fontWeight: '900', color: C.white },
  woInfoRow: { gap: 2, borderTopWidth: 1, borderTopColor: 'rgba(255,255,255,0.1)', paddingTop: 10 },
  woNumber: { fontSize: 11, fontWeight: '700', color: 'rgba(255,255,255,0.4)', letterSpacing: 0.5 },
  woSubject: { fontSize: 15, fontWeight: '700', color: C.white },

  card: {
    backgroundColor: C.white,
    borderRadius: R.md,
    padding: 16,
    borderWidth: 1,
    borderColor: C.border,
    gap: 10,
    ...Sh.xs,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: '700',
    color: C.muted,
    textTransform: 'uppercase',
    letterSpacing: 1.2,
  },

  crewScroll: { gap: 16, paddingRight: 4 },
  crewAvatarCol: { alignItems: 'center', gap: 4 },
  crewAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: C.navy,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2.5,
  },
  crewInitial: { fontSize: 14, fontWeight: '800', color: C.white },
  crewStatusDot: { width: 8, height: 8, borderRadius: 4 },
  crewName: { fontSize: 11, fontWeight: '600', color: C.text },
  crewStatusText: { fontSize: 10, fontWeight: '600' },

  actionsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  actionCard: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: C.white,
    borderRadius: R.md,
    borderWidth: 1,
    borderColor: C.border,
    paddingVertical: 18,
    paddingHorizontal: 12,
    alignItems: 'center',
    gap: 6,
    position: 'relative',
    ...Sh.xs,
  },
  actionIcon: { fontSize: 30 },
  actionLabel: { fontSize: 12, fontWeight: '700', color: C.text, textAlign: 'center' },
  actionBadge: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: C.blue,
    borderRadius: 10,
    paddingHorizontal: 6,
    paddingVertical: 2,
    minWidth: 20,
    alignItems: 'center',
  },
  actionBadgeText: { fontSize: 10, fontWeight: '800', color: C.white },

  photoStrip: { gap: 8 },
  photoThumb: {
    width: 62,
    height: 62,
    borderRadius: R.sm,
    backgroundColor: C.bg,
    borderWidth: 1,
    borderColor: C.border,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  photoThumbIcon: { fontSize: 20 },
  photoThumbNum: { fontSize: 9, color: C.muted, fontWeight: '600' },

  bottomRow: {
    flexDirection: 'row',
    gap: 10,
  },
  lunchBtn: {
    flex: 1,
    backgroundColor: C.orange,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.xs,
  },
  lunchBtnText: { fontSize: 15, fontWeight: '800', color: C.white },
  closeBtn: {
    flex: 1,
    backgroundColor: C.blue,
    borderRadius: R.md,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    ...Sh.xs,
  },
  closeBtnText: { fontSize: 15, fontWeight: '800', color: C.white },
});
