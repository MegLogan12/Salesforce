import React from 'react';
import { ScrollView, TouchableOpacity, Text, View, StyleSheet } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
import type { Scene } from '@/lib/foreman-types';

interface NavPhase {
  scene: Scene;
  label: string;
}

const PHASES: NavPhase[] = [
  { scene: 'myDay',    label: 'My Day' },
  { scene: 'morning',  label: 'Morning' },
  { scene: 'drive',    label: 'Drive' },
  { scene: 'arriving', label: 'Arriving' },
  { scene: 'active',   label: 'Active' },
  { scene: 'measuring',label: '📐 Cup' },
  { scene: 'lunch',    label: 'Lunch' },
  { scene: 'closeout', label: 'Closeout' },
  { scene: 'eod',      label: 'EOD' },
];

const SCENE_ORDER: Scene[] = PHASES.map(p => p.scene);

export function DayNav() {
  const currentScene = useForeman(s => s.scene);
  const goScene = useForeman(s => s.goScene);
  const currentIndex = SCENE_ORDER.indexOf(currentScene);

  return (
    <View style={styles.container}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scroll}
      >
        {PHASES.map((phase, idx) => {
          const isActive = phase.scene === currentScene;
          const isDone = idx < currentIndex;
          const isFuture = idx > currentIndex;

          return (
            <TouchableOpacity
              key={phase.scene}
              style={[
                styles.chip,
                isActive && styles.chipActive,
                isDone && styles.chipDone,
                isFuture && styles.chipFuture,
              ]}
              onPress={() => { if (isDone || isActive) goScene(phase.scene); }}
              activeOpacity={isFuture ? 1 : 0.7}
            >
              {isDone && <Text style={styles.checkmark}>✓ </Text>}
              <Text
                style={[
                  styles.chipText,
                  isActive && styles.chipTextActive,
                  isDone && styles.chipTextDone,
                  isFuture && styles.chipTextFuture,
                ]}
              >
                {phase.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: C.navy,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.1)',
  },
  scroll: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 6,
    flexDirection: 'row',
    alignItems: 'center',
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 14,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
  },
  chipActive: { backgroundColor: C.blue, borderColor: C.blue },
  chipDone: { backgroundColor: 'rgba(4,132,75,0.25)', borderColor: C.green },
  chipFuture: { opacity: 0.4 },
  chipText: { fontSize: 11, fontWeight: '600', color: 'rgba(255,255,255,0.7)', letterSpacing: 0.2 },
  chipTextActive: { color: C.white },
  chipTextDone: { color: '#86efac' },
  chipTextFuture: { color: 'rgba(255,255,255,0.4)' },
  checkmark: { fontSize: 10, color: '#86efac', fontWeight: '700' },
});
