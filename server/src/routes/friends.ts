import { and, eq, inArray, or } from 'drizzle-orm';
import { Hono } from 'hono';
import { db } from '../db/index.js';
import { friendRequest, friendship, user as userTable } from '../db/schema.js';
import type { FriendRequestRow, UserRow } from '../db/schema.js';
import { apiError, requireAuth, type AppEnv } from '../http.js';
import { areFriends, friendIdsOf, orderPair } from '../lib/friends.js';
import { toProfile, type Profile } from '../lib/profile-mapper.js';

export const friendsRoutes = new Hono<AppEnv>();

friendsRoutes.use('*', requireAuth);

interface FriendRequestDTO {
  id: string;
  from: Profile;
  to: Profile;
  status: 'pending';
  createdAt: string;
}

async function usersByIds(ids: string[]): Promise<Map<string, UserRow>> {
  const map = new Map<string, UserRow>();
  if (ids.length === 0) return map;
  const rows = await db.select().from(userTable).where(inArray(userTable.id, ids));
  for (const r of rows) map.set(r.id, r);
  return map;
}

friendsRoutes.get('/', async (c) => {
  const me = c.get('user');
  const ids = [...(await friendIdsOf(me.id))];
  const users = await usersByIds(ids);
  const friends = ids
    .map((id) => users.get(id))
    .filter((u): u is UserRow => !!u)
    .map((u) => toProfile(u, true));
  return c.json({ friends });
});

friendsRoutes.get('/requests', async (c) => {
  const me = c.get('user');
  const rows = await db
    .select()
    .from(friendRequest)
    .where(
      and(
        eq(friendRequest.status, 'pending'),
        or(eq(friendRequest.toUserId, me.id), eq(friendRequest.fromUserId, me.id)),
      ),
    );

  const otherIds = new Set<string>();
  for (const r of rows) {
    otherIds.add(r.fromUserId);
    otherIds.add(r.toUserId);
  }
  const users = await usersByIds([...otherIds]);

  const dto = (r: FriendRequestRow): FriendRequestDTO | null => {
    const from = users.get(r.fromUserId);
    const to = users.get(r.toUserId);
    if (!from || !to) return null;
    return {
      id: r.id,
      from: toProfile(from, false),
      to: toProfile(to, false),
      status: 'pending',
      createdAt: r.createdAt.toISOString(),
    };
  };

  const incoming = rows
    .filter((r) => r.toUserId === me.id)
    .map(dto)
    .filter((x): x is FriendRequestDTO => !!x);
  const outgoing = rows
    .filter((r) => r.fromUserId === me.id)
    .map(dto)
    .filter((x): x is FriendRequestDTO => !!x);

  return c.json({ incoming, outgoing });
});

friendsRoutes.post('/requests', async (c) => {
  const me = c.get('user');
  const body = await c.req.json().catch(() => ({}));
  const toUserId = body.toUserId;
  if (typeof toUserId !== 'string') {
    apiError(400, 'invalid_body', 'toUserId is required.');
  }
  if (toUserId === me.id) {
    apiError(400, 'invalid_target', 'You cannot friend yourself.');
  }

  const target = (await usersByIds([toUserId])).get(toUserId);
  if (!target) apiError(404, 'not_found', 'User not found.');

  if (await areFriends(me.id, toUserId)) {
    apiError(409, 'already_friends', 'You are already friends.');
  }

  // If they already have a pending request to me, accept it instead of duplicating in reverse.
  const reciprocal = await db
    .select()
    .from(friendRequest)
    .where(
      and(
        eq(friendRequest.fromUserId, toUserId),
        eq(friendRequest.toUserId, me.id),
        eq(friendRequest.status, 'pending'),
      ),
    )
    .limit(1);
  if (reciprocal[0]) {
    await acceptRequest(reciprocal[0]);
    // They're now friends; don't fall through and create a stale outgoing request.
    return c.json({
      id: reciprocal[0].id,
      from: toProfile(me, false),
      to: toProfile(target!, false),
      status: 'accepted' as const,
      createdAt: reciprocal[0].createdAt.toISOString(),
    });
  }

  const existing = await db
    .select()
    .from(friendRequest)
    .where(
      and(
        eq(friendRequest.fromUserId, me.id),
        eq(friendRequest.toUserId, toUserId),
        eq(friendRequest.status, 'pending'),
      ),
    )
    .limit(1);

  const row =
    existing[0] ??
    (
      await db
        .insert(friendRequest)
        .values({ fromUserId: me.id, toUserId, status: 'pending' })
        .returning()
    )[0]!;

  return c.json({
    id: row.id,
    from: toProfile(me, false),
    to: toProfile(target!, false),
    status: 'pending' as const,
    createdAt: row.createdAt.toISOString(),
  });
});

friendsRoutes.post('/requests/:id/accept', async (c) => {
  const me = c.get('user');
  const id = c.req.param('id');
  const rows = await db.select().from(friendRequest).where(eq(friendRequest.id, id)).limit(1);
  const req = rows[0];
  if (!req || req.status !== 'pending') apiError(404, 'not_found', 'Request not found.');
  if (req!.toUserId !== me.id) apiError(403, 'forbidden', 'Not your request to accept.');

  await acceptRequest(req!);
  return c.json({ ok: true });
});

friendsRoutes.post('/requests/:id/decline', async (c) => {
  const me = c.get('user');
  const id = c.req.param('id');
  const rows = await db.select().from(friendRequest).where(eq(friendRequest.id, id)).limit(1);
  const req = rows[0];
  if (!req || req.status !== 'pending') apiError(404, 'not_found', 'Request not found.');
  // Either party may cancel/decline their own pending request.
  if (req!.toUserId !== me.id && req!.fromUserId !== me.id) {
    apiError(403, 'forbidden', 'Not your request.');
  }
  await db
    .update(friendRequest)
    .set({ status: 'declined' })
    .where(eq(friendRequest.id, id));
  return c.json({ ok: true });
});

friendsRoutes.delete('/:userId', async (c) => {
  const me = c.get('user');
  const { userA, userB } = orderPair(me.id, c.req.param('userId'));
  await db
    .delete(friendship)
    .where(and(eq(friendship.userA, userA), eq(friendship.userB, userB)));
  return c.json({ ok: true });
});

async function acceptRequest(req: FriendRequestRow): Promise<void> {
  await db
    .update(friendRequest)
    .set({ status: 'accepted' })
    .where(eq(friendRequest.id, req.id));

  const { userA, userB } = orderPair(req.fromUserId, req.toUserId);
  await db
    .insert(friendship)
    .values({ userA, userB })
    .onConflictDoNothing({ target: [friendship.userA, friendship.userB] });
}
