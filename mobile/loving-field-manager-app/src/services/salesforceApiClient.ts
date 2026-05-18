import type { FieldManagerWorkspace, PhotoProof } from "../types";

export interface FieldManagerApi {
  loadWorkspace(): Promise<FieldManagerWorkspace>;
  saveWorkspace(workspace: FieldManagerWorkspace): Promise<void>;
  uploadPhoto(jobId: string, photo: PhotoProof): Promise<PhotoProof>;
}

export class LocalFieldManagerApi implements FieldManagerApi {
  constructor(private loadLocal: () => FieldManagerWorkspace, private saveLocal: (workspace: FieldManagerWorkspace) => void) {}
  async loadWorkspace() { return this.loadLocal(); }
  async saveWorkspace(workspace: FieldManagerWorkspace) { this.saveLocal(workspace); }
  async uploadPhoto(_jobId: string, photo: PhotoProof) { return photo; }
}

export class SalesforceFieldManagerApi implements FieldManagerApi {
  constructor(private baseUrl: string, private accessToken: string) {}

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.accessToken}`,
        ...(init.headers ?? {})
      }
    });
    if (!response.ok) throw new Error(`Salesforce API request failed: ${response.status} ${response.statusText}`);
    return response.json() as Promise<T>;
  }

  async loadWorkspace(): Promise<FieldManagerWorkspace> {
    return this.request<FieldManagerWorkspace>("/services/apexrest/loving/field-manager/workspace");
  }

  async saveWorkspace(workspace: FieldManagerWorkspace): Promise<void> {
    await this.request("/services/apexrest/loving/field-manager/workspace", { method: "PUT", body: JSON.stringify(workspace) });
  }

  async uploadPhoto(jobId: string, photo: PhotoProof): Promise<PhotoProof> {
    return this.request<PhotoProof>(`/services/apexrest/loving/field-manager/jobs/${jobId}/photos`, { method: "POST", body: JSON.stringify(photo) });
  }
}
