import type { ActivityEvent, ActionResult, FieldManagerWorkspace, JobRecord, PhotoProof, PillTone } from "../types";

function now() { return new Date().toISOString(); }
function clone(workspace: FieldManagerWorkspace): FieldManagerWorkspace { return JSON.parse(JSON.stringify(workspace)); }
function event(message: string, by: string, type: ActivityEvent["type"] = "action"): ActivityEvent {
  return { id: crypto.randomUUID(), at: now(), by, message, type };
}
function findJob(workspace: FieldManagerWorkspace, jobId: string): JobRecord {
  const job = workspace.jobs.find(j => j.id === jobId);
  if (!job) throw new Error(`Job ${jobId} not found`);
  return job;
}
function setKpi(job: JobRecord, id: string, value: string, sub?: string) {
  const kpi = job.kpis.find(k => k.id === id);
  if (kpi) {
    kpi.value = value;
    if (sub) kpi.sub = sub;
  }
}
function checklistDone(items: { done: boolean }[] | undefined): boolean {
  return Boolean(items?.length) && (items ?? []).every(item => item.done);
}
function setGate(job: JobRecord, title: string, done: boolean, note: string, pill?: string, tone?: PillTone) {
  const gate = job.gateStatus.find(g => g.title === title);
  if (gate) {
    gate.done = done;
    gate.note = note;
    gate.pill = pill ?? (done ? "Done" : "Open");
    gate.tone = tone ?? (done ? "green" : "amber");
  }
}
function recalcTakeoff(job: JobRecord) {
  const lines = job.takeoff.lineItems ?? [];
  for (const line of lines) {
    if (line.verifiedQuantity === null || Number.isNaN(line.verifiedQuantity)) {
      line.status = "Not Verified";
      continue;
    }
    const poDelta = Math.abs(line.poQuantity - line.verifiedQuantity);
    const packageDelta = Math.abs(line.communityPackageQuantity - line.verifiedQuantity);
    line.status = poDelta <= line.tolerance && packageDelta <= line.tolerance ? "Match" : "Variance";
  }
  const allVerified = lines.length > 0 && lines.every(line => line.verifiedQuantity !== null && !Number.isNaN(line.verifiedQuantity));
  const allMatched = allVerified && lines.every(line => line.status === "Match");
  job.takeoff.matchStatus = allMatched ? "Validated" : allVerified ? "Variance" : "Not Checked";
  job.takeoff.packageComparison = lines.map(line => ({
    item: line.poLineItem,
    package: `${line.communityPackageQuantity.toLocaleString()} ${line.uom}`,
    takeoff: line.verifiedQuantity === null ? "Not entered" : `${line.verifiedQuantity.toLocaleString()} ${line.uom}`,
    result: line.status,
    tone: line.status === "Match" ? "green" : line.status === "Variance" ? "red" : "amber"
  }));
  const measurementField = job.takeoff.fields.find(field => field.label === "Measurements");
  if (measurementField) {
    measurementField.value = lines.map(line => `${line.poLineItem} ${line.verifiedQuantity ?? "?"} ${line.uom}`).join(", ");
  }
  const packageField = job.takeoff.fields.find(field => field.label === "Package Match");
  if (packageField) packageField.value = allMatched ? "PO, Takeoff, and Community Package match" : allVerified ? "Variance review required" : "Waiting for verified field measurements";
  return { allVerified, allMatched };
}

export function selectJob(workspace: FieldManagerWorkspace, jobId: string): ActionResult {
  const next = clone(workspace);
  findJob(next, jobId);
  next.selectedJobId = jobId;
  return { ok: true, message: `${findJob(next, jobId).queueTitle} selected.`, workspace: next };
}

export function advanceStage(workspace: FieldManagerWorkspace, jobId: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  job.stageIndex = Math.min(job.stageIndex + 1, job.stageLabels.length - 1);
  if (job.stageIndex >= 5) setKpi(job, "qi", job.stageIndex === 5 ? "In Review" : (job.qi.overallScore?.toString() ?? "8.6"));
  if (job.stageIndex >= 7) setKpi(job, "invoice", "Created", "Invoice created to the Division Account");
  job.activity.unshift(event(`Demo advanced to ${job.stageLabels[job.stageIndex]}.`, next.currentUser.name, "record-update"));
  return { ok: true, message: `Demo advanced to: ${job.stageLabels[job.stageIndex]}.`, workspace: next };
}

