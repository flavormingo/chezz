import { and, eq, inArray, or } from 'drizzle-orm';
import { Hono } from 'hono';
import { db } from '../db/index.js';
import {
  challenge as challengeTable,
  game as gameTable,
  user as userTable,
} from '../db/schema.js';
import type { ChallengeRow, TimeControl, UserRow } from '../db/schema.js';
import { apiError, requireAuth, type AppContext, type AppEnv } from '../http.js';
import { areFriends } from '../lib/friends.js';
import { toProfile, type Profile } from '../lib/profile-mapper.js';
import { notifyChallengeAccepted, notifyChallengeReceived, displayNameOf } from '../push/notify.js';
import { pushToUser } from '../ws/hub.js';

export const challengesRoutes = new Hono<AppEnv>();

challengesRoutes.use('*', requireAuth);

interface ChallengeDTO {
  id: string;
  from: Profile;
  to: Profile;
  kind: 'live' | 'correspondence';
  timeControl: TimeControl | null;
  color: 'white' | 'black' | 'random';
  status: 'pending';
  gameId: string | null;
  createdAt: string;
}

async function usersByIds(ids: string[]): Promise<Map<string, UserRow>> {
  const map = new Map<string, UserRow>();
  if (ids.length === 0) return map;
  const rows = await db.select().from(userTable).where(inArray(userTable.id, ids));
  for (const r of rows) map.set(r.id, r);
  return map;
}

function toChallengeDTO(r: ChallengeRow, from: UserRow, to: UserRow): ChallengeDTO {
  return {
    id: r.id,
    from: toProfile(from, false),
    to: toProfile(to, false),
    kind: r.kind as 'live' | 'correspondence',
    timeControl: r.timeControl,
    color: r.color as 'white' | 'black' | 'random',
    status: 'pending',
    gameId: r.gameId,
    createdAt: r.createdAt.toISOString(),
  };
}

challengesRoutes.post('/', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));

  const toUserId = body.toUserId;
  const kind = body.kind;
  const color = body.color;
  const timeControl: TimeControl | null = body.timeControl ?? null;

  if (typeof toUserId !== 'string') apiError(400, 'invalid_body', 'toUserId is required.');
  if (toUserId === me.id) apiError(400, 'invalid_target', 'You cannot challenge yourself.');
  if (kind !== 'live' && kind !== 'correspondence') {
    apiError(400, 'invalid_kind', 'kind must be "live" or "correspondence".');
  }
  if (color !== 'white' && color !== 'black' && color !== 'random') {
    apiError(400, 'invalid_color', 'color must be "white", "black" or "random".');
  }

  if (kind === 'live') {
    if (
      !timeControl ||
      typeof timeControl.initialSeconds !== 'number' ||
      typeof timeControl.incrementSeconds !== 'number' ||
      timeControl.initialSeconds < 60 ||
      timeControl.initialSeconds > 3600 ||
      timeControl.incrementSeconds < 0 ||
      timeControl.incrementSeconds > 180
    ) {
      apiError(400, 'invalid_time_control', 'Live games need initialSeconds 60–3600 + increment.');
    }
  } else if (timeControl !== null) {
    apiError(400, 'invalid_time_control', 'Correspondence games must have timeControl: null.');
  }

  if (!(await areFriends(me.id, toUserId))) {
    apiError(403, 'not_friends', 'You can only challenge friends.');
  }

  const target = (await usersByIds([toUserId])).get(toUserId);
  if (!target) apiError(404, 'not_found', 'User not found.');

  const [row] = await db
    .insert(challengeTable)
    .values({
      fromUserId: me.id,
      toUserId,
      kind,
      timeControl: kind === 'live' ? timeControl : null,
      color,
      status: 'pending',
    })
    .returning();

  const dto = toChallengeDTO(row!, me, target!);

  pushToUser(toUserId, { type: 'challengeReceived', challenge: dto });
  notifyChallengeReceived(toUserId, displayNameOf(me), kind);

  return c.json(dto);
});

