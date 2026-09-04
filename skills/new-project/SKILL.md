---
name: new-project
description: Turn this template into a brand-new app — interview, rename, cut unused modules, model the Convex schema, replace Home. Use when the user says "let's build X based on this template", "start a new app from this", or has just cloned the kit into an empty project.
---

# Start a new app from this template

Full procedure: [`docs/NEW_PROJECT.md`](../../docs/NEW_PROJECT.md). Read it, and
`AGENTS.md`, before editing anything.

## Interview first — do not skip

You can't choose feature flags or a schema without these. Ask all five at once:

1. App name and bundle id?
2. What does it do, in one sentence?
3. Do users have accounts? (no → drop `FEATURE_AUTH`)
4. Is it paid? (subscription → keep `FEATURE_PAYWALL`)
5. Which of push / analytics / crash reporting / in-app feedback / web billing do
   they want **on day one**?

Default every unnamed module to *off*. Each one kept is a dashboard to configure
and a privacy disclosure to write.

Don't ask for API keys. The app builds and runs on placeholders.

## Then, in order

1. **Detach from the template** — `rm -rf .git && git init` after cloning, or
   `gh repo create <new> --private --template pjmanning/swiftuitemplate-ios --clone`.
   Skipping this commits the new app into the template's history.
2. **`./Scripts/rename.sh --name "…" --bundle-id … --yes`**, then build.
3. **Cut modules** — remove tokens from `FEATURE_FLAGS` in `Config/Base.xcconfig`
   *and* delete the folders. Build again; it must still compile.
4. **`cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig`** and move on.
   Placeholders are fine; each service says what it wants.
5. **Model the domain in Convex** — replace `demoItems` with their tables, then
   `npx convex dev`. See `skills/add-convex-function`.
6. **Replace `Features/Home/`** with their real first screen. See
   `skills/add-feature`.
7. **Verify and commit** — see `skills/verify-build`.

## The mistakes that actually happen

- Editing `project.pbxproj` to add a file. The target uses synchronized folders;
  creating the file is enough.
- Forgetting `rm -rf .git`, so the new app pushes to the template's remote.
- Removing a feature flag but leaving the folder, or vice versa. Do both.
- Keeping every module because it's already wired. It isn't free.
- Running `npx convex deploy` instead of `npx convex dev`.
