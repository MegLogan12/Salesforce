import type { PhotoCategory } from '@/data/contracts';

export interface StagedPhoto {
  localUri: string;
  category: PhotoCategory;
  capturedAt: string;
  latitude?: number;
  longitude?: number;
}

export interface PhotoStagingService {
  capture(category: PhotoCategory): Promise<StagedPhoto>;
}
