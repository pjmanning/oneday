# AGENTS.md — SwiftUI Template

Read this before changing anything. It is the contract between you and this
codebase; the rest of the docs are reference.

**What this is:** an iOS 26+ SwiftUI starter kit. Someone clones it, renames it,
pastes in API keys, and ships an App Store app. Every decision below exists to
keep that true.

**Turning it into a new app?** Start at [`docs/NEW_PROJECT.md`](docs/NEW_PROJECT.md)
— interview, rename, cut modules, model the schema — then come back here for the
rules.

---

## Layout

```
SwiftUITemplate.xcodeproj      Xcode 16+ synchronized folders — see "Adding files"
SwiftUITemplate/
  App/          @main, RootRouter, AppEnvironment, FeatureFlags, AppConfig
  Core/         DesignSystem, small extensions. No feature logic.
  Features/     One folder per screen area. Deletable.
  Services/     One folder per third-party SDK. The only place SDKs are imported.
  Resources/    Assets.xcassets, PrivacyInfo.xcprivacy
Config/         Base.xcconfig, Secrets.xcconfig (gitignored), Info.plist, entitlements
convex/         TypeScript backend (schema, auth config, queries, Stripe actions)
Scripts/        rename.sh
docs/           SETUP, ARCHITECTURE, RENAME, PACKAGES
skills/         Task recipes for agents
.cursor/rules/  Style rules loaded automatically by Cursor
```

## The five rules

1. **Features never import each other.** A feature depends on `Core/`,
   `Services/` and `App/` only. The single exception: a feature may embed
   another feature's entry view inside `#if FEATURE_OTHER`, one line, nothing
   more. `ProfileView` embedding `BillingSummarySection` is the worked example.

2. **SDK imports live in `Services/` and nowhere else.** `Features/` code sees
   `AuthUser`, `BackendValue`, `PurchaseService.Product` — never `ClerkKit`,
   `ConvexMobile` or `RevenueCat`. Swapping a vendor should be one folder.

3. **Every feature is deletable.** Removing its `FEATURE_*` token from
   `Config/Base.xcconfig` must make the project compile with the folder gone.
   That is why cross-feature references are `#if`-guarded rather than
   flag-checked at runtime.

4. **Missing configuration degrades, never crashes.** No force-unwraps, no
   `fatalError` on a missing key. `AppConfig` returns `nil` for anything still
   set to `REPLACE_ME`; the service disables itself and the UI shows
   `SetupRequiredView` naming the exact setting.

5. **Navigation goes through `RootRouter`.** Screens report events; the router
   decides what is shown. No feature presents another feature's root.

## Feature flags

The real switch is `FEATURE_FLAGS` in `Config/Base.xcconfig`, which feeds
`SWIFT_ACTIVE_COMPILATION_CONDITIONS`:

```
FEATURE_FLAGS = FEATURE_ONBOARDING FEATURE_AUTH FEATURE_PAYWALL FEATURE_HOME \
                FEATURE_PROFILE FEATURE_SETTINGS FEATURE_BILLING \
                FEATURE_ANALYTICS FEATURE_ERROR_REPORTING FEATURE_PUSH \
                FEATURE_FEATUREBASE FEATURE_LOTTIE
```

`App/FeatureFlags.swift` mirrors these as booleans for runtime branching. To
remove a module: delete its token, delete its folder, build. Keep at least one
of `FEATURE_HOME` / `FEATURE_PROFILE` / `FEATURE_SETTINGS` — the app needs a tab.

## Adding files

The project uses `PBXFileSystemSynchronizedRootGroup`. **Create a `.swift` file
anywhere under `SwiftUITemplate/` and it compiles — do not edit
`project.pbxproj`.** Editing the pbxproj by hand is how agents break this repo.

New third-party package: add it in Xcode (File → Add Package Dependencies), then
wrap its use in `#if canImport(ThatModule)` inside `Services/`.

## Concurrency

Swift 6 language mode, strict concurrency. Services and view models are
`@MainActor @Observable final class`. Use `async`/`await`; Combine appears in
exactly one place — `BackendService.observeAuthState`, bridging ConvexMobile's
publisher — and should stay there.

## Liquid Glass

Target is iOS 26+. There is no iOS 17–25 fallback path and
`UIDesignRequiresCompatibility` is deliberately absent.

* **System first.** `TabView` + `Tab`, `NavigationStack` toolbars, `.sheet`,
  `Menu`, `.alert` all get Liquid Glass from the system. Use them and stop.
* **Custom glass is for the floating/navigation layer only** — see
  `Core/DesignSystem/GlassActionBar.swift`. Used by the paywall CTA and the Home
  add button, and nowhere else.
* **Never glass on glass.** Content behind a glass control stays opaque
  (`Color(.secondarySystemGroupedBackground)`). List rows, cards and form
  sections are never glass.
* Group related glass shapes in a `GlassEffectContainer` so they blend as one.
* `.interactive()` on primary glass controls.
* Don't fight Reduce Transparency or Increase Contrast with hard overlays.

## Convex

* `"module:functionName"` string names, called through `BackendService`.
* Every public function declares **both** `args` and `returns` validators.
* Every authenticated function starts with `ctx.auth.getUserIdentity()` and
  handles `null`.
* Key user data off `identity.subject`, never email.
* Third-party HTTP calls only from actions. `"use node"` when you need an npm
  package with Node APIs (see `convex/stripe.ts`).
* Anything a client must not control is an `internalQuery` / `internalMutation`
  (see `convex/stripeCustomers.ts` — a public "link my Stripe customer" mutation
  would let users read each other's billing).
* Develop with `npx convex dev`. Do not run `npx convex deploy` unless the task
  is explicitly about production.

## Clerk ↔ Convex

Configure Clerk **before** building the Convex client — `AppEnvironment.start()`
does this in order. `ClerkConvexAuthProvider` syncs the session automatically;
there is no `client.login()` call in this app and adding one is a bug.

## RevenueCat vs Stripe

They are not alternatives:

* **RevenueCat** — App Store in-app purchases. The only legal path for digital
  goods on iOS. Owns `isPremium`.
* **Stripe** — read-only lookups of web purchases, through a Convex action. The
  secret key lives in the Convex environment and must never enter the app.

Do not add Stripe Checkout to the iOS app.

## Forbidden

- Force-unwraps (`!`) in app code, and `try!` / `as!`.
- `print` — use `Log` (`Core/Extensions/Log.swift`).
- Secrets in source, in `Base.xcconfig`, or committed in `Secrets.xcconfig`.
- Editing `project.pbxproj` to add source files.
- Importing an SDK from `Features/`.
- `UIDesignRequiresCompatibility`, or an iOS 17–25 design fallback.
- Glass on content. Glass on glass.
- `fatalError` for configuration problems.

## Verifying

```bash
xcodebuild -project SwiftUITemplate.xcodeproj -scheme SwiftUITemplate \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

```bash
npm run typecheck     # convex/, after `npx convex dev` has generated _generated/
```

Deletion safety: remove one token from `FEATURE_FLAGS`, delete the matching
`Features/` folder, build again. See `skills/verify-build`.

Interactive UI carries `accessibilityIdentifier`s (`home.addItem`,
`paywall.purchase`, `settings.portal.feedback`, …) so you can drive and verify
the app from a UI test or a simulator screenshot.
