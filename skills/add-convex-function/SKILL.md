---
name: add-convex-function
description: Scaffold a Convex query, mutation or action with args/returns validators and an auth check, plus the Swift call site. Use when adding backend functionality or a new table.
---

# Add a Convex function

## Pick the right kind

| Kind | Use for | Can call third-party APIs? |
|---|---|---|
| `query` | reads; the iOS client subscribes and gets live updates | no |
| `mutation` | writes, transactional | no |
| `action` | anything needing `fetch` or an npm package | yes |
| `internalQuery` / `internalMutation` / `internalAction` | anything a client must not invoke directly | — |

## Table (if you need one)

`convex/schema.ts` — always add the index you'll query by:

```ts
journalEntries: defineTable({
  title: v.string(),
  ownerSubject: v.string(),
}).index("by_owner", ["ownerSubject"]),
```

## Function

`convex/journal.ts`:

```ts
import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

const journalEntry = v.object({
  _id: v.id("journalEntries"),
  _creationTime: v.number(),
  title: v.string(),
  ownerSubject: v.string(),
});

export const list = query({
  args: {},
  returns: v.array(journalEntry),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) return [];   // subscriptions outlive sign-out
    return await ctx.db
      .query("journalEntries")
      .withIndex("by_owner", (q) => q.eq("ownerSubject", identity.subject))
      .order("desc")
      .take(50);
  },
});

export const create = mutation({
  args: { title: v.string() },
  returns: v.id("journalEntries"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) throw new Error("Sign in to create entries.");
    const title = args.title.trim();
    if (title.length === 0 || title.length > 200) {
      throw new Error("Title must be between 1 and 200 characters.");
    }
    return await ctx.db.insert("journalEntries", {
      title,
      ownerSubject: identity.subject,
    });
  },
});
```

Non-negotiable: `args` **and** `returns` validators on every public function;
`ctx.auth.getUserIdentity()` before touching user data; `.withIndex()` not
`.filter()`; ownership checked before `patch`/`delete`, with the same "not found"
message for missing and forbidden so callers can't probe for ids.

Return an empty result rather than throwing in a query the client subscribes to
across sign-out — otherwise the app shows a spurious alert on logout.

## Action calling a third-party API

Put `"use node";` at the top — then the file may contain **actions only**. Read
the database through `ctx.runQuery(internal.module.fn, …)`. Secrets come from
`process.env`, set with `npx convex env set`. `convex/stripe.ts` is the worked
example.

**Annotate the handler's return type.** An action that calls `ctx.runQuery` from
a module that is part of the generated API creates a circular type: the api type
depends on the handler's inferred return type, which depends on the api type.
TypeScript reports it as *"implicitly has type 'any' because it is referenced
directly or indirectly in its own initializer"*.

```ts
export type BillingSummary = { /* … */ };

export const getBillingSummary = action({
  args: {},
  returns: billingSummaryValidator,
  handler: async (ctx): Promise<BillingSummary> => { /* … */ },
});
```

## Anything a client shouldn't control

Use `internalQuery` / `internalMutation`. A public mutation that accepts, say, a
`stripeCustomerId` would let any signed-in user point their account at someone
else's records — see `convex/stripeCustomers.ts`.

## Swift side

Add a `Decodable` model mirroring the `returns` validator, then call through
`BackendService` — never import ConvexMobile from `Features/`:

```swift
for try await entries in backend.subscribe(to: "journal:list", as: [JournalEntry].self) {
    state = .loaded(entries)
}

try await backend.mutation("journal:create", args: ["title": .string(title)])

let summary = try await backend.action("billing:summary", as: Summary.self)
```

Watch the time units: Convex `_creationTime` is **milliseconds** since the epoch,
Stripe timestamps are **seconds**. `DemoItem` and `BillingSummary` each convert
in a custom `init(from:)`.

Argument types come from `BackendValue` (`.string`, `.int`, `.double`, `.bool`,
`.null`). Need another type? Add a case there and map it in
`BackendService.encode` — that keeps ConvexMobile inside `Services/Convex/`.

## Verify

```bash
npx convex dev      # pushes and regenerates convex/_generated/
npm run typecheck
```

`npm run typecheck` fails before `convex dev` has ever run — `convex/_generated/`
is gitignored and created by the CLI.
