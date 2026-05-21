import React from 'react';
import { ScrollView, TouchableOpacity, Text, View, StyleSheet } from 'react-native';
import { useForeman } from '@/lib/foreman-store';
import { C } from '@/constants/loving';
import type { Scene } from '@/lib/foreman-types';

interface NavPhase {
  scene: Scene;
  label: string;
  icon: string;
}

const PHASES: NavPhase[] = [
  { scene: 'myDay',    label: 'My Day',   icon: '📋' },
  { scene: 'morning',  label: 'Morning',  icon: '✅' },
  { scene: 'drive',    label: 'Drive',    icon: '🚛' },
  { scene: 'arriving', label: 'Arriving', icon: '📍' },
  { scene: 'active',   label: 'Active',   icon: '⚡' },
  { scene: 'measuring',label: 'Cup',      icon: '📐' },
  { scene: 'lunch',    label: 'Lunch',    icon: '☀' },
  { scene: 'closeout', label: 'Closeout', icon: '🏁' },
  { scene: 'eod',      label: 'EOD',      icon: '✓' },
];

const ORDER: Scene[] = PHASES.map(p => p.scene);

export function DayNav() {
  const currentScene = useForeman(s => s.scene);
  const goScene = useForeman(s => s.goScene);
  const curIdx = ORDER.indexOf(currentScene);

  return (
    <View style={s.container}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={s.scroll}
      >
        {PHASES.map((phase, idx) => {
          const isActive = phase.scene === currentScene;
          const isDone = idx < curIdx;
          const isFuture = idx > curIdx;

          return (
            <TouchableOpacity
              key={phase.scene}
              style={[
                s.item,
                isActive && s.itemActive,
                isDone && s.itemDone,
                isFuture && s.itemFuture,
              ]}
              onPress={() => { if (isDone || isActive) goScene(phase.scene); }}
              activeOpacity={isFuture ? 1 : 0.7}
            >
              {isDone ? (
                <View style={s.checkCircle}>
                  <Text style={s.checkMark}>✓</Text>
                </View>
              ) : (
                <Text style={[s.itemIcon, isFuture && s.itemIconFuture]}>{phase.icon}</Text>
              )}
              <Text
                style={[
                  s.itemLabel,
                  isActive && s.itemLabelActive,
                  isDone && s.itemLabelDone,
                  isFuture && s.itemLabelFuture,
                ]}
              >
                {phase.label}
              </Text>
              {isActive && <View style={s.activeUnderline} />}
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
}

const s = StyleSheet.create({
  container: {
    backgroundColor: C.navy,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.08)',
  },
  scroll: {
    paddingHorizontal: 8,
    paddingVertical: 0,
    flexDirection: 'row',
    alignItems: 'stretch',
    gap: 2,
  },
  item: {
    paddingHorizontal: 10,
    paddingVertical: 10,
    alignItems: 'center',
    gap: 3,
    minWidth: 58,
    position: 'relative',
    opacity: 1,
  },
  itemActive: {},
  itemDone: {},
  itemFuture: { opacity: 0.38 },
  itemIcon: { fontSize: 15 },
  itemIconFuture: { opacity: 0.6 },
  checkCircle: {
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: C.green,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkMark: { fontSize: 10, fontWeight: '800', color: C.white },
  itemLabel: {
    fontSize: 10,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.5)',
    letterSpacing: 0.2,
  },
  itemLabelActive: { color: C.white, fontWeight: '700' },
  itemLabelDone: { color: '#86efac' },
  itemLabelFuture: { color: 'rgba(255,255,255,0.3)' },
  activeUnderline: {
    position: 'absolute',
    bottom: 0,
    left: 8,
    right: 8,
    height: 2,
    backgroundColor: C.orange,
    borderRadius: 1,
  },
});
