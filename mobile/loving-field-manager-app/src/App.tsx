import React, { useEffect, useMemo, useState } from "react";
import type { ActionResult, FieldManagerWorkspace, JobRecord, PillTone, PhotoProof } from "./types";
import { exportWorkspace, loadWorkspace, loadLiveWorkspace, resetWorkspace, saveWorkspace, commitLiveAction, type SalesforceWrite } from "./services/fieldManagerRepository";
import { acceptPhotoPackage, advanceStage, approveCloseout, completeChecklistItem, createFinishedJob, createQuoteRequest, createWarrantyJob, dispatchAquaRepair, flagSiteNotReady, markSiteReady, requestReschedule, returnWork, selectJob, submitQiPass, updateTakeoffVerifiedAmount, uploadPhoto, validateTakeoff } from "./services/domainActions";
import { captureFieldPhoto } from "./mobile/camera";
import { resolveStartupMode, handleOAuthCallback, startOAuthFlow, clearSession, type AppMode, type SalesforceSession } from "./services/auth";
import { SalesforceFieldManagerApi } from "./services/salesforceApiClient";

type TabId = "command" | "takeoffTab" | "workTab" | "aquaTab" | "photosTab" | "qiTab" | "mobileTab";
type ModalKey = "takeoff" | "schedule" | "photos" | "qi" | "fj" | "return" | "reschedule" | "aquaRepair" | "photoUpload" | "jsonExport" | "siteVisit" | "siteReadiness" | "healthCheck" | "aquaCheck" | "aquaPickup" | "siteReady" | "siteNotReady" | "quoteRequest" | "warrantyJob";

const tabOrder: { id: TabId; label: string }[] = [
  { id: "command", label: "FM Command Center" },
  { id: "takeoffTab", label: "Takeoff + Site Readiness" },
  { id: "workTab", label: "WorkOrder + Field Service" },
  { id: "aquaTab", label: "Aqua" },
  { id: "photosTab", label: "Photos + Proof" },
  { id: "qiTab", label: "QI + Closeout" },
  { id: "mobileTab", label: "Field Mobile View" }
];

function classNames(...values: Array<string | false | null | undefined>) {
  return values.filter(Boolean).join(" ");
}

function Pill({ tone, children }: { tone: PillTone; children: React.ReactNode }) {
  return <span className={`pill ${tone}`}>{children}</span>;
}

function MiniButton({ children, onClick }: { children: React.ReactNode; onClick: () => void }) {
  return <button className="mini-button" onClick={onClick}>{children}</button>;
}

function FieldGrid({ fields }: { fields: { label: string; value: string }[] }) {
  return (
    <div className="field-grid">
      {fields.map((field) => (
        <div className="field" key={field.label}>
          <label>{field.label}</label>
          <div>{field.value}</div>
        </div>
      ))}
    </div>
  );
}


function FieldBlocks({ fields }: { fields: { label: string; value: string }[] }) {
  return (
    <>
      {fields.map((field) => (
        <div className="field" key={field.label}>
          <label>{field.label}</label>
          <div>{field.value}</div>
        </div>
      ))}
    </>
  );
}

function Checklist({ items }: { items: { title: string; note: string; done: boolean; pill?: string; tone?: PillTone }[] }) {
  return (
    <div className="checklist">
      {items.map((item) => (
        <div className={classNames("check-item", item.done && "done")} key={`${item.title}-${item.note}`}>
          <div className="check-box"></div>
          <div>
            <div className="check-title">{item.title}</div>
            <div className="check-note">{item.note}</div>
          </div>
          {item.pill ? <Pill tone={item.tone ?? (item.done ? "green" : "amber")}>{item.pill}</Pill> : null}
        </div>
      ))}
    </div>
  );
}

function Toast({ message }: { message: string | null }) {
  return <div className={classNames("toast", message && "show")}>{message}</div>;
}

function Topbar({ userName, mode, onSignOut }: { userName: string; mode: AppMode; onSignOut?: () => void }) {
  const modeBadge = mode === 'live'
    ? <span className="user-pill" style={{ background: 'rgba(4,136,75,0.25)', borderColor: 'rgba(4,136,75,0.5)', color: '#a7f3d0', fontSize: 11 }}>● LIVE SALESFORCE</span>
    : <span className="user-pill" style={{ background: 'rgba(254,147,57,0.25)', borderColor: 'rgba(254,147,57,0.5)', color: '#fde68a', fontSize: 11 }}>◎ DEMO MODE</span>;
  return (
    <div className="topbar">
      <div className="brand"><div className="logo">L</div><div>LOVING Salesforce | Field Manager Workspace</div></div>
      <div className="top-actions">
        {modeBadge}
        <span className="user-pill">FM: {userName}</span>
        {onSignOut ? <button className="mini-button" style={{ color: '#d9e7ff', background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.2)' }} onClick={onSignOut}>Sign Out</button> : null}
      </div>
    </div>
  );
}

function LoginScreen({ onLogin, onDemo }: { onLogin: () => void; onDemo: () => void }) {
  const [loggingIn, setLoggingIn] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const handleLogin = async () => {
    setLoggingIn(true);
    setError(null);
    try { await startOAuthFlow(); }
    catch (err) { setError(err instanceof Error ? err.message : String(err)); setLoggingIn(false); }
  };
  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="record-header" style={{ maxWidth: 440, width: '100%', padding: 32, textAlign: 'center' }}>
        <div style={{ width: 56, height: 56, borderRadius: 14, background: 'linear-gradient(135deg,#0a8aa6,#04844b)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', boxShadow: '0 2px 8px rgba(0,0,0,0.18)' }}>
          <span style={{ color: '#fff', fontSize: 28, fontWeight: 900 }}>L</span>
        </div>
        <h2 style={{ marginBottom: 6, color: 'var(--navy)' }}>LOVING Field Manager</h2>
        <p style={{ color: 'var(--muted)', fontSize: 13, marginBottom: 24 }}>Sign in with your Salesforce credentials to load your live work queue.</p>
        {error ? <div className="alert red" style={{ marginBottom: 16, textAlign: 'left' }}><div>!</div><div>{error}</div></div> : null}
        <button className="button primary" style={{ width: '100%', justifyContent: 'center', marginBottom: 10 }} onClick={handleLogin} disabled={loggingIn}>
          {loggingIn ? 'Redirecting to Salesforce...' : '🔐 Sign in with Salesforce'}
        </button>
        <button className="button" style={{ width: '100%', justifyContent: 'center' }} onClick={onDemo}>
          Use Demo Mode (seed data)
        </button>
        <p style={{ marginTop: 16, fontSize: 11, color: 'var(--muted)' }}>
          Requires <code>VITE_SF_CLIENT_ID</code> and <code>VITE_SF_INSTANCE_URL</code> to be set.
        </p>
      </div>
    </div>
  );
}

function LoadingScreen({ message }: { message: string }) {
  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ textAlign: 'center', color: 'var(--muted)' }}>
        <div style={{ fontSize: 32, marginBottom: 12 }}>⏳</div>
        <div style={{ fontSize: 14 }}>{message}</div>
      </div>
    </div>
  );
}

function Sidebar({ workspace, selectedJob, onSelect }: { workspace: FieldManagerWorkspace; selectedJob: JobRecord; onSelect: (id: string) => void }) {
  const orderedJobs = workspace.workQueue
    .map((queue) => ({ ...queue, job: workspace.jobs.find((job) => job.id === queue.jobId) }))
    .filter((row): row is { jobId: string; priority: number; job: JobRecord } => Boolean(row.job))
    .sort((a, b) => a.priority - b.priority);

  return (
    <aside className="sidebar">
      <div className="side-title">FM Work Queue</div>
      {orderedJobs.map(({ job }) => (
        <div className={classNames("job-card", job.id === selectedJob.id && "active")} onClick={() => onSelect(job.id)} key={job.id}>
          <strong>{job.queueTitle}</strong>
          <span>{job.queueSubtitle}</span>
          <span><Pill tone={job.queuePill.tone}>{job.queuePill.label}</Pill></span>
        </div>
      ))}

      <div className="side-title">Today’s FM Priorities</div>
      <div className="checklist">
        {workspace.priorities.map((priority) => (
          <div className={classNames("check-item", priority.status === "Done" && "done")} key={priority.id}>
            <div className="check-box"></div>
            <div><div className="check-title">{priority.title}</div><div className="check-note">{priority.note}</div></div>
            <Pill tone={priority.tone}>{priority.pill}</Pill>
          </div>
        ))}
      </div>
    </aside>
  );
}

