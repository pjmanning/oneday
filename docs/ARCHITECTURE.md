# Architecture

## The whole system

```
                      ┌─────────────────────────────────────────┐
                      │              iOS app (SwiftUI)            │
                      │                                           │
                      │  App/       RootRouter · AppEnvironment   │
                      │  Features/  Onboarding Auth Paywall Home  │
                      │             Profile Settings Billing      │
                      │  Core/      DesignSystem                  │
                      │  Services/  ← the only SDK imports        │
                      └───┬──────────┬──────────┬────────────┬───┘
                          │           │          │            │
              Clerk SDK   │           │ Convex   │ RevenueCat │ WKWebView
              (sign in)   │           │ WebSocket│ StoreKit 2 │
                          ▼           ▼          ▼            ▼
                    ┌──────────┐  ┌────────┐  ┌────────┐  ┌─────────────┐
                    │  Clerk   │  │ Convex │  │Revenue │  │ FeatureBase│
                    │          ├─▶│        │  │  Cat   │  │   portal   │
                    └──────────┘  └───┬────┘  └───┬────┘  └─────────────┘
                       JWT (aud:      │           │         (web only —
                       "convex")      │ actions   │          no iOS SDK)
                                      ▼           ▼
                                 ┌────────┐  ┌───────────┐
                                 │ Stripe │  │App Store │
                                 │  API   │  │ (IAP)    │
                                 └────────┘  └───────────┘
                                  secret key
                                  server-side only
```

Two things are worth staring at:

* **Clerk's JWT is what authenticates Convex.** The app never sends a token
  itself. `ClerkConvexAuthProvider` watches the Clerk session and hands Convex a
  fresh token; there is no `client.login()` call anywhere in this app.
* **Stripe is only reachable from Convex.** The secret key lives in the Convex
  environment. Nothing on the phone can talk to Stripe directly, by design.

## Layers

```
Features/  →  Services/, Core/, App/
Services/  →  Core/  (+ its own SDK)
Core/      →  nothing
```

A feature never imports a sibling feature — with one narrow exception: it may
embed another feature's entry view inside `#if FEATURE_OTHER`. `ProfileView`
embedding `BillingSummarySection` is the only instance, and it exists so that
deleting `Features/Billing/` leaves Profile compiling.

A feature never imports an SDK. `Features/` code sees `AuthUser`,
`BackendValue`, `PurchaseService.Product` — plain Swift types we own. Replacing
Clerk with something else is a change confined to `Services/Clerk/`.

## Navigation

`RootRouter` owns one enum:

```
launch → onboarding? → auth? → paywall? → main
```

Each step drops out when its feature is off, and the router handles every
combination. Screens report events (`completeOnboarding()`, `markPaywallSeen()`,
`isPresentingPaywall = true`) rather than presenting each other. Inside a tab,
ordinary `NavigationStack` push/pop applies.

`launch` exists so a returning user never sees a flash of the sign-in screen
while Clerk restores their session.

## Feature flags are compile-time

`FEATURE_FLAGS` in `Config/Base.xcconfig` feeds
`SWIFT_ACTIVE_COMPILATION_CONDITIONS`. Removing a token makes every reference to
that module vanish at compile time, so the folder can then be deleted outright.
A runtime boolean could hide a feature; only a compile-time condition can make
it *removable*. `App/FeatureFlags.swift` mirrors the tokens as booleans for the
places that just need to branch.

## Configuration flow

```
Config/Base.xcconfig  (REPLACE_ME placeholders, committed)
        ↓  #include? — optional, so a fresh clone still builds
Config/Secrets.xcconfig  (your keys, gitignored)
        ↓  $(VAR) substitution
Config/Info.plist → STConfig dictionary
        ↓
App/AppConfig.swift   ← the only reader of Bundle.main
        ↓  nil for anything still REPLACE_ME
Services/*            ← disable themselves, log one actionable line
        ↓
SetupRequiredView     ← names the exact setting to fill in
```

Nothing crashes on a missing key. That is the difference between a template you
can evaluate in five minutes and one you have to fully configure before it will
launch once.

## RevenueCat vs Stripe

Not alternatives — different jobs.

| | RevenueCat | Stripe |
|---|---|---|
| Buys what | in-app subscriptions | purchases made on your website |
| Runs where | on device, via StoreKit 2 | in a Convex action |
| Owns | `isPremium`, the paywall, restore | read-only customer / charges / invoices |
| Key | public SDK key, in the app | secret key, Convex env only |

Apple requires digital goods on iOS to go through StoreKit, so RevenueCat is the
purchase path. Stripe is here because plenty of products sell on the web too and
users expect to see that history in the app. `Features/Billing` never writes.

## Convex

Functions are addressed by string (`"demoItems:list"`) through `BackendService`,
which is also the only place ConvexMobile is imported and the only place Combine
appears (bridging its `authState` publisher into `@Observable`).

Query subscriptions arrive as `AsyncThrowingStream`, so a view's `.task` gets
live updates and the subscription tears down on disappear with no bookkeeping.

Backend rules — validators on every public function, `getUserIdentity()` before
touching user data, internal-only functions for anything a client shouldn't
control — are in [`.cursor/rules/convex.mdc`](../.cursor/rules/convex.mdc).

## Liquid Glass

Standard system components (`TabView` + `Tab`, `NavigationStack` toolbars,
sheets, `List`) render as Liquid Glass on iOS 26 with no code from us. That
covers almost every screen.

Custom glass is confined to `Core/DesignSystem/GlassActionBar.swift` and used in
exactly two places: the paywall CTA and the Home add button. Both float over
opaque content, because glass sampling glass is the one thing Apple explicitly
warns against.

Nothing in this kit sets `UIDesignRequiresCompatibility`, and there is no
iOS 17–25 design branch.
