#!/usr/bin/env bash
# LOVING SF — Org Authentication Helper
# Run this script on your local machine (browser required)

set -euo pipefail

echo "=== LOVING SF — Salesforce Authentication ==="
echo ""

if ! command -v sf &>/dev/null; then
  echo "ERROR: Salesforce CLI not found."
  echo "Install with: npm install -g @salesforce/cli"
  echo "Then re-run this script."
  exit 1
fi

echo "Choose environment:"
echo "  1) Production  (login.salesforce.com)"
echo "  2) Sandbox     (test.salesforce.com)"
read -rp "Enter 1 or 2: " choice

case "$choice" in
  1)
    echo ""
    echo "Opening browser for PRODUCTION login..."
    sf auth web login \
      --instance-url https://login.salesforce.com \
      --alias loving-prod
    echo ""
    echo "Authenticated as: $(sf org display --target-org loving-prod --json | python3 -c 'import sys,json; d=json.load(sys.stdin)["result"]; print(d.get("username","unknown"))')"
    echo "Alias 'loving-prod' is ready. Run: ./deploy.sh loving-prod"
    ;;
  2)
    echo ""
    echo "Opening browser for SANDBOX login..."
    sf auth web login \
      --instance-url https://test.salesforce.com \
      --alias loving-sandbox
    echo ""
    echo "Authenticated as: $(sf org display --target-org loving-sandbox --json | python3 -c 'import sys,json; d=json.load(sys.stdin)["result"]; print(d.get("username","unknown"))')"
    echo "Alias 'loving-sandbox' is ready. Run: ./deploy.sh loving-prod loving-sandbox"
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
