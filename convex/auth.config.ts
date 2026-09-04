/**
 * Tells Convex to trust JWTs issued by your Clerk instance.
 *
 * `applicationID` must be exactly "convex" — that is the JWT template name the
 * Clerk dashboard creates for the Convex integration. Change it and every
 * authenticated query silently returns unauthenticated.
 *
 * Set the domain once with:
 *
 *   npx convex env set CLERK_JWT_ISSUER_DOMAIN https://your-app.clerk.accounts.dev
 *
 * (Clerk Dashboard → Configure → Sessions → JWT Templates → convex → Issuer.)
 */
export default {
  providers: [
    {
      domain: process.env.CLERK_JWT_ISSUER_DOMAIN,
      applicationID: "convex",
    },
  ],
};
