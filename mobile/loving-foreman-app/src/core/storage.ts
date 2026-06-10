import AsyncStorage from '@react-native-async-storage/async-storage';
import type { AppSnapshot } from '@/core/types';

const SNAPSHOT_KEY = 'loving-foreman-alpha-snapshot-v1';

export async function loadSnapshot(): Promise<AppSnapshot | null> {
  const raw = await AsyncStorage.getItem(SNAPSHOT_KEY);
  return raw ? (JSON.parse(raw) as AppSnapshot) : null;
}

export async function saveSnapshot(snapshot: AppSnapshot): Promise<void> {
  await AsyncStorage.setItem(SNAPSHOT_KEY, JSON.stringify(snapshot));
}
