import { friendsAmong } from '../lib/friends.js';
import type { AppliedMove } from '../lib/game-logic.js';
import { toGame } from '../lib/game-logic.js';
import type { GameResult, GameRow, Termination } from '../db/schema.js';
import { getUserRow } from '../lib/games-service.js';
import { broadcastGame } from './hub.js';

// viewerId is null on broadcasts, so isFriend is false; clients recompute friendship locally.
export async function buildGameDTO(g: GameRow, viewerId: string | null) {
  const white = await getUserRow(g.whiteId);
  const black = await getUserRow(g.blackId);
  const candidateIds = [white?.id, black?.id].filter((x): x is string => !!x);
  const friendIds = viewerId ? await friendsAmong(viewerId, candidateIds) : new Set<string>();
  return toGame(g, white, black, friendIds);
}

export function emitMove(g: GameRow, move: AppliedMove): void {
  broadcastGame(g.id, {
    type: 'move',
    gameId: g.id,
    uci: move.uci,
    san: move.san,
    fen: move.fen,
    turn: move.turn,
    whiteTimeMs: g.whiteTimeMs,
    blackTimeMs: g.blackTimeMs,
  });
}

export function emitGameOver(
  gameId: string,
  result: GameResult | null,
  termination: Termination,
): void {
  broadcastGame(gameId, { type: 'gameOver', gameId, result, termination });
}
