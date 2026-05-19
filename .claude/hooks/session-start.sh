#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Install Salesforce CLI if not already present
if ! command -v sf &>/dev/null; then
  npm install -g @salesforce/cli --prefer-offline 2>&1
fi
