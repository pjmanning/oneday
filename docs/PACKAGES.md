# Packages

Everything is Swift Package Manager, declared in the Xcode project. No
CocoaPods, no Carthage, no checked-in binaries.

| Package | Product | Version | Used by |
|---|---|---|---|
| [clerk-ios](https://github.com/clerk/clerk-ios) | `ClerkKit` | 1.3.6+ | `Services/Clerk` |
| [convex-swift](https://github.com/get-convex/convex-swift) | `ConvexMobile` | 0.8.1+ | `Services/Convex` |
| [clerk-convex-swift](https://github.com/clerk/clerk-convex-swift) | `ClerkConvex` | 0.1.0+ | `Services/Convex` |
| [purchases-ios-spm](https://github.com/RevenueCat/purchases-ios-spm) | `RevenueCat` | 5.83.0+ | `Services/RevenueCat` |
| [posthog-ios](https://github.com/PostHog/posthog-ios) | `PostHog` | 3.69.2+ | `Services/PostHog` |
| [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) | `Sentry` | 9.25.0+ | `Services/Sentry` |
| [OneSignal-XCFramework](https://github.com/OneSignal/OneSignal-XCFramework) | `OneSignalFramework` | 5.5.6+ | `Services/OneSignal` |

## Two repo choices worth knowing about

Several vendors publish a second, SPM-specific repository. The main repos carry
compiled binaries in their git history, and SwiftPM clones full history:

| SDK | Main repo | SPM repo | Used here |
|---|---|---|---|
| OneSignal | `OneSignal-iOS-SDK` — **2.8 GB** | `OneSignal-XCFramework` — **16 MB** | XCFramework |
| RevenueCat | `purchases-ios` — 54 MB | `purchases-ios-spm` — 44 MB | spm |

Same SDK, same version numbers. Pointing at `OneSignal-iOS-SDK` turns a first
`git clone && open` into a 20-minute download, which is the opposite of what
this kit is for. If you add a package and resolution crawls, check whether the
vendor has an SPM-specific repo.

## Deliberately not included

**Lottie** (`lottie-ios`, ~200 MB checkout). Onboarding uses animated SF Symbols
instead. The integration is already written, in
`Services/Lottie/LottieAnimationView.swift` — add the package and
`LottieSupport.isAvailable` flips to `true`, so `OnboardingArtwork` starts using
it for any page with a `lottieName`:

```
File → Add Package Dependencies → https://github.com/airbnb/lottie-ios
```

Then drop a `.json`/`.lottie` file in `SwiftUITemplate/Resources/` and name it in
`OnboardingPage.all`.

**ClerkKitUI** — Clerk's prebuilt auth screens (and their Nuke + PhoneNumberKit
dependencies). `Features/Auth` is 140 lines of SwiftUI you can restyle, which is
what most people want from a template. Add the `ClerkKitUI` product if you'd
rather use Clerk's components.

**RevenueCatUI** — same reasoning; `PaywallView` is ours and easy to edit.

**OneSignalExtension / OneSignalInAppMessages / OneSignalLocation** — the
extension product needs a Notification Service Extension target, which this MVP
doesn't ship. Add both when you want rich push.

## Adding a package

1. Xcode → File → Add Package Dependencies.
2. Import it **only** inside a `Services/<Vendor>/` file.
3. Guard it: `#if canImport(TheModule) && FEATURE_X`, so removing either the
   package or the flag still compiles.
4. Expose your own plain Swift types to `Features/`.

If the SDK ships as a dynamic framework, confirm it lands in
`YourApp.app/Frameworks/`. `LD_RUNPATH_SEARCH_PATHS` in `Config/Base.xcconfig`
already includes `@executable_path/Frameworks` — without it the app builds and
then dies at launch with `Library not loaded: @rpath/…`.

## Apple Silicon only (for the simulator)

ConvexMobile ships an arm64-only simulator slice, so `Config/Base.xcconfig`
sets:

```
EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64
```

Device builds are unaffected. If you ever need to build the simulator target on
an Intel Mac, you'd have to replace the Convex client first.

## Node packages

`package.json` covers the Convex backend only:

- `convex` — CLI and function runtime types
- `stripe` — used by `convex/stripe.ts` (Node runtime, hence `"use node"`)
- `typescript` — pinned to 5.x
