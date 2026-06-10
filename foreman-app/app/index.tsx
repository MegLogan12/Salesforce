import React, { useMemo } from 'react';
import { View, ScrollView, StyleSheet } from 'react-native';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';
import { useForeman } from '@/lib/foreman-store';
import { AppHeader } from '@/components/foreman/AppHeader';
import { DayNav } from '@/components/foreman/DayNav';
import { PinScene } from '@/components/foreman/scenes/PinScene';
import { LoginScene } from '@/components/foreman/scenes/LoginScene';
import { MyDayScene } from '@/components/foreman/scenes/MyDayScene';
import { MorningScene } from '@/components/foreman/scenes/MorningScene';
import { DriveScene } from '@/components/foreman/scenes/DriveScene';
import { ArrivingScene } from '@/components/foreman/scenes/ArrivingScene';
import { ActiveScene } from '@/components/foreman/scenes/ActiveScene';
import { MeasuringScene } from '@/components/foreman/scenes/MeasuringScene';
import { LunchScene } from '@/components/foreman/scenes/LunchScene';
import { FlagScene } from '@/components/foreman/scenes/FlagScene';
import { CloseoutScene } from '@/components/foreman/scenes/CloseoutScene';
import { EodScene } from '@/components/foreman/scenes/EodScene';
import { lovingColors } from '@/constants/loving';

function App() {
  const insets = useSafeAreaInsets();
  const scene = useForeman((s) => s.scene);

  const sceneEl = useMemo(() => {
    switch (scene) {
      case 'pin':      return <PinScene />;
      case 'login':    return <LoginScene />;
      case 'myDay':    return <MyDayScene />;
      case 'morning':  return <MorningScene />;
      case 'drive':    return <DriveScene />;
      case 'arriving': return <ArrivingScene />;
      case 'active':   return <ActiveScene />;
      case 'measuring':return <MeasuringScene />;
      case 'lunch':    return <LunchScene />;
      case 'flag':     return <FlagScene />;
      case 'closeout': return <CloseoutScene />;
      case 'eod':      return <EodScene />;
      default:         return null;
    }
  }, [scene]);

  if (scene === 'pin' || scene === 'login') {
    return (
      <View style={styles.root}>
        <View style={{ paddingTop: insets.top, flex: 1 }}>
          {scene === 'pin' ? <PinScene /> : <LoginScene />}
        </View>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <AppHeader insetTop={insets.top} />
      <DayNav />
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 32 }]}
        showsVerticalScrollIndicator={false}
      >
        {sceneEl}
      </ScrollView>
    </View>
  );
}

export default function Home() {
  return (
    <SafeAreaProvider>
      <App />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: lovingColors.bg },
  scroll: { flex: 1, backgroundColor: lovingColors.bg },
  content: { padding: 12, gap: 12 },
});
