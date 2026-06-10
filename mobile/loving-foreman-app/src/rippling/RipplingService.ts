import type { RipplingStatus } from '@/data/contracts';

export interface RipplingService {
  getStatus(serviceResourceId: string): Promise<RipplingStatus>;
}
