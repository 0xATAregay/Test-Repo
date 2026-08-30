import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/d1";

/**
 * Cloudflare D1 adapter retained for the existing hosting environment.
 * EdgeLab's default local-first repository does not require this binding.
 * The relational PostgreSQL reference model lives in db/schema.ts for the
 * optional cloud adapter described in README.md.
 */
export function getDb() {
  if (!env.DB) {
    throw new Error("Cloudflare D1 binding `DB` is unavailable. Local/demo EdgeLab does not require it.");
  }
  return drizzle(env.DB);
}
