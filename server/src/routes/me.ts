import { randomInt, randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { and, eq } from 'drizzle-orm';
import { Hono } from 'hono';
import { db } from '../db/index.js';
import {
  deviceToken as deviceTokenTable,
  user as userTable,
  verification as verificationTable,
} from '../db/schema.js';
import { env } from '../env.js';
import { apiError, requireAuth, type AppEnv } from '../http.js';
import { hashPhone, normalizeE164 } from '../lib/hash.js';
import { selfProfile } from '../lib/profile-mapper.js';
import { sendEmailChangeCode } from '../lib/resend.js';
import { afterPlay } from '../lib/streak.js';

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export const meRoutes = new Hono<AppEnv>();

meRoutes.use('*', requireAuth);

meRoutes.get('/', (c) => c.json(selfProfile(c.get('user'))));

meRoutes.patch('/', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));

  const patch: Partial<typeof userTable.$inferInsert> = {};

  if (typeof body.username === 'string') {
    const username = body.username.toLowerCase().trim();
    if (!/^[a-z0-9_.]{2,20}$/.test(username)) {
      apiError(400, 'invalid_username', 'Username must be 2–20 chars of [a-z0-9_.].');
    }
    patch.username = username;
    patch.displayUsername = body.username.trim();
  }

  if (typeof body.displayName === 'string') {
    patch.displayName = body.displayName.trim().slice(0, 60) || null;
  }

  if (typeof body.avatarColor === 'string') {
    if (!/^#[0-9a-fA-F]{6}$/.test(body.avatarColor)) {
      apiError(400, 'invalid_color', 'avatarColor must be a #RRGGBB hex string.');
    }
    patch.avatarColor = body.avatarColor;
  }

  if (typeof body.discoverable === 'boolean') {
    patch.discoverable = body.discoverable;
  }

  if (Object.keys(patch).length === 0) {
    return c.json(selfProfile(me));
  }
  patch.updatedAt = new Date();

  try {
    const [updated] = await db
      .update(userTable)
      .set(patch)
      .where(eq(userTable.id, me.id))
      .returning();
    return c.json(selfProfile(updated!));
  } catch (err) {
    // A lower(username) unique violation surfaces as a friendly 409.
    if (err instanceof Error && /unique|duplicate/i.test(err.message)) {
      apiError(409, 'username_taken', 'That username is already taken.');
    }
    throw err;
  }
});

meRoutes.post('/discovery-phone', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));

  if (typeof body.phoneNumber !== 'string') {
    apiError(400, 'invalid_body', 'phoneNumber is required.');
  }
  // `region` (e.g. "US") lets a national-format number resolve its country code; same parse as /contacts/match.
  const region = typeof body.region === 'string' ? body.region : null;
  const e164 = normalizeE164(body.phoneNumber, region);
  if (!e164) {
    apiError(400, 'invalid_phone', 'Enter a valid phone number, including the area code.');
  }

  const phoneHash = hashPhone(e164);
  try {
    const [updated] = await db
      .update(userTable)
      .set({ phoneHash, discoverable: true, updatedAt: new Date() })
      .where(eq(userTable.id, me.id))
      .returning();
    return c.json(selfProfile(updated!));
  } catch (err) {
    // A phoneHash unique violation means another account already claims this number.
    if (err instanceof Error && /unique|duplicate/i.test(err.message)) {
      apiError(409, 'phone_in_use', 'That phone number is already linked to another account.');
    }
    throw err;
  }
});

meRoutes.delete('/discovery-phone', async (c) => {
  const me = c.get('user');
  const [updated] = await db
    .update(userTable)
    .set({ phoneHash: null, discoverable: false, updatedAt: new Date() })
    .where(eq(userTable.id, me.id))
    .returning();
  return c.json(selfProfile(updated!));
});

// The client pings this whenever it plays a game (any mode) so the server can track the streak that
// friends see. Server time decides the day boundary, so the count can rise by at most 1 per day.
meRoutes.post('/played', async (c) => {
  const me = c.get('user');
  const r = afterPlay(me.streakCount, me.streakLastPlayedAt, new Date());
  const [updated] = await db
    .update(userTable)
    .set({ streakCount: r.count, streakLastPlayedAt: r.lastPlayed, updatedAt: new Date() })
    .where(eq(userTable.id, me.id))
    .returning();
  return c.json(selfProfile(updated!));
});

