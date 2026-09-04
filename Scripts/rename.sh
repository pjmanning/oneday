#!/usr/bin/env bash
#
# rename.sh — turn this template into your app.
#
#   ./Scripts/rename.sh --name "Trail Notes" --bundle-id com.acme.trailnotes
#
# By default it renames everything: display name, bundle identifier, the Xcode
# project, the target, the scheme, the source folder and the @main struct.
# Pass --keep-target to change only the display name and bundle id, leaving the
# project called SwiftUITemplate.
#
# Run it on a clean tree — it edits files in place and does not create a commit.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OLD_TARGET="SwiftUITemplate"

DISPLAY_NAME=""
BUNDLE_ID=""
TARGET_NAME=""
KEEP_TARGET=0
ASSUME_YES=0

usage() {
  cat <<'USAGE'
Usage: ./Scripts/rename.sh --name "My App" --bundle-id com.example.myapp [options]

Required:
  --name <string>         Display name shown under the icon.
  --bundle-id <string>    Reverse-DNS bundle identifier.

Optional:
  --target-name <string>  Xcode target/scheme/folder name.
                          Defaults to the display name with spaces removed.
  --keep-target           Only change display name and bundle id.
  --yes                   Skip the confirmation prompt.
  -h, --help              Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)        DISPLAY_NAME="${2:-}"; shift 2 ;;
    --bundle-id)   BUNDLE_ID="${2:-}"; shift 2 ;;
    --target-name) TARGET_NAME="${2:-}"; shift 2 ;;
    --keep-target) KEEP_TARGET=1; shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DISPLAY_NAME" || -z "$BUNDLE_ID" ]]; then
  echo "error: --name and --bundle-id are both required." >&2
  usage
  exit 1
fi

if [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]; then
  echo "error: '$BUNDLE_ID' is not a valid bundle identifier (expected something like com.acme.myapp)." >&2
  exit 1
fi

if [[ $KEEP_TARGET -eq 0 ]]; then
  if [[ -z "$TARGET_NAME" ]]; then
    # "Trail Notes" -> "TrailNotes"
    TARGET_NAME="$(printf '%s' "$DISPLAY_NAME" | tr -cd '[:alnum:]')"
  fi
  if [[ ! "$TARGET_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
    echo "error: target name '$TARGET_NAME' must start with a letter and contain only letters and digits." >&2
    echo "       Pass --target-name explicitly." >&2
    exit 1
  fi
else
  TARGET_NAME="$OLD_TARGET"
fi

echo "About to rename this template:"
echo "  Display name : $DISPLAY_NAME"
echo "  Bundle id    : $BUNDLE_ID"
if [[ "$TARGET_NAME" != "$OLD_TARGET" ]]; then
  echo "  Target/scheme: $OLD_TARGET -> $TARGET_NAME"
  echo "  Source folder: $OLD_TARGET/ -> $TARGET_NAME/"
else
  echo "  Target/scheme: unchanged ($OLD_TARGET)"
fi
echo

if [[ $ASSUME_YES -eq 0 ]]; then
  read -r -p "Continue? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# --- 1. Identity in the one xcconfig that owns it ---------------------------

# Use a bash function rather than `sed -i` so this behaves the same on BSD and
# GNU sed (macOS ships BSD sed, CI often runs GNU).
replace_in_file() {
  local pattern="$1" replacement="$2" file="$3"
  local tmp
  tmp="$(mktemp)"
  sed "s|${pattern}|${replacement}|g" "$file" > "$tmp"
  mv "$tmp" "$file"
}

replace_in_file "^APP_DISPLAY_NAME = .*" "APP_DISPLAY_NAME = ${DISPLAY_NAME}" Config/Base.xcconfig
replace_in_file "^APP_BUNDLE_ID = .*"    "APP_BUNDLE_ID = ${BUNDLE_ID}"       Config/Base.xcconfig
echo "Updated Config/Base.xcconfig"

# --- 2. Target / scheme / folder rename -------------------------------------

if [[ "$TARGET_NAME" != "$OLD_TARGET" ]]; then
  # Prefer `git mv` so history follows the rename; fall back to plain mv when
  # the template has been copied out of git.
  move() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git mv "$1" "$2"
    else
      mv "$1" "$2"
    fi
  }

  move "$OLD_TARGET" "$TARGET_NAME"
  move "${OLD_TARGET}.xcodeproj" "${TARGET_NAME}.xcodeproj"
  move "Config/${OLD_TARGET}.entitlements" "Config/${TARGET_NAME}.entitlements"
  move "${TARGET_NAME}.xcodeproj/xcshareddata/xcschemes/${OLD_TARGET}.xcscheme" \
       "${TARGET_NAME}.xcodeproj/xcshareddata/xcschemes/${TARGET_NAME}.xcscheme"
  move "${TARGET_NAME}/App/${OLD_TARGET}App.swift" "${TARGET_NAME}/App/${TARGET_NAME}App.swift"

  # Only project machinery gets the blanket rename — docs keep referring to the
  # kit they came from, which is what you want when you go looking for help.
  for file in \
    "${TARGET_NAME}.xcodeproj/project.pbxproj" \
    "${TARGET_NAME}.xcodeproj/xcshareddata/xcschemes/${TARGET_NAME}.xcscheme" \
    "Config/Base.xcconfig" \
    "${TARGET_NAME}/App/${TARGET_NAME}App.swift"
  do
    replace_in_file "$OLD_TARGET" "$TARGET_NAME" "$file"
  done

  echo "Renamed target, scheme, project and source folder to ${TARGET_NAME}"
fi

# --- 3. What's left for a human ---------------------------------------------

cat <<NEXT

Done.

Next:
  1. cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig  (gitignored)
     and fill in your keys — see docs/SETUP.md.
  2. Set DEVELOPMENT_TEAM in Config/Secrets.xcconfig to run on a device.
  3. Register ${BUNDLE_ID} in your Apple Developer account and enable
     Sign in with Apple + Push Notifications for it.
  4. open ${TARGET_NAME}.xcodeproj and press Cmd+R.

Not renamed on purpose:
  - docs/, AGENTS.md and .cursor/rules still describe "SwiftUI Template".
    They document the kit, not your app. Edit them when they start to lie.
  - The app icon is a placeholder: replace
    ${TARGET_NAME}/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
NEXT
