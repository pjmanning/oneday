import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

const MAX_FOLLOWING = 30;

const settingsValidator = v.object({
  _id: v.id("userSettings"),
  _creationTime: v.number(),
  ownerSubject: v.string(),
  followingCapMode: v.union(v.literal("people"), v.literal("minutes")),
});

/** Current following count and cap mode for the signed-in user. */
export const myFollowing = query({
  args: {},
  returns: v.object({
    count: v.number(),
    maxPeople: v.number(),
    mode: v.union(v.literal("people"), v.literal("minutes")),
  }),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return { count: 0, maxPeople: MAX_FOLLOWING, mode: "people" as const };
    }

    const follows = await ctx.db
      .query("follows")
      .withIndex("by_follower", (q) => q.eq("followerSubject", identity.subject))
      .take(MAX_FOLLOWING + 1);

    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_owner", (q) => q.eq("ownerSubject", identity.subject))
      .unique();

    return {
      count: follows.length,
      maxPeople: MAX_FOLLOWING,
      mode: settings?.followingCapMode ?? ("people" as const),
    };
  },
});

export const getSettings = query({
  args: {},
  returns: v.union(settingsValidator, v.null()),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return null;
    }
    return await ctx.db
      .query("userSettings")
      .withIndex("by_owner", (q) => q.eq("ownerSubject", identity.subject))
      .unique();
  },
});

/** Persist people-vs-minutes cap preference. */
export const setFollowingCapMode = mutation({
  args: {
    mode: v.union(v.literal("people"), v.literal("minutes")),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Sign in to change following settings.");
    }

    const existing = await ctx.db
      .query("userSettings")
      .withIndex("by_owner", (q) => q.eq("ownerSubject", identity.subject))
      .unique();

    if (existing === null) {
      await ctx.db.insert("userSettings", {
        ownerSubject: identity.subject,
        followingCapMode: args.mode,
      });
    } else {
      await ctx.db.patch(existing._id, { followingCapMode: args.mode });
    }
    return null;
  },
});

/**
 * Follow someone. When cap mode is `people`, rejects past 30 follows.
 * Minute-based cap is enforced client-side for now (watch-time stub).
 */
export const follow = mutation({
  args: { followeeSubject: v.string() },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Sign in to follow people.");
    }
    if (args.followeeSubject === identity.subject) {
      throw new Error("You can't follow yourself.");
    }

    const existing = await ctx.db
      .query("follows")
      .withIndex("by_pair", (q) =>
        q
          .eq("followerSubject", identity.subject)
          .eq("followeeSubject", args.followeeSubject),
      )
      .unique();
    if (existing !== null) {
      return null;
    }

    const settings = await ctx.db
      .query("userSettings")
      .withIndex("by_owner", (q) => q.eq("ownerSubject", identity.subject))
      .unique();
    const mode = settings?.followingCapMode ?? "people";

    if (mode === "people") {
      const current = await ctx.db
        .query("follows")
        .withIndex("by_follower", (q) =>
          q.eq("followerSubject", identity.subject),
        )
        .take(MAX_FOLLOWING + 1);
      if (current.length >= MAX_FOLLOWING) {
        throw new Error(`Following cap reached (${MAX_FOLLOWING} people).`);
      }
    }

    await ctx.db.insert("follows", {
      followerSubject: identity.subject,
      followeeSubject: args.followeeSubject,
    });
    return null;
  },
});

export const unfollow = mutation({
  args: { followeeSubject: v.string() },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Sign in to unfollow.");
    }

    const existing = await ctx.db
      .query("follows")
      .withIndex("by_pair", (q) =>
        q
          .eq("followerSubject", identity.subject)
          .eq("followeeSubject", args.followeeSubject),
      )
      .unique();

    if (existing !== null) {
      await ctx.db.delete(existing._id);
    }
    return null;
  },
});
