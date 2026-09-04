---
name: rename-app
description: Rename the template into a new app — display name, bundle identifier, Xcode target, scheme, source folder and @main struct. Use when the user says "rename this to X", "make this my app", or is starting a new project from the kit.
---

# Rename the app

## Do this

```bash
./Scripts/rename.sh --name "Trail Notes" --bundle-id com.acme.trailnotes --yes
```

The script:

1. Rewrites `APP_DISPLAY_NAME` and `APP_BUNDLE_ID` in `Config/Base.xcconfig`.
2. Renames `SwiftUITemplate/` → `TrailNotes/`, `SwiftUITemplate.xcodeproj` →
   `TrailNotes.xcodeproj`, the scheme, the entitlements file and
   `SwiftUITemplateApp.swift` → `TrailNotesApp.swift`.
3. Rewrites the target name inside `project.pbxproj`, the scheme and the
   xcconfig.

Add `--keep-target` to change only the display name and bundle id — useful when
the user just wants a different name on the icon.

Pass `--target-name` when the display name doesn't reduce to a valid Swift
identifier (e.g. `--name "99 Problems" --target-name NinetyNineProblems`).

## Then verify

```bash
xcodebuild -project <NewName>.xcodeproj -scheme <NewName> \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## What the script deliberately leaves alone

- `docs/`, `AGENTS.md`, `.cursor/rules/` still say "SwiftUI Template". They
  document the kit, not the app. Only rewrite them if the user asks.
- The app icon at `<NewName>/Resources/Assets.xcassets/AppIcon.appiconset/` is
  still the placeholder.
- `Config/Secrets.xcconfig` — tell the user to create it from
  `Secrets.example.xcconfig` (see the `wire-secrets` skill).

## Gotchas

- Run on a clean git tree; the script edits in place and makes no commit.
- The bundle id must be registered in the user's Apple Developer account, with
  **Sign in with Apple** and **Push Notifications** capabilities enabled, before
  a device build will sign.
- Never hand-edit `project.pbxproj` to do this yourself — the project uses
  synchronized folders and the script's targeted replacements are the safe path.
