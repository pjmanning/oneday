# Starting a new app from this template

**Who this is for:** an AI agent (Claude Code, Cursor, Codex, …) in a fresh
session, told something like *"let's build a hiking-log app based on this
template."* Follow it top to bottom.

**Human shortcut** — paste this into a new chat after cloning:

> I've cloned the SwiftUI Template into this directory. Read `docs/NEW_PROJECT.md`
> and `AGENTS.md`, then set it up as a new app. It's called **<NAME>**, bundle id
> **<com.you.app>**, and it does **<one sentence>**.

---

## 0. Interview first, edit nothing yet

You cannot pick feature flags or a Convex schema without these answers. Ask all
of them in one go, then wait:

1. **App name and bundle id** — e.g. "Trail Notes", `com.acme.trailnotes`.
2. **What does it do**, in one sentence? You'll turn this into the Convex schema
   and the Home screen.
3. **Accounts?** If no sign-in, `FEATURE_AUTH` goes and Convex runs anonymously.
4. **Paid?** Subscription (keep `FEATURE_PAYWALL`), free, or paid-upfront.
5. **Which of these do they actually want on day one** — push, analytics, crash
   reporting, in-app feedback, web billing? Default to *off* for anything they
   don't name. Every module kept is a dashboard to configure.

Don't ask about API keys yet. The app runs without them.

## 1. Get the code, detach from the template

```bash
gh repo clone pjmanning/swiftuitemplate-ios trail-notes
cd trail-notes
rm -rf .git && git init && git add -A && git commit -m "Initial commit from SwiftUI Template"
```

The `rm -rf .git` matters — otherwise you're committing the new app into the
template's history and its remote.

If the template is a GitHub template repository, this is equivalent:

```bash
gh repo create acme/trail-notes --private --template pjmanning/swiftuitemplate-ios --clone
```

## 2. Rename

```bash
./Scripts/rename.sh --name "Trail Notes" --bundle-id com.acme.trailnotes --yes
```

Renames the display name, bundle id, Xcode project, target, scheme, source
folder and the `@main` struct. Use `--target-name` if the display name doesn't
reduce to a valid Swift identifier ("99 Problems" → `NinetyNineProblems`).

Verify before going further:

```bash
xcodebuild -project TrailNotes.xcodeproj -scheme TrailNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## 3. Cut what they don't need

Edit `FEATURE_FLAGS` in `Config/Base.xcconfig`, then delete the matching folders.
Both steps — the flag alone only hides it.

| Removing | Delete |
|---|---|
| `FEATURE_ONBOARDING` | `TrailNotes/Features/Onboarding/` |
| `FEATURE_AUTH` | `TrailNotes/Features/Auth/` |
| `FEATURE_PAYWALL` | `TrailNotes/Features/Paywall/` |
| `FEATURE_BILLING` | `TrailNotes/Features/Billing/` |
| `FEATURE_PROFILE` | `TrailNotes/Features/Profile/` |
| `FEATURE_SETTINGS` | `TrailNotes/Features/Settings/` |
| `FEATURE_PUSH` | `TrailNotes/Services/OneSignal/` |
| `FEATURE_FEATUREBASE` | `TrailNotes/Services/FeatureBase/` |
| `FEATURE_LOTTIE` | `TrailNotes/Services/Lottie/` |
| `FEATURE_ANALYTICS` / `FEATURE_ERROR_REPORTING` | flag only — these are facades called from everywhere and become no-ops |

Keep at least one of `FEATURE_HOME` / `FEATURE_PROFILE` / `FEATURE_SETTINGS`.

Build again. It must still compile — that's the whole point of the flags being
compile-time. If it doesn't, something referenced the module without an
`#if FEATURE_X` guard; fix the reference, don't restore the flag.

Keep `AGENTS.md`, `.cursor/rules/`, `skills/` and `docs/` — those are how the
next agent working on this app stays oriented. The only doc worth deleting is
this one, once the setup is done.

## 4. Secrets

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Gitignored. Leave everything `REPLACE_ME` for now; the app runs and each
unconfigured service says which setting it wants. Walk the human through
`docs/SETUP.md` when they're ready — don't block building on it.

The only two that can't wait, once they want real data: `CLERK_PUBLISHABLE_KEY`
and `CONVEX_DEPLOYMENT_URL`.

## 5. Model their domain in Convex

Replace `demoItems` with the real thing. From answer 2 of the interview:

- `convex/schema.ts` — their tables. Index by `ownerSubject` (the Clerk user id)
  for anything user-owned; never key off email.
- `convex/<domain>.ts` — queries and mutations. `args` **and** `returns`
  validators on every public function, `ctx.auth.getUserIdentity()` before
  touching user data.
- Delete `convex/demoItems.ts` and its table.
- Keep `convex/stripe.ts` + `stripeCustomers.ts` only if `FEATURE_BILLING` stayed.

`skills/add-convex-function` has the exact scaffold. Then:

```bash
npm install && npx convex dev      # creates the deployment, generates _generated/
npm run typecheck
```

## 6. Replace Home

`Features/Home/` is a placeholder card, a premium-gate example and a live Convex
list. Swap in their actual first screen, keeping the shape:

- `@Observable` view model with a `LoadState` enum
- `for try await` over `backend.subscribe(...)` inside `.task`
- `accessibilityIdentifier` on every interactive control

Delete `Features/Home/DemoItem.swift` along with the demo table.

`skills/add-feature` has the scaffold for additional screens.

## 7. Verify before reporting done

```bash
xcodebuild -project TrailNotes.xcodeproj -scheme TrailNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Zero warnings in the app's own sources. Then run it and check the first screen
renders. `skills/verify-build` has the simulator commands, including the launch
arguments that skip past onboarding.

Commit.

## Ground rules

`AGENTS.md` is the contract — read it before writing code. The short version:

- Features never import each other, or any SDK. SDKs live in `Services/`.
- Every feature stays deletable: guard cross-module references with `#if FEATURE_X`.
- Missing configuration degrades with a message; it never crashes.
- Navigation goes through `RootRouter`.
- Liquid Glass from system chrome; custom `glassEffect` only on floating controls,
  never on content, never on glass.
- No force-unwraps, no `print`, no hand-editing `project.pbxproj`.

## Don't

- **Don't edit `project.pbxproj`** to add files. The target uses synchronized
  folders — creating the file is enough. This is the single most common way an
  agent breaks this project.
- **Don't run `npx convex deploy`.** `npx convex dev` for everything until the
  human explicitly asks for production.
- **Don't put a Stripe secret key in the app.** It belongs in the Convex
  environment. There is no in-app Stripe Checkout — Apple doesn't allow it for
  digital goods; that's what RevenueCat is for.
- **Don't add an iOS 17–25 design fallback** or set
  `UIDesignRequiresCompatibility`. Deployment target is iOS 26.
- **Don't keep modules "just in case."** Each one is a dashboard to configure and
  a privacy disclosure to write. Deleting is cheap; that's the design.
