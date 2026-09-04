# OneDay

TikTok-style vertical feed with one hard rule: **one post per person per day**.

Clips are 1–3 minutes, one headline, no external links. Follow at most 30 people
— or cap yourself at 30 minutes of feed per day. Every clip has an AI summary
slot so you can decide if it's worth your time.

Seeded from [swiftuitemplate-ios](https://github.com/pjmanning/swiftuitemplate-ios).

## Product rules (scaffolded)

| Rule | Where |
|---|---|
| 1 post / user / day | `DailyPostLock` + `posts:create` |
| 1–3 minute clips | Composer stepper + Convex validators |
| One headline, no links | Composer + `posts:create` |
| Following cap: 30 people **or** 30 min/day | Settings stubs + `following` Convex module |
| AI summary | Placeholder on feed + composer |

## Screens

- **Feed** — vertical paging, full-bleed post pages, compose FAB
- **Composer** — headline, duration, clip stub, 1/day lock
- **Profile** — identity, today's publish status, cap summary
- **Settings** — following-cap picker (both modes stubbed), privacy, legal

## Requirements

- Xcode 26+ (iOS 26 SDK), Apple Silicon Mac for simulator
- Node 20+ (Convex backend)

## Run (iOS)

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
open OneDay.xcodeproj
# Cmd+R — app runs with REPLACE_ME keys; unconfigured services degrade
```

## Run (Convex)

```bash
npm install
npx convex dev          # development only — never deploy from this step
npm run typecheck
```

Set `CONVEX_DEPLOYMENT_URL` and `CLERK_PUBLISHABLE_KEY` in
`Config/Secrets.xcconfig` when you want live data. Until then the feed shows
local sample posts.

## Verify structure (Linux / CI without Xcode)

```bash
./Scripts/verify-oneday.sh
```

Full compile requires macOS:

```bash
xcodebuild -project OneDay.xcodeproj -scheme OneDay \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Cloud Agent bootstrap:

```bash
./Scripts/cloud-agent-install.sh
```

## Layout

```
OneDay/                 SwiftUI app (synchronized folders)
  App/                  RootRouter, tabs, environment
  Features/Home/        Vertical feed + AI summary placeholder
  Features/Composer/    1/day publish flow
  Features/Profile/     Status + caps summary
  Features/Settings/    Following-cap settings
  Core/OneDay/          DailyPostLock, FollowingCapsStore
convex/                 posts, following, schema
Config/                 Base.xcconfig, Secrets.example.xcconfig
```

## Repos

- **Browse:** https://cursor.com/codebase/pjmanning/oneday (Private — change in settings)
- **Origin:** `pjmanning/oneday` — `origin repo clone pjmanning/oneday`
- **GitHub:** https://github.com/pjmanning/oneday (mirror; app icon PNG may be missing)
- Template seed: https://github.com/pjmanning/swiftuitemplate-ios

### Clone with Origin CLI

```bash
curl -fsSL https://downloads.cursor.com/origin/install.sh | sh
origin auth login
origin repo clone pjmanning/oneday
```

If `origin` is not found after install:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Docs: https://cursor.com/docs/origin/cli
