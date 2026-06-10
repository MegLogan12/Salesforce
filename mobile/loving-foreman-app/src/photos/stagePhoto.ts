import * as FileSystem from 'expo-file-system';
import * as ImagePicker from 'expo-image-picker';
import type { PhotoCategory } from '@/data/contracts';

export interface StagedPhotoResult {
  localUri: string;
  category: PhotoCategory;
  capturedAt: string;
}

export async function stagePhoto(category: PhotoCategory): Promise<StagedPhotoResult> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) {
    throw new Error('Photo library permission not granted.');
  }

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ImagePicker.MediaTypeOptions.Images,
    quality: 0.7,
    allowsEditing: false
  });

  if (result.canceled || result.assets.length === 0) {
    throw new Error('Photo selection canceled.');
  }

  const asset = result.assets[0];
  const fileName = asset.fileName ?? `staged-${Date.now()}.jpg`;
  const targetUri = `${FileSystem.documentDirectory}photos/${Date.now()}-${fileName}`;
  await FileSystem.makeDirectoryAsync(`${FileSystem.documentDirectory}photos`, { intermediates: true });
  await FileSystem.copyAsync({ from: asset.uri, to: targetUri });

  return {
    localUri: targetUri,
    category,
    capturedAt: new Date().toISOString()
  };
}
