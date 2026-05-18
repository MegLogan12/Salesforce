import seedWorkspace from "../data/seed-workspace.json";
import type { FieldManagerWorkspace } from "../types";

const STORAGE_KEY = "loving-field-manager-workspace:v1";

function cloneSeed(): FieldManagerWorkspace {
  return JSON.parse(JSON.stringify(seedWorkspace)) as FieldManagerWorkspace;
}

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
