# Convex backend — OneDay

TypeScript functions for the iOS app. The client calls them by name
(`"posts:feed"`) through `OneDay/Services/Convex/BackendService.swift`.

## Files

| File | What it does |
|---|---|
| `schema.ts` | `posts`, `follows`, `userSettings` |
| `auth.config.ts` | Clerk JWTs (`applicationID: "convex"`) |
| `posts.ts` | feed / hasPostedOnDay / create (1/day lock) |
| `following.ts` | follow/unfollow + people-vs-minutes cap settings |

## Develop

```bash
npm install
npx convex dev        # creates a deployment, pushes, generates _generated/
npm run typecheck
```

Do **not** run `npx convex deploy` unless you are producing a production setup.

## Environment

```bash
npx convex env set CLERK_JWT_ISSUER_DOMAIN https://your-app.clerk.accounts.dev
```

## House style

Every public function declares `args` **and** `returns` validators and checks
`ctx.auth.getUserIdentity()` before touching user data.
