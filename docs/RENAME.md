# Renaming the template

## The script

```bash
./Scripts/rename.sh --name "Trail Notes" --bundle-id com.acme.trailnotes
```

Options:

| Flag | Effect |
|---|---|
| `--name` | Display name under the icon. Required. |
| `--bundle-id` | Reverse-DNS identifier. Required. |
| `--target-name` | Xcode target/scheme/folder name. Defaults to the display name with non-alphanumerics stripped. |
| `--keep-target` | Change only the display name and bundle id; leave the project called `SwiftUITemplate`. |
| `--yes` | Skip the confirmation prompt. |

Run it on a clean git tree — it edits in place and makes no commit.

## What it changes

1. `APP_DISPLAY_NAME` and `APP_BUNDLE_ID` in `Config/Base.xcconfig`. These are
   the only places identity is defined; `Info.plist` and the project both read
   them through `$(…)` substitution.
2. With a target rename (the default):
   - `SwiftUITemplate/` → `TrailNotes/`
   - `SwiftUITemplate.xcodeproj` → `TrailNotes.xcodeproj`
   - `Config/SwiftUITemplate.entitlements` → `Config/TrailNotes.entitlements`
   - the shared scheme
   - `App/SwiftUITemplateApp.swift` → `App/TrailNotesApp.swift`, including the
     `@main` struct name
   - the target name inside `project.pbxproj`

It uses `git mv` when inside a repository so history follows the rename.

## What it deliberately leaves alone

- **`docs/`, `AGENTS.md`, `.cursor/rules/`** still say "SwiftUI Template". They
  document the kit, and keeping the original name is what lets you match them
  against upstream when something changes. Edit them when they start to lie
  about your app.
- **The app icon** at
  `TrailNotes/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` is
  still the placeholder. Replace it with a 1024×1024 PNG, or use Icon Composer
  (Xcode 26) for a layered icon with the iOS 26 material treatments.
- **`Config/Secrets.xcconfig`** — create it from the example, see
  [SETUP.md](SETUP.md).
- **The Convex deployment** — `npx convex dev` creates one per project.

## Doing it by hand

If you'd rather not run the script:

1. Edit `APP_DISPLAY_NAME` and `APP_BUNDLE_ID` in `Config/Base.xcconfig`. That
   alone gives you a distinct app identity; everything below is cosmetic.
2. In Xcode, rename the target in the Project navigator (this rewrites the
   pbxproj safely), then rename the scheme in Product → Scheme → Manage Schemes.
3. Rename the `SwiftUITemplate/` folder on disk. The project uses synchronized
   folders, so update the folder reference's path in the File Inspector.
4. Rename `SwiftUITemplateApp.swift` and its `@main` struct.
5. Point `CODE_SIGN_ENTITLEMENTS` at the renamed entitlements file.

## Afterwards

- Register the bundle id in your Apple Developer account.
- Enable **Sign in with Apple** and **Push Notifications** for it.
- Set `DEVELOPMENT_TEAM` in `Config/Secrets.xcconfig` for device builds.
- Update the RevenueCat and OneSignal apps to the new bundle id.
- Build once for the simulator to confirm the rename took:

```bash
xcodebuild -project TrailNotes.xcodeproj -scheme TrailNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
