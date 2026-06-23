import { and, ne, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { db } from '../db/index.js';
import { user as userTable } from '../db/schema.js';
import { requireAuth, type AppEnv } from '../http.js';
import { friendsAmong } from '../lib/friends.js';
import { toProfile } from '../lib/profile-mapper.js';

export const usersRoutes = new Hono<AppEnv>();

usersRoutes.use('*', requireAuth);

const MAX_RESULTS = 25;

usersRoutes.get('/search', async (c) => {
  const me = c.get('user');
  const q = (c.req.query('q') ?? '').toLowerCase().trim();

  if (q.length === 0) return c.json({ results: [] });

  // Escape LIKE wildcards so user input can't inject % or _ patterns.
  const prefix = q.replace(/[%_\\]/g, (ch) => `\\${ch}`);

  const rows = await db
    .select()
    .from(userTable)
    .where(
      and(
        ne(userTable.id, me.id),
        sql`lower(${userTable.username}) LIKE ${prefix + '%'} ESCAPE '\\'`,
      ),
    )
    .orderBy(sql`lower(${userTable.username})`)
    .limit(MAX_RESULTS);

  const friendIds = await friendsAmong(
    me.id,
    rows.map((r) => r.id),
  );
  const results = rows.map((r) => toProfile(r, friendIds.has(r.id)));
  return c.json({ results });
});
