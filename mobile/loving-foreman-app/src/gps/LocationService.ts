export interface DeviceLocation {
  latitude: number;
  longitude: number;
  capturedAt: string;
}

export interface LocationService {
  getCurrentLocation(): Promise<DeviceLocation>;
}
