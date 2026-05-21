import { describe, expect, it } from "vitest";
import seedWorkspace from "../data/seed-workspace.json";
import type { FieldManagerWorkspace } from "../types";
import { acceptPhotoPackage, approveCloseout, completeChecklistItem, createFinishedJob, dispatchAquaRepair, returnWork, selectJob, submitQiPass, updateTakeoffVerifiedAmount, uploadPhoto, validateTakeoff } from "./domainActions";

function fresh(): FieldManagerWorkspace {
  return JSON.parse(JSON.stringify(seedWorkspace)) as FieldManagerWorkspace;
}

describe("Field Manager domain actions", () => {
  it("selects a job without changing the job records", () => {
    const result = selectJob(fresh(), "lot077");
    expect(result.ok).toBe(true);
    expect(result.workspace.selectedJobId).toBe("lot077");
    expect(result.workspace.jobs.length).toBe(4);
  });

  it("updates verified takeoff amount and validates PO to package match", () => {
    const updated = updateTakeoffVerifiedAmount(fresh(), "lot204", "po-sod", "3800");
    expect(updated.ok).toBe(true);
    const line = updated.workspace.jobs.find(j => j.id === "lot204")!.takeoff.lineItems.find(l => l.id === "po-sod")!;
    expect(line.verifiedQuantity).toBe(3800);
  });

  it("blocks takeoff validation when PO lines are not fully verified", () => {
    const result = validateTakeoff(fresh(), "lot204");
    expect(result.ok).toBe(false);
    expect(result.message).toMatch(/verified/i);
  });

  it("moves a fully validated takeoff to ready to schedule", () => {
    const result = validateTakeoff(fresh(), "lot118");
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot118")!;
    expect(job.workOrder.status).toBe("Ready to Schedule");
    expect(job.takeoff.matchStatus).toBe("Validated");
  });

  it("toggles site readiness and Aqua checklist items", () => {
    const site = completeChecklistItem(fresh(), "lot118", "siteReadiness", "sr-access");
    expect(site.ok).toBe(true);
    const aqua = completeChecklistItem(site.workspace, "lot118", "aquaPickup", "ap-device");
    expect(aqua.ok).toBe(true);
  });

  it("blocks photo acceptance when required categories are missing", () => {
    const result = acceptPhotoPackage(fresh(), "lot204");
    expect(result.ok).toBe(false);
    expect(result.message).toMatch(/not ready/i);
  });

  it("submits QI and unlocks invoice readiness when gates pass", () => {
    const result = submitQiPass(fresh(), "lot118");
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot118")!;
    expect(job.qi.status).toBe("Passed");
    expect(job.qi.invoiceStatus).toBe("Ready");
  });

  it("blocks closeout before QI has passed", () => {
    const result = approveCloseout(fresh(), "lot118");
    expect(result.ok).toBe(false);
    expect(result.message).toMatch(/QI/i);
  });

  it("approves closeout after QI passes", () => {
    const qi = submitQiPass(fresh(), "lot118").workspace;
    const result = approveCloseout(qi, "lot118");
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot118")!;
    expect(job.stageIndex).toBe(7);
    expect(job.kpis.find(k => k.id === "invoice")?.value).toBe("Created");
  });

  it("return work blocks invoice and marks the queue NFI", () => {
    const result = returnWork(fresh(), "lot118", "Foreman", "Missing required photo", "Upload the final clean area photo.");
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot118")!;
    expect(job.queuePill.label).toBe("NFI");
    expect(job.kpis.find(k => k.id === "invoice")?.value).toBe("Blocked");
  });

  it("creates a Finished Job activity trail", () => {
    const result = createFinishedJob(fresh(), "lot118", "Incomplete Scope", "Pine straw touch-up.");
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot118")!;
    expect(job.activity[0].message).toMatch(/Finished Job/);
  });

  it("dispatches Aqua repair and updates job health", () => {
    const result = dispatchAquaRepair(fresh(), "lot077", "Dry Spot", "Same-Day", "Marcos Rivera", "2 heads", "Repair now.");
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot077")!;
    expect(job.kpis.find(k => k.id === "aqua")?.value).toBe("Same-Day");
    expect(job.kpis.find(k => k.id === "health")?.value).toBe("Red");
  });

  it("adds a categorized proof photo", () => {
    const result = uploadPhoto(fresh(), "lot204", { category: "Access", caption: "Gate photo", status: "complete" });
    expect(result.ok).toBe(true);
    const job = result.workspace.jobs.find(j => j.id === "lot204")!;
    expect(job.photos.some(p => p.category === "Access")).toBe(true);
  });
});