meRoutes.post('/push-token', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));

  const token = typeof body.token === 'string' ? body.token.trim() : '';
  if (!/^[0-9a-fA-F]{16,256}$/.test(token)) {
    apiError(400, 'invalid_token', 'A hex APNs device token is required.');
  }
  const environment = body.environment === 'sandbox' ? 'sandbox' : 'production';
  const platform = typeof body.platform === 'string' ? body.platform.slice(0, 16) : 'ios';

  // Upsert by token so a device that switches accounts re-points to the latest signer.
  await db
    .insert(deviceTokenTable)
    .values({ userId: me.id, token, environment, platform })
    .onConflictDoUpdate({
      target: deviceTokenTable.token,
      set: { userId: me.id, environment, platform, updatedAt: new Date() },
    });

  return c.json({ ok: true });
});

meRoutes.delete('/push-token', async (c) => {
  const me = c.get('user');
  const token = c.req.query('token');
  if (token) {
    await db
      .delete(deviceTokenTable)
      .where(and(eq(deviceTokenTable.token, token), eq(deviceTokenTable.userId, me.id)));
  } else {
    await db.delete(deviceTokenTable).where(eq(deviceTokenTable.userId, me.id));
  }
  return c.json({ ok: true });
});

meRoutes.post('/avatar', async (c) => {
  const me = c.get('user');
  const buf = Buffer.from(await c.req.arrayBuffer());

  if (buf.length === 0) apiError(400, 'empty', 'No image data.');
  if (buf.length > 2_000_000) apiError(413, 'too_large', 'Image must be under 2 MB.');

  const isJpeg = buf[0] === 0xff && buf[1] === 0xd8;
  const isPng =
    buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47;
  if (!isJpeg && !isPng) apiError(400, 'bad_type', 'Image must be a JPEG or PNG.');

  const ext = isPng ? 'png' : 'jpg';
  await mkdir(env.uploadDir, { recursive: true });
  await writeFile(path.join(env.uploadDir, `${me.id}.${ext}`), buf);

  const url = `${env.appBaseUrl}/uploads/${me.id}.${ext}?v=${Date.now()}`;
  const [updated] = await db
    .update(userTable)
    .set({ image: url, updatedAt: new Date() })
    .where(eq(userTable.id, me.id))
    .returning();
  return c.json(selfProfile(updated!));
});

meRoutes.delete('/avatar', async (c) => {
  const me = c.get('user');
  const [updated] = await db
    .update(userTable)
    .set({ image: null, updatedAt: new Date() })
    .where(eq(userTable.id, me.id))
    .returning();
  return c.json(selfProfile(updated!));
});

meRoutes.post('/email/start', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));
  const newEmail = typeof body.newEmail === 'string' ? body.newEmail.trim().toLowerCase() : '';

  if (!EMAIL_RE.test(newEmail)) apiError(400, 'invalid_email', 'Enter a valid email.');
  if (newEmail === me.email.toLowerCase()) apiError(400, 'same_email', 'That is already your email.');

  const taken = await db.select().from(userTable).where(eq(userTable.email, newEmail)).limit(1);
  if (taken[0] && taken[0].id !== me.id) apiError(409, 'email_in_use', 'That email is already in use.');

  const otp = String(randomInt(100000, 1000000));
  const identifier = `change-email:${me.id}`;
  // Stash the pending change as "<otp>:<newEmail>" in the verification table until step 2 commits it.
  await db.delete(verificationTable).where(eq(verificationTable.identifier, identifier));
  await db.insert(verificationTable).values({
    id: randomUUID(),
    identifier,
    value: `${otp}:${newEmail}`,
    expiresAt: new Date(Date.now() + 10 * 60 * 1000),
  });
  sendEmailChangeCode(newEmail, otp);
  return c.json({ ok: true });
});

meRoutes.post('/email/verify', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));
  const otp = typeof body.otp === 'string' ? body.otp.trim() : '';
  const identifier = `change-email:${me.id}`;

  const rows = await db
    .select()
    .from(verificationTable)
    .where(eq(verificationTable.identifier, identifier))
    .limit(1);
  const rec = rows[0];
  if (!rec || rec.expiresAt.getTime() < Date.now()) {
    apiError(400, 'otp_expired', 'That code has expired. Request a new one.');
  }
  const sep = rec!.value.indexOf(':');
  const recOtp = rec!.value.slice(0, sep);
  const newEmail = rec!.value.slice(sep + 1);
  if (!otp || otp !== recOtp) apiError(400, 'invalid_otp', 'Wrong code.');

  const taken = await db.select().from(userTable).where(eq(userTable.email, newEmail)).limit(1);
  if (taken[0] && taken[0].id !== me.id) {
    await db.delete(verificationTable).where(eq(verificationTable.identifier, identifier));
    apiError(409, 'email_in_use', 'That email is already in use.');
  }

  const [updated] = await db
    .update(userTable)
    .set({ email: newEmail, emailVerified: true, updatedAt: new Date() })
    .where(eq(userTable.id, me.id))
    .returning();
  await db.delete(verificationTable).where(eq(verificationTable.identifier, identifier));
  return c.json(selfProfile(updated!));
});
