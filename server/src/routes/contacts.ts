import { and, eq, inArray } from 'drizzle-orm';
import { Hono } from 'hono';
import { db } from '../db/index.js';
import { user as userTable } from '../db/schema.js';
import { apiError, requireAuth, type AppEnv } from '../http.js';
import { friendsAmong } from '../lib/friends.js';
import { hashPhone, normalizeE164 } from '../lib/hash.js';
import { toProfile } from '../lib/profile-mapper.js';
import { contactsByAccount, contactsByIp } from '../lib/rate-limit.js';

export const contactsRoutes = new Hono<AppEnv>();

contactsRoutes.use('*', requireAuth);

const MAX_BATCH = 1000;

contactsRoutes.post('/match', async (c) => {
  const me = c.get('user');

  const ip =
    c.req.header('x-forwarded-for')?.split(',')[0]?.trim() ||
    c.req.header('x-real-ip') ||
    'unknown';
  if (!contactsByAccount.check(`acct:${me.id}`) || !contactsByIp.check(`ip:${ip}`)) {
    apiError(429, 'rate_limited', 'Too many contact-match requests. Try again later.');
  }

  const body = await c.req.json().catch(() => ({}));
  const numbers: unknown = body.phoneNumbers;
  if (!Array.isArray(numbers)) {
    apiError(400, 'invalid_body', 'phoneNumbers must be an array of E.164 strings.');
  }
  if (numbers.length > MAX_BATCH) {
    apiError(400, 'batch_too_large', `At most ${MAX_BATCH} numbers per request.`);
  }

  // Hash in memory and match on phoneHash; the raw numbers are never stored.
  const hashes = new Set<string>();
  for (const n of numbers) {
    if (typeof n !== 'string') continue;
    // Normalize with the same function /me/discovery-phone uses, so the hashes line up.
    const e164 = normalizeE164(n);
    if (e164) hashes.add(hashPhone(e164));
  }
  if (hashes.size === 0) return c.json({ matches: [] });

  const rows = await db
    .select()
    .from(userTable)
    .where(
      and(
        inArray(userTable.phoneHash, [...hashes]),
        eq(userTable.discoverable, true),
      ),
    );

  const others = rows.filter((r) => r.id !== me.id);
  const friendIds = await friendsAmong(
    me.id,
    others.map((r) => r.id),
  );
  const matches = others.map((r) => toProfile(r, friendIds.has(r.id)));
  return c.json({ matches });
});