export function updateTakeoffVerifiedAmount(workspace: FieldManagerWorkspace, jobId: string, lineId: string, value: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  const line = job.takeoff.lineItems.find(item => item.id === lineId);
  if (!line) return { ok: false, message: "Takeoff line item was not found.", workspace };
  line.verifiedQuantity = value.trim() === "" ? null : Number(value);
  recalcTakeoff(job);
  setKpi(job, "takeoff", job.takeoff.matchStatus, job.takeoff.matchStatus === "Validated" ? "PO, takeoff, and package match" : "Verified quantities still need review");
  return { ok: true, message: `${line.poLineItem} verified amount updated.`, workspace: next };
}

export function completeChecklistItem(workspace: FieldManagerWorkspace, jobId: string, area: "takeoff" | "siteReadiness" | "aquaCheck" | "aquaPickup", itemId: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  const source = area === "takeoff" ? job.takeoff.tasks : area === "siteReadiness" ? job.takeoff.siteReadiness : area === "aquaCheck" ? job.aqua.checkChecklist : job.aqua.pickupChecklist;
  const item = source?.find(row => row.id === itemId || row.title === itemId);
  if (!item) return { ok: false, message: "Checklist item was not found.", workspace };
  item.done = !item.done;
  item.pill = item.done ? "Done" : "Open";
  item.tone = item.done ? "green" : "amber";
  if (area === "siteReadiness") setKpi(job, "siteReadiness", checklistDone(job.takeoff.siteReadiness) ? "Ready" : "Open", checklistDone(job.takeoff.siteReadiness) ? "48-hour checklist complete" : "48-hour checklist incomplete");
  if (area === "aquaCheck") setKpi(job, "aqua", checklistDone(job.aqua.checkChecklist) ? "Check OK" : "Check Open", checklistDone(job.aqua.checkChecklist) ? "Aqua check checklist complete" : "Aqua check checklist open");
  if (area === "aquaPickup") setKpi(job, "aqua", checklistDone(job.aqua.pickupChecklist) ? "Pickup Ready" : "Pickup Open", checklistDone(job.aqua.pickupChecklist) ? "Pickup checklist complete" : "Pickup checklist open");
  job.activity.unshift(event(`${area} checklist updated: ${item.title} is now ${item.done ? "done" : "open"}.`, next.currentUser.name, "record-update"));
  return { ok: true, message: `${item.title} marked ${item.done ? "done" : "open"}.`, workspace: next };
}

export function validateTakeoff(workspace: FieldManagerWorkspace, jobId: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  const { allVerified, allMatched } = recalcTakeoff(job);
  const has811 = job.takeoff.tasks.some(task => /811/.test(task.title) && task.done);
  const takeoffTasksDone = checklistDone(job.takeoff.tasks);
  const takeoffPhotos = job.photos.filter(photo => photo.status === "complete" && ["Takeoff", "Site Overview", "Measurements", "Access Notes", "Issue"].includes(photo.category)).length;
  if (!allVerified) return { ok: false, message: "Takeoff cannot validate until every PO line has a verified field amount.", workspace };
  if (!has811) return { ok: false, message: "Takeoff cannot validate until Complete 811 Utility Call is done.", workspace };
  if (!takeoffTasksDone) return { ok: false, message: "Takeoff cannot validate until all takeoff checklist items are done.", workspace };
  if (takeoffPhotos < 1) return { ok: false, message: "Takeoff cannot validate until at least one categorized takeoff photo exists.", workspace };
  if (!allMatched) {
    job.takeoff.statusPill = { label: "Variance", tone: "red" };
    job.queuePill = { label: "Mismatch Review", tone: "red" };
    setGate(job, "Takeoff complete", false, "PO, verified takeoff, and community package do not match", "Variance", "red");
    job.activity.unshift(event("Takeoff validation failed. Variance found between PO amount, verified takeoff amount, and community package amount.", next.currentUser.name, "warning"));
    return { ok: false, message: "Variance found. Return to CSM review before scheduling.", workspace: next };
  }
  job.takeoff.statusPill = { label: "Validated", tone: "green" };
  job.queuePill = { label: "Ready to Schedule", tone: "green" };
  setGate(job, "Takeoff complete", true, "PO line items, verified takeoff quantities, 811, photos, and package match validated", "Done", "green");
  job.stageIndex = Math.max(job.stageIndex, 2);
  job.workOrder.status = "Ready to Schedule";
  setKpi(job, "takeoff", "Validated", "PO, takeoff, and package match");
  job.activity.unshift(event("Takeoff validated. Job moved to Ready to Schedule.", next.currentUser.name, "record-update"));
  return { ok: true, message: "Takeoff validated. The job is now Ready to Schedule.", workspace: next };
}

