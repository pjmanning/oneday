import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

const MIN_DURATION = 60;
const MAX_DURATION = 180;
const MAX_HEADLINE = 80;

const postValidator = v.object({
  _id: v.id("posts"),
  _creationTime: v.number(),
  authorSubject: v.string(),
  authorDisplayName: v.string(),
  headline: v.string(),
  durationSeconds: v.number(),
  dayKey: v.string(),
  aiSummary: v.optional(v.string()),
});

function containsExternalLink(text: string): boolean {
  const lower = text.toLowerCase();
  if (
    lower.includes("http://") ||
    lower.includes("https://") ||
    lower.includes("www.")
  ) {
    return true;
  }
  return /\b[a-z0-9-]+\.(com|net|org|io|app)\b/i.test(text);
}

/**
 * Feed for the signed-in user: posts from people they follow, plus their own,
 * newest first. Unauthenticated callers get an empty list so the subscription
 * stays quiet across sign-out.
 */
export const feed = query({
  args: {},
  returns: v.array(postValidator),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return [];
    }

    const follows = await ctx.db
      .query("follows")
      .withIndex("by_follower", (q) => q.eq("followerSubject", identity.subject))
      .take(30);

    const authorSet = new Set<string>([
      identity.subject,
      ...follows.map((f) => f.followeeSubject),
    ]);

    const collected = [];
    for (const author of authorSet) {
      const recent = await ctx.db
        .query("posts")
        .withIndex("by_author", (q) => q.eq("authorSubject", author))
        .order("desc")
        .take(7);
      collected.push(...recent);
    }

    collected.sort((a, b) => b._creationTime - a._creationTime);
    return collected.slice(0, 40);
  },
});

/** Whether the caller already published on `dayKey`. */
export const hasPostedOnDay = query({
  args: { dayKey: v.string() },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return false;
    }

    const existing = await ctx.db
      .query("posts")
      .withIndex("by_author_day", (q) =>
        q.eq("authorSubject", identity.subject).eq("dayKey", args.dayKey),
      )
      .unique();

    return existing !== null;
  },
});

/** Publish today's OneDay. Enforces 1/day, duration, headline, no links. */
export const create = mutation({
  args: {
    headline: v.string(),
    durationSeconds: v.number(),
    dayKey: v.string(),
  },
  returns: v.id("posts"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Sign in to publish today's OneDay.");
    }

    const headline = args.headline.trim();
    if (headline.length === 0 || headline.length > MAX_HEADLINE) {
      throw new Error(`Headline must be 1–${MAX_HEADLINE} characters.`);
    }
    if (containsExternalLink(headline)) {
      throw new Error("No external links — keep it in the clip.");
    }
    if (
      args.durationSeconds < MIN_DURATION ||
      args.durationSeconds > MAX_DURATION
    ) {
      throw new Error("Clips must be between 1 and 3 minutes.");
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(args.dayKey)) {
      throw new Error("Invalid day key.");
    }

    const existing = await ctx.db
      .query("posts")
      .withIndex("by_author_day", (q) =>
        q.eq("authorSubject", identity.subject).eq("dayKey", args.dayKey),
      )
      .unique();

    if (existing !== null) {
      throw new Error("You've already shared today's OneDay. Come back tomorrow.");
    }

    const displayName =
      identity.name?.trim() ||
      identity.nickname?.trim() ||
      identity.email?.split("@")[0] ||
      "Someone";

    return await ctx.db.insert("posts", {
      authorSubject: identity.subject,
      authorDisplayName: displayName,
      headline,
      durationSeconds: args.durationSeconds,
      dayKey: args.dayKey,
      // Placeholder until the summarizer action lands.
      aiSummary: undefined,
    });
  },
});