function StageRail({ job }: { job: JobRecord }) {
  return (
    <div className="stage-rail" id="stageRail">
      {job.stageLabels.map((stage, index) => (
        <div className={classNames("stage", index < job.stageIndex && "done", index === job.stageIndex && "current")} key={stage}>{stage}</div>
      ))}
    </div>
  );
}

function RecordHeader({ job, onOpenModal, onAdvance }: { job: JobRecord; onOpenModal: (key: ModalKey) => void; onAdvance: () => void }) {
  return (
    <section className="record-header">
      <div className="crumbs">
        {job.breadcrumbs.map((crumb, index) => (
          <span key={`${crumb}-${index}`}>{index > 0 ? "›" : null}{index > 0 ? " " : null}{crumb}</span>
        ))}
      </div>
      <div className="header-body">
        <div>
          <div className="record-kicker">{job.recordKicker}</div>
          <h1>{job.title}</h1>
          <div className="header-meta">
            {job.meta.map((item) => <span key={item}>{item}</span>)}
          </div>
        </div>
        <div className="header-actions">
          <button className="button" onClick={() => onOpenModal("takeoff")}>Open Takeoff</button>
          <button className="button" onClick={() => onOpenModal("schedule")}>Review Schedule</button>
          <button className="button" onClick={() => onOpenModal("photos")}>Review Photos</button>
          <button className="button primary" onClick={() => onOpenModal("qi")}>Start QI Review</button>
          <button className="button green" onClick={onAdvance}>Advance Demo Stage</button>
        </div>
      </div>
      <StageRail job={job} />
    </section>
  );
}

function KpiGrid({ job }: { job: JobRecord }) {
  return (
    <section className="kpi-grid">
      {job.kpis.map((kpi) => (
        <div className="kpi" key={kpi.id}>
          <div className="label">{kpi.label}</div>
          <div className="value">{kpi.value}</div>
          <div className="sub">{kpi.sub}</div>
        </div>
      ))}
    </section>
  );
}

