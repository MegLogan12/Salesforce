import type { GpsStatus } from '@/data/contracts';

export interface WexGpsService {
  getVehicleStatus(vehicleId: string): Promise<GpsStatus>;
}
