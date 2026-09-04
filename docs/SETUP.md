# Setup

Start to finish for a brand-new app. Budget about 20 minutes for step 1–3 and
another 30–60 for the dashboards in step 4, most of which is waiting on Apple.

Requirements: **Xcode 26 or later** (iOS 26 SDK), Node 20+, an Apple Developer
account for device builds.

---

## 1. Clone and rename

```bash
git clone <your-fork> my-app && cd my-app
./Scripts/rename.sh --name "My App" --bundle-id com.acme.myapp
```

This rewrites `Config/Base.xcconfig` and renames the project, target, scheme,
source folder and `@main` struct. See [RENAME.md](RENAME.md) for what it leaves
alone.

## 2. Secrets

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

`Config/Secrets.xcconfig` is gitignored. Fill in what you have; the rest stays
`REPLACE_ME` and the matching feature disables itself with an on-screen message
instead of crashing.

> **xcconfig gotcha:** `//` starts a comment, so URLs must be written
> `https:$(SLASH)$(SLASH)example.com`. `$(SLASH)` is defined in `Base.xcconfig`.

| Setting | Where to get it |
|---|---|
| `CLERK_PUBLISHABLE_KEY` | dashboard.clerk.com → API keys |
| `CONVEX_DEPLOYMENT_URL` | printed by `npx convex dev` |
| `REVENUECAT_API_KEY` | app.revenuecat.com → API keys → **Apple App Store** public key |
| `POSTHOG_API_KEY` / `POSTHOG_HOST` | posthog.com → Project settings |
| `SENTRY_DSN` | sentry.io → Project → Client Keys (DSN) |
| `ONESIGNAL_APP_ID` | app.onesignal.com → Keys & IDs |
| `FEATUREBASE_PORTAL_URL` / `FEATUREBASE_CHANGELOG_URL` | your FeatureBase portal |
| `PRIVACY_POLICY_URL` / `TERMS_URL` / `SUPPORT_EMAIL` | yours |
| `DEVELOPMENT_TEAM` | Apple Developer → Membership → Team ID (device builds only) |

## 3. Convex

```bash
npm install
npx convex dev        # creates a deployment, pushes convex/, generates _generated/
```

Copy the deployment URL it prints into `CONVEX_DEPLOYMENT_URL`.

Then set the two server-side secrets. **Neither belongs in the app:**

```bash
npx convex env set CLERK_JWT_ISSUER_DOMAIN https://your-app.clerk.accounts.dev
npx convex env set STRIPE_SECRET_KEY sk_test_...
```

Leave `npx convex dev` running while you work — it hot-pushes function changes.

## 4. Dashboards

### Apple Developer
- Register the bundle id.
- Enable **Sign in with Apple** and **Push Notifications** on it.
- For Sign in with Apple you also need a Services ID and a key; Clerk's guide
  walks through it.

### Clerk
- Create an application.
- Enable **Apple** and **Google** under social connections.
- Run the Convex integration setup at `dashboard.clerk.com/apps/setup/convex`.
  It creates a JWT template named **`convex`** — the name must be exactly that
  or `convex/auth.config.ts` won't match and every authenticated query will
  quietly return unauthenticated.
- Copy the template's **Issuer** into `CLERK_JWT_ISSUER_DOMAIN` above.

### RevenueCat
- Create a project, add your App Store app.
- Create products, attach them to an **offering**, mark that offering
  **Current** — `PaywallView` loads `offerings.current`.
- Create an entitlement with identifier **`premium`**. If you name it something
  else, change `PurchaseService.premiumEntitlementID`.
- Testing purchases needs App Store Connect products and a sandbox account, or a
  local StoreKit configuration file.

### Stripe
Stripe here is **read-only lookups of web purchases**. There is no in-app
checkout — Apple doesn't allow it for digital goods.

Nothing shows up until a Clerk user is linked to a Stripe customer. Link one
from the Convex dashboard → Functions → `stripeCustomers:linkCustomer` → Run:

```json
{ "ownerSubject": "user_2abc...", "stripeCustomerId": "cus_123", "email": "a@b.com" }
```

`ownerSubject` is the Clerk user id. In production you'd call the same internal
mutation from a Stripe webhook or your web checkout's success handler.

### PostHog / Sentry
Paste the keys. Nothing else to configure — Sentry has a "Send test event"
button in Settings → Diagnostics on DEBUG builds.

### OneSignal
- Create an app, choose Apple iOS (APNs).
- Upload an APNs auth key (.p8) from your Apple Developer account.
- Push does not work in the simulator; test on a device.
- Rich notifications (images, buttons) need a Notification Service Extension,
  which this MVP does not include. Add one with the `OneSignalExtension`
  product when you need it.

### FeatureBase
There is no native iOS SDK — it's a web product. Point
`FEATUREBASE_PORTAL_URL` at your portal and the app opens it in a `WKWebView`
sheet from Settings.

## 5. Run

```bash
open MyApp.xcodeproj     # Cmd+R
```

First open resolves the Swift packages, which takes a few minutes.

---

## Turning features off

`Config/Base.xcconfig`:

```
FEATURE_FLAGS = FEATURE_ONBOARDING FEATURE_AUTH FEATURE_PAYWALL FEATURE_HOME \
                FEATURE_PROFILE FEATURE_SETTINGS FEATURE_BILLING \
                FEATURE_ANALYTICS FEATURE_ERROR_REPORTING FEATURE_PUSH \
                FEATURE_FEATUREBASE FEATURE_LOTTIE
```

| Token | Removes |
|---|---|
| `FEATURE_ONBOARDING` | the intro pages; app starts at auth |
| `FEATURE_AUTH` | sign-in gate; Convex connects anonymously |
| `FEATURE_PAYWALL` | RevenueCat, paywall, all premium gating |
| `FEATURE_HOME` / `FEATURE_PROFILE` / `FEATURE_SETTINGS` | that tab (keep at least one) |
| `FEATURE_BILLING` | Stripe lookups and the Profile billing section |
| `FEATURE_ANALYTICS` | PostHog; `Analytics.track` becomes a no-op |
| `FEATURE_ERROR_REPORTING` | Sentry |
| `FEATURE_PUSH` | OneSignal and the notification prompt |
| `FEATURE_FEATUREBASE` | feedback / changelog entries and the web portal view |
| `FEATURE_LOTTIE` | Lottie support in onboarding artwork |

Delete the token, then delete the folder, then build. If it doesn't compile,
something referenced the module without an `#if` guard.

## Troubleshooting

**"Library not loaded: @rpath/….framework" at launch** — `LD_RUNPATH_SEARCH_PATHS`
in `Base.xcconfig` lost `@executable_path/Frameworks`.

**Everything says "not configured"** — you created `Config/Secrets.xcconfig` but
Xcode is holding a stale build. Clean build folder (Cmd+Shift+K).

**Convex queries return nothing while signed in** — the Clerk JWT template isn't
named `convex`, or `CLERK_JWT_ISSUER_DOMAIN` is unset in the Convex environment.
Home shows a badge reading *Anonymous* rather than *Authenticated* when this is
the problem.

**Paywall says "No current offering"** — mark an offering Current in RevenueCat.

**`npm run typecheck` fails on missing `./_generated/server`** — run
`npx convex dev` once; `convex/_generated/` is gitignored and created by the CLI.
