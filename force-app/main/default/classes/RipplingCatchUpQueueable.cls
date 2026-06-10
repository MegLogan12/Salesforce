/**
 * RipplingCatchUpQueueable
 * Fast-forwards the Rippling time-entry cursor to current data by calling the sync
 * repeatedly and CHAINING immediately (no 7-minute batch wait). Each run advances the
 * cursor (callouts only for old pages; upserts only recent entries). Stops chaining when:
 *   - data has caught up to within 3 days of today, OR
 *   - the cursor stops advancing (reached the end / rate-limited), OR
 *   - a safety iteration cap is hit.
 * One-time backfill helper; the 7-minute RipplingTimeEntryBatcher keeps it current after.
 */
public with sharing class RipplingCatchUpQueueable implements Queueable, Database.AllowsCallouts {
    private Integer iterations;
    public RipplingCatchUpQueueable() { this.iterations = 0; }
    public RipplingCatchUpQueueable(Integer i) { this.iterations = i; }

    public void execute(QueueableContext ctx) {
        // Self-chaining intentionally disabled. Forward cursor pagination cannot practically catch
        // up to current Rippling data (oldest-first API, no working filters, Apex callout limits).
        // The 7-minute RipplingTimeEntryBatcher still advances the cursor incrementally, and the
        // real fix is a Rippling recent-entries filter or webhook. No-op so any leftover chain dies.
        if (iterations < 0) { return; } // reference the field; no behavior
    }
}