challengesRoutes.get('/', async (c) => {
  const me = c.get('user');
  const rows = await db
    .select()
    .from(challengeTable)
    .where(
      and(
        eq(challengeTable.status, 'pending'),
        or(eq(challengeTable.toUserId, me.id), eq(challengeTable.fromUserId, me.id)),
      ),
    );

  const ids = new Set<string>();
  for (const r of rows) {
    ids.add(r.fromUserId);
    ids.add(r.toUserId);
  }
  const users = await usersByIds([...ids]);

  const dto = (r: ChallengeRow): ChallengeDTO | null => {
    const from = users.get(r.fromUserId);
    const to = users.get(r.toUserId);
    return from && to ? toChallengeDTO(r, from, to) : null;
  };

  const incoming = rows
    .filter((r) => r.toUserId === me.id)
    .map(dto)
    .filter((x): x is ChallengeDTO => !!x);
  const outgoing = rows
    .filter((r) => r.fromUserId === me.id)
    .map(dto)
    .filter((x): x is ChallengeDTO => !!x);

  return c.json({ incoming, outgoing });
});

challengesRoutes.post('/:id/accept', async (c) => {
  const me = c.get('user');
  const id = c.req.param('id');

  const rows = await db.select().from(challengeTable).where(eq(challengeTable.id, id)).limit(1);
  const ch = rows[0];
  if (!ch || ch.status !== 'pending') apiError(404, 'not_found', 'Challenge not found.');
  if (ch!.toUserId !== me.id) apiError(403, 'forbidden', 'Not your challenge to accept.');

  // The challenge color is from the challenger's perspective.
  let challengerWhite: boolean;
  if (ch!.color === 'white') challengerWhite = true;
  else if (ch!.color === 'black') challengerWhite = false;
  else challengerWhite = Math.random() < 0.5;

  const whiteId = challengerWhite ? ch!.fromUserId : ch!.toUserId;
  const blackId = challengerWhite ? ch!.toUserId : ch!.fromUserId;

  const initialMs =
    ch!.kind === 'live' && ch!.timeControl ? ch!.timeControl.initialSeconds * 1000 : null;

  const [createdGame] = await db
    .insert(gameTable)
    .values({
      kind: ch!.kind,
      whiteId,
      blackId,
      timeControl: ch!.timeControl,
      rated: true,
      status: 'active',
      whiteTimeMs: initialMs,
      blackTimeMs: initialMs,
      // No lastMoveAt yet: white's clock starts on their first move.
    })
    .returning();

  await db
    .update(challengeTable)
    .set({ status: 'accepted', gameId: createdGame!.id })
    .where(eq(challengeTable.id, id));

  notifyChallengeAccepted(ch!.fromUserId, displayNameOf(me), createdGame!.id);

  return c.json({ gameId: createdGame!.id });
});

async function closeChallenge(c: AppContext, mode: 'declined' | 'cancelled') {
  const me = c.get('user');
  const id = c.req.param('id')!;
  const rows = await db.select().from(challengeTable).where(eq(challengeTable.id, id)).limit(1);
  const ch = rows[0];
  if (!ch || ch.status !== 'pending') apiError(404, 'not_found', 'Challenge not found.');

  // decline = recipient closes; cancel = sender closes.
  if (mode === 'declined' && ch!.toUserId !== me.id) {
    apiError(403, 'forbidden', 'Not your challenge to decline.');
  }
  if (mode === 'cancelled' && ch!.fromUserId !== me.id) {
    apiError(403, 'forbidden', 'Not your challenge to cancel.');
  }

  await db.update(challengeTable).set({ status: mode }).where(eq(challengeTable.id, id));
  return c.json({ ok: true });
}

challengesRoutes.post('/:id/decline', (c) => closeChallenge(c, 'declined'));
challengesRoutes.post('/:id/cancel', (c) => closeChallenge(c, 'cancelled'));
