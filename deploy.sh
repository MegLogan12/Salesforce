#!/usr/bin/env bash
# LOVING SF — Production Deployment Script
# Run from the repo root after authenticating with: sf auth web login --alias loving-prod

set -euo pipefail

ORG_ALIAS="${1:-loving-prod}"
SANDBOX_ALIAS="${2:-loving-sandbox}"
TEST_CLASS="LOVING_WorkOrderTriggerHandlerTest"
SOURCE_DIR="force-app"

echo "=== LOVING SF Deployment ==="
echo "Target org alias: $ORG_ALIAS"
echo ""

# Check sf CLI
if ! command -v sf &>/dev/null; then
  echo "ERROR: Salesforce CLI not found."
  echo "Install: npm install -g @salesforce/cli"
  exit 1
fi

# Confirm org is authenticated
echo "--- Verifying org auth ---"
sf org display --target-org "$ORG_ALIAS" || {
  echo "ERROR: Org '$ORG_ALIAS' not authenticated."
  echo "Run: sf auth web login --alias $ORG_ALIAS"
  exit 1
}

# Step 1 — Validate (dry run)
echo ""
echo "--- Step 1: Validate (dry run) ---"
sf project deploy validate \
  --source-dir "$SOURCE_DIR" \
  --target-org "$ORG_ALIAS" \
  --test-level RunSpecifiedTests \
  --tests "$TEST_CLASS" \
  --wait 30

echo ""
read -rp "Validation passed. Deploy to production? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# Step 2 — Deploy
echo ""
echo "--- Step 2: Deploying to $ORG_ALIAS ---"
sf project deploy start \
  --source-dir "$SOURCE_DIR" \
  --target-org "$ORG_ALIAS" \
  --test-level RunSpecifiedTests \
  --tests "$TEST_CLASS" \
  --wait 30

echo ""
echo "--- Step 3: Running full test suite ---"
sf apex run test \
  --class-names "$TEST_CLASS" \
  --target-org "$ORG_ALIAS" \
  --result-format human \
  --wait 10

echo ""
echo "=== Deploy complete ==="
echo ""
echo "POST-DEPLOY CHECKLIST:"
echo "  [ ] Schedule Apex jobs via Developer Console (see README)"
echo "  [ ] Verify all 11 Flows are Active in Setup → Flows"
echo "  [ ] Configure FSL: Operating Hours, Territory, Work Types, Policy, Resources"
echo "  [ ] Confirm Celigo recipe targets WorkOrder.Invoice_Number__c"
