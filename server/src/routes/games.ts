import { and, desc, eq, inArray, isNull, or } from 'drizzle-orm';
import { Hono } from 'hono';
import { db } from '../db/index.js';
import { game as gameTable, user as userTable } from '../db/schema.js';
import type { GameRow, UserRow } from '../db/schema.js';
import { apiError, requireAuth, type AppEnv } from '../http.js';
import { friendsAmong } from '../lib/friends.js';
import { toGame } from '../lib/game-logic.js';
import { colorOf, endGame, getGameRow, makeMove, MoveError } from '../lib/games-service.js';
import { notifyTurnIfCorrespondence } from '../push/notify.js';
import { emitGameOver, emitMove } from '../ws/broadcast.js';

export const gamesRoutes = new Hono<AppEnv>();

gamesRoutes.use('*', requireAuth);

async function dtoFor(rows: GameRow[], viewerId: string) {
  const playerIds = new Set<string>();
  for (const g of rows) {
    if (g.whiteId) playerIds.add(g.whiteId);
    if (g.blackId) playerIds.add(g.blackId);
  }
  const users = new Map<string, UserRow>();
  if (playerIds.size > 0) {
    const urows = await db.select().from(userTable).where(inArray(userTable.id, [...playerIds]));
    for (const u of urows) users.set(u.id, u);
  }
  const friendIds = await friendsAmong(viewerId, [...playerIds]);
  return rows.map((g) =>
    toGame(g, users.get(g.whiteId ?? '') ?? null, users.get(g.blackId ?? '') ?? null, friendIds),
  );
}

async function requireParticipantGame(viewerId: string, id: string): Promise<GameRow> {
  const g = await getGameRow(id);
  if (!g) apiError(404, 'not_found', 'Game not found.');
  if (!colorOf(g!, viewerId)) apiError(403, 'forbidden', 'You are not a player in this game.');
  return g!;
}

function mapMoveError(e: unknown): never {
  if (e instanceof MoveError) {
    const status =
      e.code === 'not_found'
        ? 404
        : e.code === 'forbidden'
          ? 403
          : e.code === 'illegal_move'
            ? 400
            : 409;
    apiError(status, e.code, e.message);
  }
  throw e;
}

gamesRoutes.get('/', async (c) => {
  const me = c.get('user');
  const status = c.req.query('status');
  const limit = Math.min(Number(c.req.query('limit') ?? 50) || 50, 100);

  const mine = or(eq(gameTable.whiteId, me.id), eq(gameTable.blackId, me.id));
  const where =
    status === 'active' || status === 'finished' || status === 'aborted'
      ? and(mine, eq(gameTable.status, status))
      : mine;

  const rows = await db
    .select()
    .from(gameTable)
    .where(where)
    .orderBy(desc(gameTable.updatedAt))
    .limit(limit);

  return c.json({ games: await dtoFor(rows, me.id) });
});

gamesRoutes.get('/:id', async (c) => {
  const me = c.get('user');
  const g = await requireParticipantGame(me.id, c.req.param('id'));
  const [dto] = await dtoFor([g], me.id);
  return c.json(dto);
});

gamesRoutes.post('/:id/move', async (c) => {
  const me = c.get('user');
  const id = c.req.param('id');
  const body = await c.req.json().catch(() => ({}));
  if (typeof body.uci !== 'string') apiError(400, 'invalid_body', 'uci is required.');

  let result;
  try {
    result = await makeMove(id, me.id, body.uci);
  } catch (e) {
    mapMoveError(e);
  }

  emitMove(result.game, result.move);
  if (result.outcome) {
    emitGameOver(result.game.id, result.outcome.result, result.outcome.termination);
  } else {
    notifyTurnIfCorrespondence(result.game);
  }

  const [dto] = await dtoFor([result.game], me.id);
  return c.json(dto);
});

// Shared Game Review: clients analyze on-device (non-deterministic across devices), so the first
// participant to open the review uploads it and everyone else downloads that one canonical copy.
gamesRoutes.get('/:id/review', async (c) => {
  const me = c.get('user');
  const g = await requireParticipantGame(me.id, c.req.param('id'));
  console.log(`[review] GET game=${g.id.slice(0, 8)} present=${g.review != null}`);
  return c.json({ review: g.review ?? null });
});

gamesRoutes.post('/:id/review', async (c) => {
  const me = c.get('user');
  const id = c.req.param('id');
  const g = await requireParticipantGame(me.id, id);
  console.log(
    `[review] POST game=${id.slice(0, 8)} user=${me.id.slice(0, 6)} status=${g.status} hadReview=${g.review != null}`,
  );
  if (g.status === 'active') apiError(409, 'conflict', 'Game is not finished.');

  const body = await c.req.json().catch(() => ({}));
  if (body.review == null || typeof body.review !== 'object') {
    apiError(400, 'invalid_body', 'A review object is required.');
  }

  // First-write-wins: only set when empty, so a simultaneous open by both players still converges on
  // one review. Re-read and return the stored copy so the caller always gets the canonical version.
  await db
    .update(gameTable)
    .set({ review: body.review })
    .where(and(eq(gameTable.id, id), isNull(gameTable.review)));
  const fresh = await getGameRow(id);
  return c.json({ review: fresh?.review ?? body.review });
});

gamesRoutes.post('/:id/resign', async (c) => {
  const me = c.get('user');
  const g = await requireParticipantGame(me.id, c.req.param('id'));
  if (g.status !== 'active') apiError(409, 'conflict', 'Game is not active.');

  const color = colorOf(g, me.id)!;
  const winner = color === 'white' ? 'black' : 'white';
  const updated = await endGame(g.id, winner, 'resignation');

  emitGameOver(updated.id, winner, 'resignation');
  const [dto] = await dtoFor([updated], me.id);
  return c.json(dto);
});

// Abort an active game that has no moves yet (e.g. a player backs out before move one). Unlike a
// resignation there's no winner and no rating change; the opponent just sees "Game aborted".
gamesRoutes.post('/:id/abort', async (c) => {
  const me = c.get('user');
  const g = await requireParticipantGame(me.id, c.req.param('id'));
  if (g.status !== 'active') apiError(409, 'conflict', 'Game is not active.');
  if (g.movesUci.length > 0) apiError(409, 'has_moves', 'Game already has moves; resign instead.');

  const updated = await endGame(g.id, 'draw', 'aborted', { aborted: true });
  emitGameOver(updated.id, null, 'aborted');
  const [dto] = await dtoFor([updated], me.id);
  return c.json(dto);
});
