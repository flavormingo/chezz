import { and, eq } from 'drizzle-orm';
import { db } from '../db/index.js';
import { game as gameTable, user as userTable } from '../db/schema.js';
import type { GameResult, GameRow, Termination, UserRow } from '../db/schema.js';
import {
  applyMove,
  chessFromMoves,
  debitClock,
  detectOutcome,
  eloUpdate,
  pgnFor,
  turnFor,
  type AppliedMove,
} from './game-logic.js';

export async function getGameRow(id: string): Promise<GameRow | null> {
  const rows = await db.select().from(gameTable).where(eq(gameTable.id, id)).limit(1);
  return rows[0] ?? null;
}

export async function getUserRow(id: string | null): Promise<UserRow | null> {
  if (!id) return null;
  const rows = await db.select().from(userTable).where(eq(userTable.id, id)).limit(1);
  return rows[0] ?? null;
}

export function colorOf(g: GameRow, userId: string): 'white' | 'black' | null {
  if (g.whiteId === userId) return 'white';
  if (g.blackId === userId) return 'black';
  return null;
}

export class MoveError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export interface MoveResult {
  game: GameRow;
  move: AppliedMove;
  outcome: { result: GameResult; termination: Termination } | null;
}

export async function makeMove(id: string, userId: string, uci: string): Promise<MoveResult> {
  const g = await getGameRow(id);
  if (!g) throw new MoveError('not_found', 'Game not found.');
  if (g.status !== 'active') throw new MoveError('conflict', 'Game is not active.');

  const color = colorOf(g, userId);
  if (!color) throw new MoveError('forbidden', 'You are not a player in this game.');

  const turn = turnFor(g.movesUci);
  if (turn !== color) throw new MoveError('conflict', 'Not your turn.');

  let applied: AppliedMove;
  try {
    applied = applyMove(g.movesUci, uci);
  } catch {
    throw new MoveError('illegal_move', 'Illegal move.');
  }

  const now = Date.now();
  const movesUci = [...g.movesUci, uci];

  let whiteTimeMs = g.whiteTimeMs;
  let blackTimeMs = g.blackTimeMs;
  if (g.kind === 'live' && whiteTimeMs != null && blackTimeMs != null) {
    const debited = debitClock({
      mover: color,
      whiteTimeMs,
      blackTimeMs,
      lastMoveAt: g.lastMoveAt,
      incrementSeconds: g.timeControl?.incrementSeconds ?? 0,
      now,
    });
    whiteTimeMs = debited.whiteTimeMs;
    blackTimeMs = debited.blackTimeMs;
  }

  const chess = chessFromMoves(movesUci);
  const outcome = detectOutcome(chess);

  const patch: Partial<GameRow> = {
    movesUci,
    whiteTimeMs,
    blackTimeMs,
    lastMoveAt: new Date(now),
    updatedAt: new Date(now),
  };

  if (outcome) {
    patch.status = 'finished';
    patch.result = outcome.result;
    patch.termination = outcome.termination;
    patch.pgn = pgnFor(movesUci);
    patch.finishedAt = new Date(now);
  }

  const [updated] = await db
    .update(gameTable)
    .set(patch)
    .where(and(eq(gameTable.id, id), eq(gameTable.status, 'active')))
    .returning();
  if (!updated) throw new MoveError('conflict', 'Game is not active.');

  if (outcome) await applyEloIfNeeded(updated, outcome.result);

  return { game: updated, move: applied, outcome };
}

export async function endGame(
  id: string,
  result: GameResult,
  termination: Termination,
  opts: { aborted?: boolean } = {},
): Promise<GameRow> {
  const g = await getGameRow(id);
  if (!g) throw new MoveError('not_found', 'Game not found.');
  if (g.status !== 'active') return g; // idempotent: already finished.

  const now = new Date();
  const [updated] = await db
    .update(gameTable)
    .set({
      status: opts.aborted ? 'aborted' : 'finished',
      result: opts.aborted ? null : result,
      termination,
      pgn: pgnFor(g.movesUci),
      finishedAt: now,
      updatedAt: now,
    })
    // Status guard so only one finisher wins the row (resign vs clock-sweep vs double-tap).
    .where(and(eq(gameTable.id, id), eq(gameTable.status, 'active')))
    .returning();

  if (!updated) return (await getGameRow(id)) ?? g; // lost the race; already finalized elsewhere.
  if (!opts.aborted) await applyEloIfNeeded(updated, result);
  return updated;
}

async function applyEloIfNeeded(g: GameRow, result: GameResult): Promise<void> {
  const white = await getUserRow(g.whiteId);
  const black = await getUserRow(g.blackId);
  if (!white || !black) return;

  const next = eloUpdate(g, white, black, result);
  if (!next) return;

  await Promise.all([
    db.update(userTable).set({ rating: next.white }).where(eq(userTable.id, white.id)),
    db.update(userTable).set({ rating: next.black }).where(eq(userTable.id, black.id)),
  ]);
}
