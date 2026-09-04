import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * OneDay domain.
 *
 * - `posts` — at most one clip per author per calendar day (`dayKey`).
 * - `follows` — who follows whom; capped client-side (and later server-side).
 * - `userSettings` — following-cap preference (people vs minutes).
 *
 * `subject` always means Clerk `identity.subject`. Never key off email.
 */
export default defineSchema({
  posts: defineTable({
    authorSubject: v.string(),
    authorDisplayName: v.string(),
    headline: v.string(),
    /** Clip length in seconds — enforced 60–180. */
    durationSeconds: v.number(),
    /** Calendar day in the author's timezone, `yyyy-MM-dd`. */
    dayKey: v.string(),
    /** Placeholder until the AI summarizer is wired. */
    aiSummary: v.optional(v.string()),
  })
    .index("by_author", ["authorSubject"])
    .index("by_author_day", ["authorSubject", "dayKey"])
    .index("by_day", ["dayKey"]),

  follows: defineTable({
    followerSubject: v.string(),
    followeeSubject: v.string(),
  })
    .index("by_follower", ["followerSubject"])
    .index("by_followee", ["followeeSubject"])
    .index("by_pair", ["followerSubject", "followeeSubject"]),

  userSettings: defineTable({
    ownerSubject: v.string(),
    /** `"people"` (max 30 follows) or `"minutes"` (max 30 min/day). */
    followingCapMode: v.union(v.literal("people"), v.literal("minutes")),
  }).index("by_owner", ["ownerSubject"]),
});
