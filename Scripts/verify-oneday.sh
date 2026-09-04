#!/usr/bin/env bash
# verify-oneday.sh — structure checks that run without Xcode.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
require() {
  if [[ ! -e "$1" ]]; then
    echo "MISSING: $1" >&2
    fail=1
  else
    echo "ok  $1"
  fi
}

echo "== OneDay scaffold =="
require "OneDay.xcodeproj/project.pbxproj"
require "OneDay/App/OneDayApp.swift"
require "OneDay/Features/Home/FeedView.swift"
require "OneDay/Features/Home/FeedViewModel.swift"
require "OneDay/Features/Home/FeedPost.swift"
require "OneDay/Features/Home/AISummaryPlaceholder.swift"
require "OneDay/Features/Composer/ComposerView.swift"
require "OneDay/Features/Composer/ComposerViewModel.swift"
require "OneDay/Features/Profile/ProfileView.swift"
require "OneDay/Features/Settings/SettingsView.swift"
require "OneDay/Core/OneDay/DailyPostLock.swift"
require "OneDay/Core/OneDay/FollowingCaps.swift"
require "convex/schema.ts"
require "convex/posts.ts"
require "convex/following.ts"
require "Config/Base.xcconfig"
require "README.md"

echo
echo "== Feature flags =="
if rg -q 'FEATURE_PAYWALL|FEATURE_BILLING|FEATURE_PUSH|FEATURE_FEATUREBASE|FEATURE_LOTTIE' Config/Base.xcconfig; then
  echo "UNEXPECTED: cut modules still in FEATURE_FLAGS" >&2
  fail=1
else
  echo "ok  cut modules absent from FEATURE_FLAGS"
fi

if rg -q 'FEATURE_HOME FEATURE_PROFILE FEATURE_SETTINGS' Config/Base.xcconfig; then
  echo "ok  core tabs present"
else
  echo "MISSING core tab flags" >&2
  fail=1
fi

echo
echo "== Cut modules gone =="
for path in OneDay/Features/Paywall OneDay/Features/Billing OneDay/Services/OneSignal \
  OneDay/Services/FeatureBase OneDay/Services/Lottie convex/demoItems.ts convex/stripe.ts; do
  if [[ -e "$path" ]]; then
    echo "UNEXPECTED present: $path" >&2
    fail=1
  else
    echo "ok  removed $path"
  fi
done

if [[ $fail -ne 0 ]]; then
  echo
  echo "verify-oneday: FAILED" >&2
  exit 1
fi

echo
echo "verify-oneday: PASSED"
echo "Full iOS compile requires Xcode 26+ on macOS:"
echo "  xcodebuild -project OneDay.xcodeproj -scheme OneDay \\"
echo "    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build"
