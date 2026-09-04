---
name: verify-build
description: Build, run and verify the app — including the deletion-safety check that every feature module can be removed. Use after any change, and always before saying work is done.
---

# Verify the build

## Build

```bash
xcodebuild -project SwiftUITemplate.xcodeproj -scheme SwiftUITemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```

The first build resolves and compiles the SDKs and takes several minutes;
later ones are fast. A clean build must produce **zero warnings** in
`SwiftUITemplate/` — SDK warnings are not yours to fix.

If XcodeBuildMCP is available, use it instead — the output is easier to read.

## Run

```bash
xcrun simctl boot 'iPhone 17 Pro'
xcrun simctl bootstatus 'iPhone 17 Pro'          # wait; launching too early is denied
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/SwiftUITemplate-*/Build/Products/Debug-iphonesimulator/SwiftUITemplate.app
xcrun simctl launch booted com.swiftuitemplate.demo
xcrun simctl io booted screenshot /tmp/shot.png
```

Skip straight past onboarding — `UserDefaults` reads the argument domain, so
launch arguments override the router's persisted state:

```bash
xcrun simctl launch booted com.swiftuitemplate.demo -app.hasCompletedOnboarding YES -app.hasSeenPaywall YES
```

Watch the app's own logs:

```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.swiftuitemplate.demo"'
```

On a fresh clone every service logs one actionable line about its missing key.
That is correct behaviour, not a failure.

## Deletion safety — the check people forget

Every feature must survive removal. For a feature `X`:

1. Delete its token from `FEATURE_FLAGS` in `Config/Base.xcconfig`.
2. Delete `SwiftUITemplate/Features/X/`.
3. Build.
4. Restore both.

It must compile. If it doesn't, something referenced `X` without an
`#if FEATURE_X` guard — fix the reference, not the flag.

Keep at least one of `FEATURE_HOME` / `FEATURE_PROFILE` / `FEATURE_SETTINGS`;
`AppTab.initial` raises a `#error` explaining this if you remove all three.

## Convex

```bash
npx convex dev        # pushes functions, regenerates convex/_generated/
npm run typecheck
```

`npm run typecheck` fails before `convex dev` has ever run, because
`convex/_generated/` is gitignored and created by the CLI.

## Checklist before reporting done

- [ ] Builds with no warnings in `SwiftUITemplate/`
- [ ] Launches and reaches the expected screen
- [ ] Deletion safety holds for anything you touched
- [ ] No force-unwraps, no `print`, no SDK import outside `Services/`
- [ ] New interactive controls have `accessibilityIdentifier`s
- [ ] Checked light **and** dark appearance