export function acceptPhotoPackage(workspace: FieldManagerWorkspace, jobId: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  const completeCount = job.photos.filter(p => p.status === "complete").length;
  const requiredCount = Math.max(4, job.photos.filter(p => p.status !== "add").length - 1);
  if (completeCount < requiredCount) {
    return { ok: false, message: `Photo package is not ready. ${completeCount} accepted, ${requiredCount} required.`, workspace };
  }
  setKpi(job, "photos", `${completeCount} / ${completeCount}`, "Photo categories accepted by FM");
  job.activity.unshift(event("Photo package accepted by FM. QI scoring can proceed.", next.currentUser.name));
  return { ok: true, message: "Photo package accepted by FM. QI scoring can proceed.", workspace: next };
}

export function uploadPhoto(workspace: FieldManagerWorkspace, jobId: string, photo: PhotoProof): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  job.photos.splice(Math.max(job.photos.length - 1, 0), 0, { ...photo, uploadedAt: now(), uploadedBy: next.currentUser.name });
  setKpi(job, "photos", `${job.photos.filter(p => p.status === "complete").length} / ${job.photos.filter(p => p.status !== "add").length - 1}`, "Photo uploaded and categorized");
  job.activity.unshift(event(`Photo uploaded: ${photo.category}.`, next.currentUser.name));
  return { ok: true, message: `Photo uploaded: ${photo.category}.`, workspace: next };
}

export function submitQiPass(workspace: FieldManagerWorkspace, jobId: string, scores?: Record<string, number>, notes?: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  if (job.photos.filter(p => p.status === "complete").length < 4) return { ok: false, message: "QI cannot be submitted until at least 4 accepted photo categories exist.", workspace };
  if (!job.qi.categories.length) return { ok: false, message: "QI cannot be submitted because this job has no QI categories loaded.", workspace };
  job.qi.categories = job.qi.categories.map(c => ({ ...c, score: scores?.[c.category] ?? c.score }));
  const avg = Number((job.qi.categories.reduce((sum, c) => sum + c.score, 0) / job.qi.categories.length).toFixed(1));
  job.qi.overallScore = avg;
  job.qi.status = avg < 7 ? "Held" : "Passed";
  job.qi.closeoutStatus = avg < 7 ? "Waiting" : "Ready";
  job.qi.invoiceStatus = avg < 7 ? "Locked" : "Ready";
  setKpi(job, "qi", avg.toString(), avg < 7 ? "Red QI hold. Finished Job required." : "QI passed 24-48 hours after field completion");
  setKpi(job, "invoice", avg < 7 ? "Blocked" : "Ready", avg < 7 ? "Waits for Finished Job" : "Closeout approval unlocks invoice");
  job.stageIndex = avg < 7 ? Math.max(job.stageIndex, 5) : Math.max(job.stageIndex, 6);
  setGate(job, "FM QI approval", avg >= 7, avg >= 7 ? "QI passed" : "Red QI hold", avg >= 7 ? "Done" : "Held", avg >= 7 ? "green" : "red");
  job.activity.unshift(event(`QI submitted in the 24-48 hour window. Overall score ${avg}. ${notes ?? ""}`.trim(), next.currentUser.name, avg < 7 ? "warning" : "record-update"));
  return { ok: true, message: avg < 7 ? "QI held. Create a Finished Job before closeout." : "QI passed. Closeout can now be approved and invoice path is ready.", workspace: next };
}

