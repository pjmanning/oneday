---
name: wire-secrets
description: Set up Config/Secrets.xcconfig and the Convex environment — Clerk, Convex, RevenueCat, PostHog, Sentry, OneSignal, FeatureBase, Stripe. Use when the user has keys to add, sees "not configured" in the app, or is doing first-time setup.
---

# Wire up secrets

## 1. Create the file

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

It is gitignored. `Config/Base.xcconfig` includes it optionally, so the project
builds either way — anything left as `REPLACE_ME` disables that integration and
shows a `SetupRequiredView` naming the setting.

**xcconfig gotcha:** `//` starts a comment. Write URLs as
`https:$(SLASH)$(SLASH)example.com`. `$(SLASH)` is defined in `Base.xcconfig`.

## 2. Client-side keys → `Config/Secrets.xcconfig`

| Setting | Where to get it |
|---|---|
| `CLERK_PUBLISHABLE_KEY` | dashboard.clerk.com → API keys → Publishable key |
| `CONVEX_DEPLOYMENT_URL` | printed by `npx convex dev`, or dashboard.convex.dev → Settings |
| `REVENUECAT_API_KEY` | app.revenuecat.com → Project → API keys → **Apple App Store** public key |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | posthog.com → Project settings |
| `SENTRY_DSN` | sentry.io → Project → Settings → Client Keys (DSN) |
| `ONESIGNAL_APP_ID` | app.onesignal.com → Settings → Keys & IDs |
| `FEATUREBASE_PORTAL_URL`, `FEATUREBASE_CHANGELOG_URL` | your hosted FeatureBase portal |
| `PRIVACY_POLICY_URL`, `TERMS_URL`, `SUPPORT_EMAIL` | yours |
| `DEVELOPMENT_TEAM` | Apple Developer → Membership → Team ID (device builds only) |

## 3. Server-side secrets → Convex environment

**Never put these in the app.**

```bash
npx convex env set CLERK_JWT_ISSUER_DOMAIN https://your-app.clerk.accounts.dev
npx convex env set STRIPE_SECRET_KEY sk_test_...
```

The issuer domain comes from Clerk Dashboard → Configure → Sessions → JWT
Templates → **convex** → Issuer. The template must be named exactly `convex`, or
`convex/auth.config.ts` won't match and every authenticated query silently
returns unauthenticated.

## 4. Dashboard steps that no script can do

- **Clerk**: enable Sign in with Apple and Google as social connections; run the
  Convex integration setup at dashboard.clerk.com/apps/setup/convex.
- **Apple Developer**: register the bundle id; enable Sign in with Apple and
  Push Notifications.
- **RevenueCat**: create products, attach them to an offering, mark it
  **Current**, and create the `premium` entitlement (the id
  `PurchaseService.premiumEntitlementID` expects).
- **OneSignal**: upload an APNs auth key.
- **Stripe**: link a customer to a Clerk user before the Billing screen shows
  anything — Convex dashboard → Functions → `stripeCustomers:linkCustomer` →
  Run, with `ownerSubject` (the Clerk `user_...` id) and `stripeCustomerId`.

## 5. Check it

Build and run, then Settings → Diagnostics (DEBUG builds) shows how many keys
are still unconfigured. The launch log also prints one summary line:

```
AppConfig: 3 key(s) still set to REPLACE_ME — the matching features are disabled: …
```

## Adding a new key

Touch all five places, or it will read as `nil`:

1. `Config/Base.xcconfig` — placeholder
2. `Config/Secrets.example.xcconfig` — documented example
3. `Config/Info.plist` — an entry under `STConfig`
4. `App/AppConfig.swift` — a `Key` case and an accessor
5. `docs/SETUP.md` — where to obtain it
