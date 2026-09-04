#!/usr/bin/env bash
# cloud-agent-install.sh — idempotent Cloud Agent bootstrap for OneDay.
# Installs Convex toolchain deps and verifies the iOS scaffold structure.
# Full Xcode builds require macOS; this environment validates what Linux can.
set -euo pipefail

cd "$(dirname "$0")/.."

npm ci

chmod +x Scripts/verify-oneday.sh Scripts/rename.sh 2>/dev/null || true
./Scripts/verify-oneday.sh

# Anonymous Convex agent deployment so typecheck has _generated/
export CONVEX_AGENT_MODE=anonymous
if [[ ! -f .env.local ]]; then
  npx convex dev --once --typecheck=disable >/tmp/convex-dev-once.log 2>&1 || true
fi
# Ensure auth config env exists (placeholder is fine for structure checks)
npx convex env set CLERK_JWT_ISSUER_DOMAIN \
  "${CLERK_JWT_ISSUER_DOMAIN:-https://placeholder.clerk.accounts.dev}" \
  >/tmp/convex-env-set.log 2>&1 || true
npx convex dev --once --typecheck=disable >/tmp/convex-dev-once.log 2>&1

npm run typecheck

echo "cloud-agent-install: OK"