export function createFinishedJob(workspace: FieldManagerWorkspace, jobId: string, reason: string, scope: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  const childNumber = `${job.workOrder.number}-FJ-${job.activity.length + 1}`;
  job.stageIndex = Math.max(job.stageIndex, 5);
  setKpi(job, "invoice", "Blocked", "Finished Job must close first");
  job.activity.unshift(event(`Finished Job ${childNumber} created. Reason: ${reason}. Scope: ${scope || "Not provided"}.`, next.currentUser.name, "record-update"));
  return { ok: true, message: `Finished Job child WorkOrder ${childNumber} created and linked to ${job.workOrder.number}.`, workspace: next };
}

export function returnWork(workspace: FieldManagerWorkspace, jobId: string, owner: string, reason: string, instructions: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  job.stageIndex = Math.max(1, Math.min(job.stageIndex, 5));
  setKpi(job, "invoice", "Blocked", "Returned work must be resolved first");
  setKpi(job, "qi", "Returned", reason);
  job.queuePill = { label: "NFI", tone: "amber" };
  setGate(job, "FM QI approval", false, reason, "Returned", "amber");
  job.activity.unshift(event(`Returned to ${owner}. Reason: ${reason}. Instructions: ${instructions || "No instructions entered"}.`, next.currentUser.name, "warning"));
  return { ok: true, message: `Return note sent to ${owner}. Closeout remains blocked.`, workspace: next };
}

export function requestReschedule(workspace: FieldManagerWorkspace, jobId: string, reason: string, requestedDate: string, notes: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  job.workOrder.scheduledDate = requestedDate || job.workOrder.scheduledDate;
  job.activity.unshift(event(`Reschedule requested. Reason: ${reason}. Requested date: ${requestedDate}. Notes: ${notes || "None"}.`, next.currentUser.name));
  return { ok: true, message: "Reschedule request sent to Scheduling Manager. Scheduling owns the actual schedule change.", workspace: next };
}

export function dispatchAquaRepair(workspace: FieldManagerWorkspace, jobId: string, issueType: string, priority: string, tech: string, inventory: string, notes: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  job.queuePill = { label: priority, tone: priority === "Same-Day" ? "red" : "amber" };
  setKpi(job, "aqua", priority, issueType);
  setKpi(job, "health", priority === "Same-Day" ? "Red" : "Amber", `Aqua ${issueType} dispatched to ${tech}`);
  if (!job.aqua.checks.length) job.aqua.checks.push({ date: new Date().toLocaleDateString(), tech, status: priority, tone: priority === "Same-Day" ? "red" : "amber", issue: issueType });
  job.activity.unshift(event(`Aqua repair dispatched to ${tech}. Issue: ${issueType}. Priority: ${priority}. Inventory: ${inventory || "Not entered"}. Notes: ${notes || "None"}.`, next.currentUser.name, "record-update"));
  return { ok: true, message: "Aqua repair ticket updated and repair dispatch recorded.", workspace: next };
}

export function approveCloseout(workspace: FieldManagerWorkspace, jobId: string): ActionResult {
  const next = clone(workspace);
  const job = findJob(next, jobId);
  if (job.qi.status !== "Passed") return { ok: false, message: "Closeout is blocked until QI status is Passed.", workspace };
  if (job.gateStatus.some(g => !g.done)) return { ok: false, message: "Closeout is blocked because one or more gates are still open.", workspace };
  job.stageIndex = 7;
  setKpi(job, "invoice", "Created", "Invoice created to Division Account");
  job.workOrder.status = "Approved";
  job.activity.unshift(event("Closeout approved. Invoice path released to Builder Division account only.", next.currentUser.name, "record-update"));
  return { ok: true, message: "Closeout approved. Invoice path released to the Division Account.", workspace: next };
}
