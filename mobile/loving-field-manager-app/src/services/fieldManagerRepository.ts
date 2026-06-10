import seedWorkspace from "../data/seed-workspace.json";
import type { FieldManagerWorkspace } from "../types";
import type { SalesforceFieldManagerApi } from "./salesforceApiClient";

const STORAGE_KEY = "loving-field-manager-workspace:v1";

function cloneSeed(): FieldManagerWorkspace {
  return JSON.parse(JSON.stringify(seedWorkspace)) as FieldManagerWorkspace;
}

// ─── Demo mode (localStorage) ─────────────────────────────────────────────────

export function loadWorkspace(): FieldManagerWorkspace {
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return cloneSeed();
  try {
    return JSON.parse(raw) as FieldManagerWorkspace;
  } catch {
    return cloneSeed();
  }
}

export function saveWorkspace(workspace: FieldManagerWorkspace): void {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(workspace));
}

export function resetWorkspace(): FieldManagerWorkspace {
  const fresh = cloneSeed();
  saveWorkspace(fresh);
  return fresh;
}

export function exportWorkspace(workspace: FieldManagerWorkspace): string {
  return JSON.stringify(workspace, null, 2);
}

// ─── Live mode (Salesforce) ───────────────────────────────────────────────────

export async function loadLiveWorkspace(api: SalesforceFieldManagerApi): Promise<FieldManagerWorkspace> {
  return api.loadWorkspace();
}

// After each domain action: update local state instantly, write to Salesforce in
// background. If Salesforce write fails, the error is returned to the caller so
// the UI can surface it — but local state is not rolled back (field-first pattern).
export type SalesforceWrite = (api: SalesforceFieldManagerApi) => Promise<unknown>;

export async function commitLiveAction(
  api: SalesforceFieldManagerApi,
  write: SalesforceWrite
): Promise<{ ok: boolean; sfId?: string; error?: string }> {
  try {
    const result = await write(api) as Record<string, string> | undefined;
    return { ok: true, sfId: result?.id ?? result?.fjId ?? result?.qiId ?? result?.issueId };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}
