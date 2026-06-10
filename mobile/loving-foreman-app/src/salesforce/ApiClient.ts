export interface ApiClientConfig {
  instanceUrl: string;
  accessToken: string;
}

export class ApiClient {
  constructor(private readonly config: ApiClientConfig) {}

  async get<T>(path: string): Promise<T> {
    const response = await fetch(`${this.config.instanceUrl}${path}`, {
      headers: {
        Authorization: `Bearer ${this.config.accessToken}`
      }
    });

    if (!response.ok) {
      throw new Error(`GET ${path} failed: ${response.status}`);
    }

    return (await response.json()) as T;
  }
}