function CommandTab({ workspace, job, onOpenModal, onSwitchTab, onApproveCloseout }: { workspace: FieldManagerWorkspace; job: JobRecord; onOpenModal: (key: ModalKey) => void; onSwitchTab: (id: TabId) => void; onApproveCloseout: () => void }) {
  const queueRows = workspace.workQueue
    .map((queue) => ({ priority: queue.priority, job: workspace.jobs.find((item) => item.id === queue.jobId) }))
    .filter((row): row is { priority: number; job: JobRecord } => Boolean(row.job))
    .sort((a, b) => a.priority - b.priority);

  return (
    <div id="command" className="tab-content active">
      <div className="alert aqua">
        <div>ⓘ</div>
        <div><strong>What the Field Manager sees first:</strong> This page does not make the FM hunt through the full Salesforce model. It shows the exact Lot, WorkOrder, schedule, crew, proof, Aqua, QI, and closeout gates needed to move this job forward.</div>
      </div>
      <div className="layout">
        <div className="cards">
          <div className="card">
            <div className="card-header"><div><div className="card-title">Next Best Action</div><div className="card-subtitle">System-driven work queue for the FM</div></div><Pill tone="aqua">Now</Pill></div>
            <div className="card-body">
              <div className="timeline">
                {job.nextBestActions.map((action) => (
                  <div className="timeline-row" key={`${action.step}-${action.title}`}><div className={`dot ${action.tone}`}>{action.step}</div><div><div className="timeline-title">{action.title}</div><div className="timeline-note">{action.note}</div></div><div className="timeline-time">{action.time}</div></div>
                ))}
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-header"><div><div className="card-title">Record Ownership</div><div className="card-subtitle">Keeps the FM from working at the wrong level</div></div><Pill tone="green">Correct</Pill></div>
            <div className="card-body"><FieldGrid fields={job.ownership} /></div>
          </div>

          <div className="card full">
            <div className="card-header"><div><div className="card-title">FM Daily Operating Queue</div><div className="card-subtitle">What {workspace.currentUser.name} manages today</div></div><MiniButton onClick={() => onOpenModal("jsonExport")}>Open List View</MiniButton></div>
            <div className="card-body">
              <table>
                <thead><tr><th>Priority</th><th>Lot</th><th>Stage</th><th>Risk</th><th>Required FM Action</th><th>Button</th></tr></thead>
                <tbody>
                  {queueRows.map(({ priority, job: rowJob }) => {
                    const health = rowJob.kpis.find(k => k.id === "health");
                    const action = rowJob.nextBestActions[0];
                    const tone: PillTone = rowJob.queuePill.tone;
                    return <tr key={rowJob.id}><td><Pill tone={tone}>{priority}</Pill></td><td>{rowJob.queueTitle}</td><td>{rowJob.stageLabels[rowJob.stageIndex]}</td><td>{health?.sub ?? "None"}</td><td>{action?.title ?? "Review record"}</td><td><MiniButton onClick={() => rowJob.id === job.id ? onSwitchTab("qiTab") : onOpenModal("jsonExport")}>{rowJob.id === job.id ? "Review" : "Open"}</MiniButton></td></tr>;
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <aside className="right-rail">
          <div className="card">
            <div className="card-header"><div className="card-title">Gate Status</div><Pill tone={job.gateStatus.some(g => !g.done) ? "amber" : "green"}>{job.gateStatus.filter(g => !g.done).length} open</Pill></div>
            <div className="card-body"><Checklist items={job.gateStatus} /></div>
          </div>
          <div className="card">
            <div className="card-header"><div className="card-title">Role Guardrails</div><Pill tone="blue">FM</Pill></div>
            <div className="card-body">
              <div className="alert green"><div>✓</div><div><strong>FM can:</strong> review takeoff, return field work, approve QI, create Finished Jobs, approve closeout, manage Aqua decisions.</div></div>
              <div className="alert red"><div>!</div><div><strong>FM cannot:</strong> change builder BMG pricing, bill Parent Account, skip CSM takeoff approval, or close without required proof.</div></div>
              <button className="button green" onClick={onApproveCloseout}>Approve Closeout</button><br /><br />
              <button className="button" onClick={() => onOpenModal("quoteRequest")}>Request Quote</button>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}


function TakeoffLineTable({ job, onUpdateVerified }: { job: JobRecord; onUpdateVerified: (lineId: string, value: string) => void }) {
  const rows = job.takeoff.lineItems ?? [];
  return (
    <table>
      <thead><tr><th>PO Line Item</th><th>UOM</th><th>PO Amount</th><th>Verified Amount</th><th>Community Package</th><th>Status</th></tr></thead>
      <tbody>
        {rows.length ? rows.map((line) => (
          <tr key={line.id}>
            <td><strong>{line.poLineItem}</strong></td>
            <td>{line.uom}</td>
            <td>{line.poQuantity.toLocaleString()}</td>
            <td><input type="number" value={line.verifiedQuantity ?? ""} onChange={(event) => onUpdateVerified(line.id, event.target.value)} aria-label={`${line.poLineItem} verified amount`} /></td>
            <td>{line.communityPackageQuantity.toLocaleString()}</td>
            <td><Pill tone={line.status === "Match" ? "green" : line.status === "Variance" ? "red" : "amber"}>{line.status}</Pill></td>
          </tr>
        )) : <tr><td colSpan={6}>No PO line items loaded yet.</td></tr>}
      </tbody>
    </table>
  );
}

function InteractiveChecklist({ items, onToggle }: { items: { id?: string; title: string; note: string; done: boolean; pill?: string; tone?: PillTone }[]; onToggle: (id: string) => void }) {
  return (
    <div className="checklist">
      {items.map((item) => (
        <div className={classNames("check-item", item.done && "done")} key={`${item.id ?? item.title}-${item.note}`} onClick={() => onToggle(item.id ?? item.title)}>
          <div className="check-box"></div>
          <div>
            <div className="check-title">{item.title}</div>
            <div className="check-note">{item.note}</div>
          </div>
          <Pill tone={item.tone ?? (item.done ? "green" : "amber")}>{item.pill ?? (item.done ? "Done" : "Open")}</Pill>
        </div>
      ))}
    </div>
  );
}

function HealthCheckPanel({ job, onOpenModal }: { job: JobRecord; onOpenModal: (key: ModalKey) => void }) {
  const checks = job.workOrder.healthChecks ?? [];
  return (
    <div className="card full">
      <div className="card-header"><div><div className="card-title">2 PM Crew Health Check</div><div className="card-subtitle">FM watches crew progress before the job becomes tomorrow's Finished Job problem</div></div><MiniButton onClick={() => onOpenModal("healthCheck")}>Open</MiniButton></div>
      <div className="card-body">
        <table><thead><tr><th>Due</th><th>Crew</th><th>Foreman</th><th>Status</th><th>Remaining</th><th>Can Fix Tomorrow?</th><th>Notes</th></tr></thead><tbody>
          {checks.length ? checks.map(check => <tr key={check.id}><td>{check.dueTime}</td><td>{check.crew}</td><td>{check.foreman}</td><td><Pill tone={check.status === "Green" ? "green" : check.status === "Red" ? "red" : "amber"}>{check.status}</Pill></td><td>{check.scopeRemainingPct}%</td><td>{check.canFixTomorrow ? "Yes" : "No"}</td><td>{check.notes}</td></tr>) : <tr><td colSpan={7}>No health check loaded.</td></tr>}
        </tbody></table>
      </div>
    </div>
  );
}

function TakeoffTab({ job, onOpenModal, onUpdateVerified, onValidateTakeoff, onToggleChecklist }: { job: JobRecord; onOpenModal: (key: ModalKey) => void; onUpdateVerified: (lineId: string, value: string) => void; onValidateTakeoff: () => void; onToggleChecklist: (area: "takeoff" | "siteReadiness", itemId: string) => void }) {
  return (
    <div id="takeoffTab" className="tab-content active">
      <div className="layout">
        <div className="cards">
          <div className="card full">
            <div className="card-header"><div><div className="card-title">PO-Generated Takeoff Checklist</div><div className="card-subtitle">The PO creates these rows. The FM enters the measured verified amount next to each PO amount.</div></div><Pill tone={job.takeoff.statusPill.tone}>{job.takeoff.statusPill.label}</Pill></div>
            <div className="card-body"><TakeoffLineTable job={job} onUpdateVerified={onUpdateVerified} /></div>
          </div>
          <div className="card full">
            <div className="card-header"><div><div className="card-title">Takeoff Validation Result</div><div className="card-subtitle">System match: PO amount vs. verified takeoff amount vs. community package amount</div></div><Pill tone={job.takeoff.matchStatus === "Validated" ? "green" : job.takeoff.matchStatus === "Variance" ? "red" : "amber"}>{job.takeoff.matchStatus}</Pill></div>
            <div className="card-body">
              <table><thead><tr><th>Item</th><th>Community Package</th><th>Verified Takeoff</th><th>Result</th></tr></thead><tbody>
                {job.takeoff.packageComparison.length ? job.takeoff.packageComparison.map(row => <tr key={row.item}><td>{row.item}</td><td>{row.package}</td><td>{row.takeoff}</td><td><Pill tone={row.tone}>{row.result}</Pill></td></tr>) : <tr><td colSpan={4}>No package comparison rows available for this stage.</td></tr>}
              </tbody></table>
            </div>
          </div>
          <div className="card">
            <div className="card-header"><div><div className="card-title">Takeoff Tasks</div><div className="card-subtitle">Includes Complete 811 Utility Call</div></div><MiniButton onClick={() => onOpenModal("takeoff")}>Open Record</MiniButton></div>
            <div className="card-body"><InteractiveChecklist items={job.takeoff.tasks} onToggle={(id) => onToggleChecklist("takeoff", id)} /></div>
          </div>
          <div className="card">
            <div className="card-header"><div><div className="card-title">Site Readiness, 48 Hours Before Start</div><div className="card-subtitle">Separate from takeoff. Confirms the job can actually start.</div></div><MiniButton onClick={() => onOpenModal("siteReadiness")}>Open</MiniButton></div>
            <div className="card-body"><InteractiveChecklist items={job.takeoff.siteReadiness ?? []} onToggle={(id) => onToggleChecklist("siteReadiness", id)} /></div>
          </div>
          <div className="card full">
            <div className="card-header"><div><div className="card-title">Site Visits</div><div className="card-subtitle">Used to decide warranty, Finished Job, or proposal work before anyone guesses wrong</div></div><MiniButton onClick={() => onOpenModal("siteVisit")}>Open Site Visit</MiniButton></div>
            <div className="card-body">
              <table><thead><tr><th>Purpose</th><th>Status</th><th>Decision</th><th>Checklist</th><th>Notes</th></tr></thead><tbody>
                {(job.takeoff.siteVisits ?? []).map(visit => <tr key={visit.id}><td>{visit.purpose}</td><td><Pill tone={visit.status === "Complete" ? "green" : "blue"}>{visit.status}</Pill></td><td>{visit.decision}</td><td>{visit.checklist.filter(item => item.done).length} / {visit.checklist.length}</td><td>{visit.notes}</td></tr>)}
              </tbody></table>
              <br /><button className="button amber" onClick={() => onOpenModal("warrantyJob")}>Create Warranty Job</button>
            </div>
          </div>
        </div>
        <aside className="right-rail">
          <div className="card"><div className="card-header"><div className="card-title">FM Decision</div></div><div className="card-body"><button className="button green" onClick={onValidateTakeoff}>Validate and Move to Ready to Schedule</button><br /><br /><button className="button" onClick={() => onOpenModal("siteReady")}>Mark Site Ready</button><br /><br /><button className="button red" onClick={() => onOpenModal("siteNotReady")}>Flag Site Not Ready</button><br /><br /><button className="button" onClick={() => onOpenModal("return")}>Return with Notes</button></div></div>
          <div className="alert amber"><div>!</div><div><strong>Guardrail:</strong> If the PO line amount, verified takeoff amount, and community package amount do not match within tolerance, the job cannot move to scheduling. It goes to CSM mismatch review.</div></div>
        </aside>
      </div>
    </div>
  );
}

function WorkTab({ job, onOpenModal }: { job: JobRecord; onOpenModal: (key: ModalKey) => void }) {
  const fields = [
    { label: "WorkOrder Status", value: job.workOrder.status },
    { label: "Service Appointment", value: job.workOrder.serviceAppointment },
    { label: "Assigned Resource", value: job.workOrder.assignedResource },
    { label: "Scheduled Date", value: job.workOrder.scheduledDate },
    { label: "Route Sequence", value: job.workOrder.routeSequence },
    { label: "Territory", value: job.workOrder.territory }
  ];
  return (
    <div id="workTab" className="tab-content active">
      <div className="layout">
        <div className="cards">
          <div className="card full">
            <div className="card-header"><div><div className="card-title">Standard WorkOrder + Field Service</div><div className="card-subtitle">This is where FSL becomes the scheduling and execution backbone</div></div><Pill tone="aqua">{job.workOrder.number}</Pill></div>
            <div className="card-body split-3"><FieldBlocks fields={fields} /></div>
          </div>
          <HealthCheckPanel job={job} onOpenModal={onOpenModal} />
          <div className="card full">
            <div className="card-header"><div className="card-title">WorkOrder Line Items</div><MiniButton onClick={() => onOpenModal("jsonExport")}>Open WOLI</MiniButton></div>
            <div className="card-body">
              <table><thead><tr><th>Line</th><th>Planned Qty</th><th>Actual Qty</th><th>Goal Hrs</th><th>Actual Hrs</th><th>Status</th></tr></thead><tbody>
                {job.workOrder.lineItems.length ? job.workOrder.lineItems.map(row => <tr key={row.line}><td>{row.line}</td><td>{row.planned}</td><td>{row.actual}</td><td>{row.goal}</td><td>{row.actualHours}</td><td><Pill tone={row.status === "Complete" ? "green" : "amber"}>{row.status}</Pill></td></tr>) : <tr><td colSpan={6}>No line items loaded yet.</td></tr>}
              </tbody></table>
            </div>
          </div>
        </div>
        <aside className="right-rail">
          <div className="card"><div className="card-header"><div className="card-title">Schedule Controls</div><Pill tone="green">Locked</Pill></div><div className="card-body"><FieldGrid fields={job.workOrder.scheduleControls} /></div></div>
          <div className="card"><div className="card-header"><div className="card-title">FM Actions</div></div><div className="card-body"><button className="button" onClick={() => onOpenModal("reschedule")}>Request Reschedule</button><br /><br /><button className="button amber" onClick={() => onOpenModal("fj")}>Create Finished Job</button></div></div>
        </aside>
      </div>
    </div>
  );
}

function AquaTab({ job, onOpenModal, onToggleChecklist }: { job: JobRecord; onOpenModal: (key: ModalKey) => void; onToggleChecklist: (area: "aquaCheck" | "aquaPickup", itemId: string) => void }) {
  const fields = [
    { label: "Ticket", value: job.aqua.installTicket }, { label: "Tech", value: job.aqua.tech }, { label: "Device Installed", value: job.aqua.deviceInstalled },
    { label: "Coverage Verified", value: job.aqua.coverageVerified }, { label: "Inventory Recorded", value: job.aqua.inventoryRecorded }, { label: "Photos", value: job.aqua.photos }
  ];
  return (
    <div id="aquaTab" className="tab-content active">
      <div className="alert aqua"><div>💧</div><div><strong>Aqua appears because the Community package says Aqua applies.</strong> The FM does not manually remember this. Salesforce reads the Community package/service rules and creates the needed Aqua work.</div></div>
      <div className="cards">
        <div className="card">
          <div className="card-header"><div><div className="card-title">Aqua Install Ticket</div><div className="card-subtitle">Created from package rule after production install scheduled</div></div><Pill tone={job.aqua.installTicket === "N/A" || job.aqua.installTicket === "Not created" ? "gray" : "green"}>{job.aqua.installTicket === "N/A" ? "Not Applicable" : job.aqua.installTicket === "Not created" ? "Not Created" : "Completed"}</Pill></div>
          <div className="card-body"><FieldGrid fields={fields} /></div>
        </div>
        <div className="card">
          <div className="card-header"><div><div className="card-title">Aqua Check Schedule</div><div className="card-subtitle">Daily/recurring checks while lot is active</div></div><Pill tone={job.aqua.checks.length ? "aqua" : "gray"}>{job.aqua.checks.length ? "Pending" : "None"}</Pill></div>
          <div className="card-body">
            <table><thead><tr><th>Date</th><th>Tech</th><th>Status</th><th>Issue</th></tr></thead><tbody>
              {job.aqua.checks.length ? job.aqua.checks.map(check => <tr key={`${check.date}-${check.tech}`}><td>{check.date}</td><td>{check.tech}</td><td><Pill tone={check.tone}>{check.status}</Pill></td><td>{check.issue}</td></tr>) : <tr><td colSpan={4}>No Aqua checks for this job.</td></tr>}
            </tbody></table>
          </div>
        </div>
        <div className="card full">
          <div className="card-header"><div className="card-title">Aqua Check Checklist</div><MiniButton onClick={() => onOpenModal("aquaCheck")}>Open Check</MiniButton></div>
          <div className="card-body"><InteractiveChecklist items={job.aqua.checkChecklist ?? []} onToggle={(id) => onToggleChecklist("aquaCheck", id)} /></div>
        </div>
        <div className="card full">
          <div className="card-header"><div className="card-title">Aqua Pickup Checklist</div><MiniButton onClick={() => onOpenModal("aquaPickup")}>Open Pickup</MiniButton></div>
          <div className="card-body"><InteractiveChecklist items={job.aqua.pickupChecklist ?? []} onToggle={(id) => onToggleChecklist("aquaPickup", id)} /></div>
        </div>
        <div className="card full">
          <div className="card-header"><div className="card-title">Aqua FM Closeout Gates</div><MiniButton onClick={() => onOpenModal("aquaRepair")}>Open Aqua Console</MiniButton></div>
          <div className="card-body"><Checklist items={job.aqua.gates.map(g => ({...g, pill: g.done ? "Done" : "Open", tone: g.done ? "green" : "amber"}))} /></div>
        </div>
      </div>
    </div>
  );
}

function PhotosTab({ job, onOpenModal, onAccept }: { job: JobRecord; onOpenModal: (key: ModalKey) => void; onAccept: () => void }) {
  return (
    <div id="photosTab" className="tab-content active">
      <div className="layout">
        <div>
          <div className="card">
            <div className="card-header"><div><div className="card-title">Photo Proof Package</div><div className="card-subtitle">FM reviews quality and category completion, not just file count</div></div><Pill tone="green">{job.photos.filter(p => p.status === "complete").length} of {job.photos.filter(p => p.status !== "add").length}</Pill></div>
            <div className="card-body photo-grid">
              {job.photos.map((photo) => (
                <div className="photo-card" key={`${photo.category}-${photo.caption}`} onClick={() => photo.status === "add" ? onOpenModal("photoUpload") : undefined}>
                  <div className={classNames("photo-thumb", photo.status === "issue" && "issue", photo.status === "complete" && "complete")}>{photo.status === "complete" ? "✓" : photo.status === "issue" ? "!" : "+"}</div>
                  <div className="photo-caption">{photo.category}<span>{photo.caption}</span></div>
                </div>
              ))}
            </div>
          </div>
        </div>
        <aside className="right-rail">
          <div className="card"><div className="card-header"><div className="card-title">Photo Gate</div></div><div className="card-body"><button className="button green" onClick={onAccept}>Accept Photo Package</button><br /><br /><button className="button" onClick={() => onOpenModal("return")}>Return for Missing Proof</button></div></div>
          <div className="alert amber"><div>!</div><div><strong>Important:</strong> A raw count of photos is not enough. The FM must verify required categories are present and usable.</div></div>
        </aside>
      </div>
    </div>
  );
}

function QiTab({ job, onOpenModal, onSubmitQi, onApproveCloseout }: { job: JobRecord; onOpenModal: (key: ModalKey) => void; onSubmitQi: () => void; onApproveCloseout: () => void }) {
  return (
    <div id="qiTab" className="tab-content active">
      <div className="layout">
        <div className="cards">
          <div className="card full">
            <div className="card-header"><div><div className="card-title">QI Scoring</div><div className="card-subtitle">FM/QI review decides whether closeout can proceed</div></div><Pill tone={job.qi.status === "Passed" ? "green" : job.qi.status === "Held" ? "red" : "amber"}>{job.qi.status}</Pill></div>
            <div className="card-body">
              <table><thead><tr><th>Landscape Rating</th><th>Score</th><th>Meaning</th><th>Result</th></tr></thead><tbody>
                {job.qi.categories.length ? job.qi.categories.map(row => <tr key={row.category}><td><strong>{row.theme ?? "Landscape Score"}</strong><br /><span className="card-subtitle">{row.category}</span></td><td><input type="range" min="1" max="10" value={row.score} onChange={() => null} /><strong>{row.score}/10</strong></td><td>{row.finding}</td><td><Pill tone={row.result === "Pass" ? "green" : "red"}>{row.result}</Pill></td></tr>) : <tr><td colSpan={4}>QI categories are not available until the job reaches field complete.</td></tr>}
              </tbody></table>
              <br /><div className="alert aqua"><div>🌿</div><div><strong>Timing:</strong> QI is completed {job.qi.dueWindow ?? "24-48 hours after Foreman marks Field Complete"}. The point is quality work, photo proof, and no unresolved complaints before closeout.</div></div>
            </div>
          </div>
          <div className="card">
            <div className="card-header"><div className="card-title">Closeout Gate</div><Pill tone={job.qi.closeoutStatus === "Ready" ? "green" : "amber"}>{job.qi.closeoutStatus}</Pill></div>
            <div className="card-body"><Checklist items={job.gateStatus} /></div>
          </div>
          <div className="card">
            <div className="card-header"><div className="card-title">FM Decision</div></div>
            <div className="card-body">
              <button className="button green" onClick={onSubmitQi}>Submit QI Pass</button><br /><br />
              <button className="button amber" onClick={() => onOpenModal("fj")}>Create Finished Job</button><br /><br />
              <button className="button red" onClick={() => onOpenModal("return")}>Return Closeout</button><br /><br />
              <button className="button primary" onClick={onApproveCloseout}>Approve Closeout</button>
            </div>
          </div>
        </div>
        <aside className="right-rail">
          <div className="card"><div className="card-header"><div className="card-title">Invoice Preview</div><Pill tone={job.qi.invoiceStatus === "Ready" ? "green" : "gray"}>{job.qi.invoiceStatus}</Pill></div><div className="card-body"><FieldGrid fields={job.invoicePreview} /></div></div>
          <div className="alert red"><div>!</div><div><strong>Guardrail:</strong> The FM cannot bill the Parent Account. Invoice must attach to the Division Account and the completed WorkOrder.</div></div>
        </aside>
      </div>
    </div>
  );
}

function MobileTab({ job, onOpenModal, onSwitchTab }: { job: JobRecord; onOpenModal: (key: ModalKey) => void; onSwitchTab: (tab: TabId) => void }) {
  const isTakeoffStage = job.stageIndex <= 1;
  const status = job.workOrder.status;
  const photoText = `${job.photos.filter(p => p.status === "complete").length} of ${job.photos.filter(p => p.status !== "add").length} categories uploaded. Tap to review.`;

  const lines = job.takeoff.lineItems ?? [];
  const verifiedCount = lines.filter(l => l.verifiedQuantity !== null).length;
  const has811 = (job.takeoff.tasks ?? []).some(t => /811/.test(t.title) && t.done);
  const hasTakeoffPhoto = job.photos.some(p => p.status === "complete" && ["Takeoff", "Site Overview", "Measurements", "Access Notes"].includes(p.category));

  const phoneBody = isTakeoffStage ? (
    <>
      <div className="mobile-step">
        <strong>Takeoff Appointment</strong>
        <span>{job.workOrder.serviceAppointment && job.workOrder.serviceAppointment !== "Not created" ? job.workOrder.serviceAppointment : "Takeoff Appointment — not yet scheduled"}</span>
      </div>
      <div className="mobile-step">
        <strong>811 Utility Call</strong>
        <span>{has811 ? "Complete ✓" : "Required before takeoff can validate"}</span>
      </div>
      <div className="mobile-step">
        <strong>Field Measurements</strong>
        <span>{lines.length === 0 ? "No PO lines loaded" : `${verifiedCount} of ${lines.length} PO lines measured. Takeoff: ${job.takeoff.matchStatus}`}</span>
      </div>
      <div className="mobile-step">
        <strong>Takeoff Status</strong>
        <span>{job.takeoff.statusPill.label}. {job.takeoff.matchStatus === "Validated" ? "Ready to move to scheduling." : "Measurements or checklist items still required."}</span>
      </div>
      <button className="button primary" style={{ width: "100%", justifyContent: "center" }} onClick={() => onSwitchTab("takeoffTab")}>Enter Measurements</button>
    </>
  ) : (
    <>
      <div className="mobile-step"><strong>Job Status</strong><span>{status}, {job.meta.find(m => m.startsWith("Foreman")) ?? job.meta.find(m => m.startsWith("Aqua Tech")) ?? "field update pending"}</span></div>
      <div className="mobile-step"><strong>Photo Gate</strong><span>{photoText}</span></div>
      <div className="mobile-step"><strong>QI Required</strong><span>{job.qi.status}. Sod, plant, cleanup, Aqua score required when applicable.</span></div>
      <div className="mobile-step"><strong>Aqua</strong><span>{job.aqua.installTicket}. {job.aqua.checks[0]?.status ?? "No active check"}</span></div>
      <button className="button primary" style={{ width: "100%", justifyContent: "center" }} onClick={() => onOpenModal("qi")}>Start QI</button>
    </>
  );

  const mobileActions = isTakeoffStage
    ? [
        { title: "Enter verified field measurements", note: "Open Takeoff tab and fill all PO line quantities", done: verifiedCount === lines.length && lines.length > 0 },
        { title: "Complete 811 Utility Call", note: "Required before takeoff can validate", done: has811 },
        { title: "Submit takeoff photo proof", note: "At least one categorized takeoff photo required", done: hasTakeoffPhoto },
        { title: "Validate takeoff", note: "Move job to Ready to Schedule", done: job.takeoff.matchStatus === "Validated" }
      ]
    : [
        { title: "Review photos", note: "Open categorized proof", done: job.photos.filter(p => p.status === "complete").length >= 4 },
        { title: "Score QI", note: "Submit pass/fail", done: job.qi.status === "Passed" },
        { title: "Approve closeout", note: "Unlock invoice path", done: job.stageIndex >= 7 }
      ];

  const trainingNote = isTakeoffStage
    ? "At the Takeoff Appointment, the FM's job is to measure each PO line item in the field, complete the 811 utility call, and submit takeoff photos. No scheduling is created until the verified field measurements match the community package within tolerance."
    : "The FM should be trained to ask only three questions: Is the scope complete? Is the proof complete? Is the quality acceptable? If yes, approve closeout. If no, return or create Finished Job.";

  return (
    <div id="mobileTab" className="tab-content active">
      <div className="layout">
        <div className="cards">
          <div className="card full">
            <div className="card-header"><div><div className="card-title">What the FM Sees on Tablet or Phone</div><div className="card-subtitle">This is not the foreman-only mobile flow. It is the FM review and approval view.</div></div><Pill tone="blue">Responsive</Pill></div>
            <div className="card-body split-3">
              <div className="phone-wrap">
                <div className="phone-screen">
                  <div className="phone-header">LOVING FM Review<br />{job.queueTitle}</div>
                  <div className="phone-body">{phoneBody}</div>
                </div>
              </div>
              <div className="card" style={{ boxShadow: "none" }}><div className="card-header"><div className="card-title">FM Mobile Actions</div></div><div className="card-body"><Checklist items={mobileActions} /></div></div>
              <div className="card" style={{ boxShadow: "none" }}><div className="card-header"><div className="card-title">What is hidden from FM Mobile</div></div><div className="card-body"><div className="alert red"><div>!</div><div>BMG pricing edits, Parent Account billing, admin setup, and destructive record actions stay out of the FM mobile flow.</div></div><div className="alert aqua"><div>ⓘ</div><div>The mobile screen is focused on review, proof, QI, and closeout decisions.</div></div></div></div>
            </div>
          </div>
        </div>
        <aside className="right-rail"><div className="card"><div className="card-header"><div className="card-title">Training Note</div></div><div className="card-body">{trainingNote}</div></div></aside>
      </div>
    </div>
  );
}

function Modal({ keyName, workspace, job, onClose, onCommit }: { keyName: ModalKey | null; workspace: FieldManagerWorkspace; job: JobRecord; onClose: () => void; onCommit: (result: ActionResult, sfWrite?: SalesforceWrite) => void }) {
  const [form, setForm] = useState<Record<string, string>>({});
  if (!keyName) return null;

  const set = (name: string, value: string) => setForm((prev) => ({ ...prev, [name]: value }));
  const closeOnBackdrop = (event: React.MouseEvent<HTMLDivElement>) => { if ((event.target as HTMLElement).id === "modalBackdrop") onClose(); };

  const modalMeta: Record<ModalKey, { title: string; subtitle: string; primary: string }> = {
    takeoff: { title: `Takeoff Record: ${job.takeoff.statusPill.label}`, subtitle: "FM field verification before WorkOrder scheduling", primary: "Mark Reviewed" },
    schedule: { title: "Field Service Schedule Review", subtitle: "ServiceAppointment and AssignedResource details", primary: "Confirm Schedule" },
    photos: { title: "Photo Review", subtitle: "Required proof categories before QI and closeout", primary: "Accept Photos" },
    qi: { title: "Start QI Review", subtitle: "FM review must pass before closeout approval", primary: "Submit QI Pass" },
    fj: { title: "Create Finished Job", subtitle: "Child WorkOrder when scope is incomplete or QI fails", primary: "Create Finished Job" },
    return: { title: "Return Work with Notes", subtitle: "Use when proof, scope, or notes are incomplete", primary: "Return to Field" },
    reschedule: { title: "Request Reschedule", subtitle: "FM can request, Scheduling Manager owns schedule changes", primary: "Send Request" },
    aquaRepair: { title: "Aqua Same-Day / Repair Decision", subtitle: "FM decides repair dispatch, tech completes work in mobile", primary: "Dispatch Repair" },
    photoUpload: { title: "Add Photo Proof", subtitle: "Upload or capture a categorized proof photo", primary: "Save Photo" },
    jsonExport: { title: "Data Export / API Payload", subtitle: "Current state used by the app and ready for API wiring", primary: "Close" },
    siteVisit: { title: "Site Visit Decision", subtitle: "Determine Warranty, Finished Job, or Proposal Scope", primary: "Close" },
    siteReadiness: { title: "Site Readiness Checklist", subtitle: "48 hours before job start", primary: "Close" },
    healthCheck: { title: "2 PM Health Check", subtitle: "Crew and job status checkpoint", primary: "Close" },
    aquaCheck: { title: "Aqua Check Checklist", subtitle: "Recurring Aqua condition and coverage check", primary: "Close" },
    aquaPickup: { title: "Aqua Pickup Checklist", subtitle: "Retrieve equipment and reconcile inventory", primary: "Close" },
    siteReady: { title: "Mark Site Ready", subtitle: "Confirm site is clear for crew to start", primary: "Mark Site Ready" },
    siteNotReady: { title: "Flag Site Not Ready", subtitle: "Block scheduling until site issue is resolved", primary: "Flag Not Ready" },
    quoteRequest: { title: "Request Quote — Scope Outside PO", subtitle: "Submit to CSM for pricing. FM cannot set or approve the quote amount.", primary: "Submit Quote Request" },
    warrantyJob: { title: "Create Warranty Job", subtitle: "Loving's responsibility — no charge to builder. Division Manager will be notified.", primary: "Create Warranty Job" }
  };

  const submit = async () => {
    const reason = form.reason || workspace.forms.rescheduleReasons?.[0] || '';
    const requestedDate = form.requestedDate || '';
    const notes = form.notes || '';
    const owner = form.owner || workspace.forms.returnOwners?.[0] || '';
    const instructions = form.instructions || '';
    const fjReason = form.reason || workspace.forms.fjReasons?.[0] || '';
    const scope = form.scope || '';
    const issueType = form.issueType || workspace.forms.aquaIssues?.[0] || '';
    const priority = form.priority || workspace.forms.aquaPriorities?.[0] || '';
    const tech = form.tech || job.aqua.tech || 'Unassigned';
    const inventory = form.inventory || '';
    const requestType = form.requestType || 'Scope Outside PO';
    const scopeDescription = form.scopeDescription || '';
    const fmNotes = form.fmNotes || '';
    const warrantyScope = form.warrantyScope || '';

    if (keyName === "qi") {
      const result = submitQiPass(workspace, job.id, undefined, notes);
      onCommit(result, (api) => api.submitQI(job.id, {}, notes));
    } else if (keyName === "fj") {
      const result = createFinishedJob(workspace, job.id, fjReason, scope);
      onCommit(result, (api) => api.createFinishJob(job.id, fjReason, scope));
    } else if (keyName === "return") {
      const returnReason = form.reason || workspace.forms.returnReasons?.[0] || '';
      const result = returnWork(workspace, job.id, owner, returnReason, instructions);
      onCommit(result, (api) => api.returnWork(job.id, owner, returnReason, instructions));
    } else if (keyName === "reschedule") {
      const result = requestReschedule(workspace, job.id, reason, requestedDate, notes);
      onCommit(result, (api) => api.requestReschedule(job.id, reason, requestedDate, notes));
    } else if (keyName === "aquaRepair") {
      const result = dispatchAquaRepair(workspace, job.id, issueType, priority, tech, inventory, notes);
      onCommit(result, (api) => api.dispatchAquaRepair(job.id, issueType, priority, tech, inventory, notes));
    } else if (keyName === "photos") {
      onCommit(acceptPhotoPackage(workspace, job.id), (api) => api.acceptPhotoPackage(job.id));
    } else if (keyName === "photoUpload") {
      const photo: PhotoProof = { category: form.category || "Additional Proof", caption: form.caption || "Uploaded by FM", status: "complete", uri: form.uri || undefined };
      onCommit(uploadPhoto(workspace, job.id, photo));
    } else if (keyName === "siteReady") {
      const result = markSiteReady(workspace, job.id, notes);
      onCommit(result, (api) => api.markSiteReady(job.id, notes));
    } else if (keyName === "siteNotReady") {
      const siteReason = form.reason || '';
      const result = flagSiteNotReady(workspace, job.id, siteReason, notes);
      if (result.ok) onCommit(result, (api) => api.flagSiteNotReady(job.id, siteReason, notes));
      else { onCommit(result); return; }
    } else if (keyName === "quoteRequest") {
      const photosCount = job.photos.filter(p => p.status === "complete").length;
      const lotNum = job.takeoff.fields.find(f => f.label === "PO Number")?.value ?? '';
      const result = createQuoteRequest(workspace, job.id, requestType, scopeDescription, fmNotes);
      if (result.ok) onCommit(result, (api) => api.createQuoteRequest(job.id, requestType, scopeDescription, lotNum, '', fmNotes, photosCount));
      else { onCommit(result); return; }
    } else if (keyName === "warrantyJob") {
      const result = createWarrantyJob(workspace, job.id, warrantyScope, notes);
      const lotNum = job.takeoff.fields.find(f => f.label === "PO Number")?.value ?? job.queueTitle;
      if (result.ok) onCommit(result, (api) => api.createWarrantyJob(job.id, warrantyScope, notes, lotNum));
      else { onCommit(result); return; }
    } else {
      onClose();
      return;
    }
    onClose();
  };

  const useCamera = async () => {
    const photo = await captureFieldPhoto(form.category || "Mobile Proof");
    onCommit(uploadPhoto(workspace, job.id, photo));
    onClose();
  };

  const renderBody = () => {
    if (keyName === "takeoff") return <><div className="split-3"><FieldBlocks fields={job.takeoff.fields} /></div><br /><div className="alert green"><div>✓</div><div><strong>Result:</strong> This takeoff state is loaded from the selected job record and will update once wired to Salesforce.</div></div></>;
    if (keyName === "schedule") return <><div className="split-3"><FieldBlocks fields={[{ label: "Service Appointment", value: job.workOrder.serviceAppointment }, { label: "Work Type", value: job.title.split("|")[1]?.trim() ?? "Production Install" }, { label: "Assigned Crew", value: job.workOrder.assignedResource }, { label: "Scheduled Date", value: job.workOrder.scheduledDate }, { label: "Territory", value: job.workOrder.territory }, { label: "Route Stop", value: job.workOrder.routeSequence }]} /></div><br /><div className="alert aqua"><div>ⓘ</div><div>Field Service owns scheduling, route sequence, crew/resource assignment, and mobile visibility. The FM reviews operational readiness, but the scheduler owns dispatch changes.</div></div></>;
    if (keyName === "photos") return <div className="checklist">{job.photos.filter(p => p.status !== "add").map(photo => <div className={classNames("check-item", photo.status === "complete" && "done")} key={photo.category}><div className="check-box"></div><div><div className="check-title">{photo.category}</div><div className="check-note">{photo.caption}</div></div><Pill tone={photo.status === "complete" ? "green" : "amber"}>{photo.status === "complete" ? "OK" : "Review"}</Pill></div>)}</div>;
    if (keyName === "qi") return <><div className="field-grid"><div className="field"><label>Overall Score</label><input value={job.qi.overallScore ?? "Auto from categories"} readOnly /></div><div className="field"><label>Outcome</label><select value={job.qi.status} onChange={(e) => set("outcome", e.target.value)}><option>Pass</option><option>Return to Foreman</option><option>Create Finished Job</option></select></div><div className="field full"><label>FM Notes</label><textarea value={form.notes ?? "Scope complete. Photos acceptable. Aqua install verified. Minor cleanup note addressed by foreman before departure."} onChange={(e) => set("notes", e.target.value)} /></div></div><br /><div className="alert amber"><div>!</div><div>If score is below threshold or scope is incomplete, closeout stays blocked and the FM should create a Finished Job.</div></div></>;
    if (keyName === "fj") return <div className="field-grid"><div className="field"><label>Parent WorkOrder</label><div>{job.workOrder.number}</div></div><div className="field"><label>Billing Type</label><div>No Charge</div></div><div className="field"><label>Reason</label><select value={form.reason ?? workspace.forms.fjReasons[0]} onChange={(e) => set("reason", e.target.value)}>{workspace.forms.fjReasons.map(x => <option key={x}>{x}</option>)}</select></div><div className="field"><label>Schedule Need</label><select value={form.scheduleNeed ?? "Return tomorrow"} onChange={(e) => set("scheduleNeed", e.target.value)}><option>Return tomorrow</option><option>Schedule this week</option><option>Hold for FM review</option></select></div><div className="field full"><label>Scope to Complete</label><textarea value={form.scope ?? ""} onChange={(e) => set("scope", e.target.value)} placeholder="Describe the missing work that must be returned to complete." /></div></div>;
    if (keyName === "return") return <div className="field-grid"><div className="field"><label>Return Reason</label><select value={form.reason ?? workspace.forms.returnReasons[0]} onChange={(e) => set("reason", e.target.value)}>{workspace.forms.returnReasons.map(x => <option key={x}>{x}</option>)}</select></div><div className="field"><label>Send To</label><select value={form.owner ?? workspace.forms.returnOwners[0]} onChange={(e) => set("owner", e.target.value)}>{workspace.forms.returnOwners.map(x => <option key={x}>{x}</option>)}</select></div><div className="field full"><label>Instructions</label><textarea value={form.instructions ?? ""} onChange={(e) => set("instructions", e.target.value)} placeholder="Enter clear return instructions. This becomes the field-facing note." /></div></div>;
    if (keyName === "reschedule") return <div className="field-grid"><div className="field"><label>Reason</label><select value={form.reason ?? workspace.forms.rescheduleReasons[0]} onChange={(e) => set("reason", e.target.value)}>{workspace.forms.rescheduleReasons.map(x => <option key={x}>{x}</option>)}</select></div><div className="field"><label>Requested Date</label><input type="date" value={form.requestedDate ?? "2026-05-15"} onChange={(e) => set("requestedDate", e.target.value)} /></div><div className="field full"><label>FM Notes</label><textarea value={form.notes ?? ""} onChange={(e) => set("notes", e.target.value)} placeholder="Explain the reason for reschedule and what must be true before the job is released again." /></div></div>;
    if (keyName === "aquaRepair") return <div className="field-grid"><div className="field"><label>Issue Type</label><select value={form.issueType ?? workspace.forms.aquaIssues[0]} onChange={(e) => set("issueType", e.target.value)}>{workspace.forms.aquaIssues.map(x => <option key={x}>{x}</option>)}</select></div><div className="field"><label>Priority</label><select value={form.priority ?? workspace.forms.aquaPriorities[0]} onChange={(e) => set("priority", e.target.value)}>{workspace.forms.aquaPriorities.map(x => <option key={x}>{x}</option>)}</select></div><div className="field"><label>Assigned Tech</label><input value={form.tech ?? job.aqua.tech} onChange={(e) => set("tech", e.target.value)} /></div><div className="field"><label>Inventory Needed</label><input value={form.inventory ?? "2 heads, 4 flags"} onChange={(e) => set("inventory", e.target.value)} /></div><div className="field full"><label>Dispatch Notes</label><textarea value={form.notes ?? "Dry spot on front left turf. Verify coverage and replace head if needed."} onChange={(e) => set("notes", e.target.value)} /></div></div>;
    if (keyName === "photoUpload") return <><div className="field-grid"><div className="field"><label>Photo Category</label><input value={form.category ?? "After"} onChange={(e) => set("category", e.target.value)} /></div><div className="field"><label>Photo URI</label><input value={form.uri ?? ""} onChange={(e) => set("uri", e.target.value)} placeholder="Data URL or Salesforce ContentDocument URL" /></div><div className="field full"><label>Caption</label><textarea value={form.caption ?? ""} onChange={(e) => set("caption", e.target.value)} placeholder="Describe what this proves." /></div></div><br /><button className="button" onClick={useCamera}>Use Mobile Camera</button></>;
    if (keyName === "siteReadiness") return <InteractiveChecklist items={job.takeoff.siteReadiness ?? []} onToggle={(id) => onCommit(completeChecklistItem(workspace, job.id, "siteReadiness", id))} />;
    if (keyName === "healthCheck") return <HealthCheckPanel job={job} onOpenModal={() => null} />;
    if (keyName === "aquaCheck") return <InteractiveChecklist items={job.aqua.checkChecklist ?? []} onToggle={(id) => onCommit(completeChecklistItem(workspace, job.id, "aquaCheck", id))} />;
    if (keyName === "aquaPickup") return <InteractiveChecklist items={job.aqua.pickupChecklist ?? []} onToggle={(id) => onCommit(completeChecklistItem(workspace, job.id, "aquaPickup", id))} />;
    if (keyName === "siteVisit") return <div className="checklist">{(job.takeoff.siteVisits ?? []).map(visit => <div className="check-item" key={visit.id}><div className="dot blue">?</div><div><div className="check-title">{visit.purpose}: {visit.decision}</div><div className="check-note">{visit.notes}</div></div><Pill tone={visit.status === "Complete" ? "green" : "blue"}>{visit.status}</Pill></div>)}</div>;
    if (keyName === "jsonExport") return <textarea value={exportWorkspace(workspace)} readOnly style={{ minHeight: 360, fontFamily: "monospace" }} />;
    if (keyName === "siteReady") return <div className="field-grid"><div className="field full"><label>Confirmation Notes</label><textarea value={form.notes ?? ""} onChange={(e) => set("notes", e.target.value)} placeholder="Confirm site conditions are clear: grading complete, access clear, utilities marked, no builder conflicts." /></div><div className="alert green"><div>✓</div><div>Marking site ready will create a Site_Readiness__c record in Salesforce and update the WorkOrder. Scheduling Manager will be notified that this lot can be dispatched.</div></div></div>;
    if (keyName === "siteNotReady") return <div className="field-grid"><div className="field full"><label>Reason (required)</label><input value={form.reason ?? ""} onChange={(e) => set("reason", e.target.value)} placeholder="e.g. Grading not complete, utilities not marked, builder blocking access" /></div><div className="field full"><label>Additional Notes</label><textarea value={form.notes ?? ""} onChange={(e) => set("notes", e.target.value)} placeholder="Describe what needs to happen before this lot can be dispatched." /></div><div className="alert red"><div>!</div><div>Flagging site not ready will block scheduling and notify Scheduling Manager and Builder Regional. The site readiness record will be created in Salesforce.</div></div></div>;
    if (keyName === "quoteRequest") return <div className="field-grid"><div className="field"><label>Request Type</label><select value={form.requestType ?? "Scope Outside PO"} onChange={(e) => set("requestType", e.target.value)}><option>Scope Outside PO</option><option>Change Order</option><option>Warranty Proposal</option><option>Aqua Addition</option></select></div><div className="field full"><label>Scope Description (required)</label><textarea value={form.scopeDescription ?? ""} onChange={(e) => set("scopeDescription", e.target.value)} placeholder="Describe the scope of work that falls outside the original PO. Be specific — the CSM prices from this description." /></div><div className="field full"><label>FM Notes</label><textarea value={form.fmNotes ?? ""} onChange={(e) => set("fmNotes", e.target.value)} placeholder="Any additional context for the CSM." /></div><div className="alert red"><div>!</div><div><strong>Guardrail:</strong> FM cannot set or approve the quote amount. This request goes to CSM for pricing. You will be notified when a decision is made.</div></div></div>;
    if (keyName === "warrantyJob") return <div className="field-grid"><div className="field full"><label>Warranty Scope (required)</label><textarea value={form.warrantyScope ?? ""} onChange={(e) => set("warrantyScope", e.target.value)} placeholder="Describe the defect that is Loving's installation responsibility. Be specific — what failed, when, and why it is not builder or homeowner damage." /></div><div className="field full"><label>Notes for Division Manager</label><textarea value={form.notes ?? ""} onChange={(e) => set("notes", e.target.value)} placeholder="Include any site conditions, photo context, or timeline details." /></div><div className="alert amber"><div>!</div><div>A Warranty WorkOrder will be created in Salesforce as a child of this WorkOrder. Work_Order_Type__c will be set to Warranty. Division Manager will be notified. This does NOT block the original invoice.</div></div><div className="alert red"><div>!</div><div><strong>Requires 2 accepted photos minimum.</strong> Attach photo proof before submitting.</div></div></div>;
  };

  const meta = modalMeta[keyName];
  return (
    <div className="modal-backdrop show" id="modalBackdrop" onClick={closeOnBackdrop}>
      <div className="modal" onClick={(event) => event.stopPropagation()}>
        <div className="modal-header"><div><h2>{meta.title}</h2><div className="card-subtitle">{meta.subtitle}</div></div><MiniButton onClick={onClose}>Close</MiniButton></div>
        <div className="modal-body">{renderBody()}</div>
        <div className="modal-footer"><button className="button" onClick={onClose}>Cancel</button><button className="button primary" onClick={submit}>{meta.primary}</button></div>
      </div>
    </div>
  );
}

export default function App() {
  const startup = useMemo(() => resolveStartupMode(), []);
  const [appMode, setAppMode] = useState<AppMode>(startup.mode);
  const [sfSession, setSfSession] = useState<SalesforceSession | null>(startup.session);
  const [sfApi, setSfApi] = useState<SalesforceFieldManagerApi | null>(
    startup.session ? new SalesforceFieldManagerApi(startup.session) : null
  );
  const [loadingMessage, setLoadingMessage] = useState('Loading workspace...');
  const [workspace, setWorkspace] = useState<FieldManagerWorkspace>(() => loadWorkspace());
  const [activeTab, setActiveTab] = useState<TabId>("command");
  const [modalKey, setModalKey] = useState<ModalKey | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const job = useMemo(() => workspace.jobs.find((item) => item.id === workspace.selectedJobId) ?? workspace.jobs[0], [workspace]);

  const showToast = (message: string, duration = 4200) => {
    setToast(message);
    window.setTimeout(() => setToast(null), duration);
  };

  // Handle OAuth callback (URL has ?code=)
  useEffect(() => {
    if (startup.oauthCode) {
      setLoadingMessage('Completing Salesforce login...');
      handleOAuthCallback(startup.oauthCode)
        .then((session) => {
          window.history.replaceState({}, '', window.location.pathname);
          const api = new SalesforceFieldManagerApi(session);
          setSfSession(session);
          setSfApi(api);
          setAppMode('loading');
          setLoadingMessage('Loading your live work queue from Salesforce...');
          return loadLiveWorkspace(api);
        })
        .then((liveWorkspace) => {
          setWorkspace(liveWorkspace);
          setAppMode('live');
        })
        .catch((err: unknown) => {
          showToast(`Login failed: ${err instanceof Error ? err.message : String(err)}`, 8000);
          setAppMode('login');
        });
    }
  }, [startup.oauthCode]);

  // Load live workspace when session is known at startup
  useEffect(() => {
    if (appMode === 'live' && sfApi && !startup.oauthCode) {
      setLoadingMessage('Loading your live work queue from Salesforce...');
      loadLiveWorkspace(sfApi)
        .then((liveWorkspace) => {
          setWorkspace(liveWorkspace);
          sfApi.getUserDisplayName().then((name) => {
            setWorkspace(prev => ({ ...prev, currentUser: { ...prev.currentUser, name } }));
          }).catch(() => null);
        })
        .catch((err: unknown) => {
          showToast(`Salesforce load failed: ${err instanceof Error ? err.message : String(err)}. Showing last cached state.`, 8000);
        });
    }
  }, [appMode, sfApi, startup.oauthCode]);

  const signOut = () => {
    clearSession();
    setSfSession(null);
    setSfApi(null);
    setWorkspace(loadWorkspace());
    setAppMode('login');
  };

  // Domain action commit: apply locally instantly, also write to Salesforce if live
  const commit = (result: ActionResult, sfWrite?: (api: SalesforceFieldManagerApi) => Promise<unknown>) => {
    if (result.ok) {
      setWorkspace(result.workspace);
      if (appMode === 'demo') saveWorkspace(result.workspace);
      if (appMode === 'live' && sfApi && sfWrite) {
        commitLiveAction(sfApi, sfWrite).then((sfResult) => {
          if (!sfResult.ok) {
            showToast(`Salesforce write failed: ${sfResult.error}`, 8000);
          } else if (sfResult.sfId) {
            showToast(`${result.message} · Salesforce ID: ${sfResult.sfId}`);
          }
        });
      }
    }
    showToast(result.message);
  };

  if (appMode === 'loading' || startup.oauthCode) {
    return <LoadingScreen message={loadingMessage} />;
  }
  if (appMode === 'login') {
    return <LoginScreen onLogin={() => startOAuthFlow().catch((e: unknown) => showToast(String(e)))} onDemo={() => { setWorkspace(loadWorkspace()); setAppMode('demo'); }} />;
  }

  const currentMode = appMode as 'live' | 'demo';
  const userName = workspace.currentUser.name;

  return (
    <>
      <Topbar userName={userName} mode={currentMode} onSignOut={appMode === 'live' ? signOut : undefined} />
      <div className="shell">
        <Sidebar workspace={workspace} selectedJob={job ?? workspace.jobs[0]} onSelect={(id) => commit(selectJob(workspace, id))} />
        <main className="main">
          {!job ? (
            <div className="alert aqua" style={{ margin: 18 }}>
              <div>ⓘ</div>
              <div>
                {appMode === 'live'
                  ? <><strong>No active WorkOrders found.</strong> The FM app queries WorkOrders where <code>FM__c = {sfSession?.userId ?? 'your user ID'}</code> and Status is not Closed/Invoiced/Cancelled. Assign yourself as FM on one or more WorkOrders in Salesforce to populate this queue.</>
                  : <><strong>No jobs in demo workspace.</strong> <button className="mini-button" onClick={() => { setWorkspace(loadWorkspace()); }}>Reload seed data</button></>
                }
              </div>
            </div>
          ) : (
            <>
              <RecordHeader job={job} onOpenModal={setModalKey} onAdvance={() => commit(advanceStage(workspace, job.id))} />
              <KpiGrid job={job} />
              <section className="tabs">
                <div className="tab-bar">
                  {tabOrder.map((tab) => <div className={classNames("tab", activeTab === tab.id && "active")} onClick={() => setActiveTab(tab.id)} key={tab.id}>{tab.label}</div>)}
                </div>
                {activeTab === "command" && <CommandTab workspace={workspace} job={job} onOpenModal={setModalKey} onSwitchTab={setActiveTab} onApproveCloseout={() => commit(approveCloseout(workspace, job.id), sfApi ? (api) => api.approveCloseout(job.id, '') : undefined)} />}
                {activeTab === "takeoffTab" && <TakeoffTab job={job} onOpenModal={setModalKey} onUpdateVerified={(lineId, value) => commit(updateTakeoffVerifiedAmount(workspace, job.id, lineId, value))} onValidateTakeoff={() => commit(validateTakeoff(workspace, job.id), sfApi ? (api) => api.validateTakeoff(job.id) : undefined)} onToggleChecklist={(area, itemId) => commit(completeChecklistItem(workspace, job.id, area, itemId))} />}
                {activeTab === "workTab" && <WorkTab job={job} onOpenModal={setModalKey} />}
                {activeTab === "aquaTab" && <AquaTab job={job} onOpenModal={setModalKey} onToggleChecklist={(area, itemId) => commit(completeChecklistItem(workspace, job.id, area, itemId))} />}
                {activeTab === "photosTab" && <PhotosTab job={job} onOpenModal={setModalKey} onAccept={() => commit(acceptPhotoPackage(workspace, job.id), sfApi ? (api) => api.acceptPhotoPackage(job.id) : undefined)} />}
                {activeTab === "qiTab" && <QiTab job={job} onOpenModal={setModalKey} onSubmitQi={() => setModalKey("qi")} onApproveCloseout={() => commit(approveCloseout(workspace, job.id), sfApi ? (api) => api.approveCloseout(job.id, '') : undefined)} />}
                {activeTab === "mobileTab" && <MobileTab job={job} onOpenModal={setModalKey} onSwitchTab={setActiveTab} />}
              </section>
            </>
          )}
          <div style={{ marginTop: 12, display: "flex", gap: 8, flexWrap: "wrap" }}>
            <button className="mini-button" onClick={() => setModalKey("jsonExport")}>Export Current Data</button>
            {appMode === 'demo' && <button className="mini-button" onClick={() => { const fresh = resetWorkspace(); setWorkspace(fresh); showToast("Workspace reset to seed data."); }}>Reset Seed Data</button>}
            {appMode === 'live' && sfApi && <button className="mini-button" onClick={() => { setLoadingMessage('Refreshing from Salesforce...'); loadLiveWorkspace(sfApi).then(setWorkspace).catch((err: unknown) => showToast(String(err))); }}>↻ Refresh from Salesforce</button>}
          </div>
        </main>
      </div>
      <Modal keyName={modalKey} workspace={workspace} job={job ?? workspace.jobs[0]} onClose={() => setModalKey(null)} onCommit={(result, sfWrite) => commit(result, sfApi ? sfWrite : undefined)} />
      <Toast message={toast} />
    </>
  );
}
