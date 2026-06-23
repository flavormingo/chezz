import { Chess } from 'chess.js';
import { updateElo } from './elo.js';
import { toProfile, type Profile } from './profile-mapper.js';
import type {
  GameResult,
  GameRow,
  TimeControl,
  Termination,
  UserRow,
} from '../db/schema.js';

export interface Game {
  id: string;
  kind: 'live' | 'correspondence';
  white: Profile | null;
  black: Profile | null;
  timeControl: TimeControl | null;
  status: 'active' | 'finished' | 'aborted';
  result: GameResult | null;
  termination: Termination | null;
  movesUci: string[];
  pgn: string;
  fen: string;
  turn: 'white' | 'black';
  whiteTimeMs: number | null;
  blackTimeMs: number | null;
  createdAt: string;
  updatedAt: string;
  finishedAt: string | null;
}

export function chessFromMoves(movesUci: string[]): Chess {
  const chess = new Chess();
  for (const uci of movesUci) {
    chess.move(uciToMoveInput(uci));
  }
  return chess;
}

function uciToMoveInput(uci: string): { from: string; to: string; promotion?: string } {
  const from = uci.slice(0, 2);
  const to = uci.slice(2, 4);
  const promotion = uci.length > 4 ? uci[4] : undefined;
  return promotion ? { from, to, promotion } : { from, to };
}

export interface AppliedMove {
  uci: string;
  san: string;
  fen: string;
  turn: 'white' | 'black';
}

export function applyMove(movesUci: string[], uci: string): AppliedMove {
  const chess = chessFromMoves(movesUci);
  let move;
  try {
    move = chess.move(uciToMoveInput(uci));
  } catch {
    throw new Error('illegal move');
  }
  if (!move) throw new Error('illegal move');
  return {
    uci,
    san: move.san,
    fen: chess.fen(),
    turn: chess.turn() === 'w' ? 'white' : 'black',
  };
}

export interface Outcome {
  result: GameResult;
  termination: Termination;
}

export function detectOutcome(chess: Chess): Outcome | null {
  if (chess.isCheckmate()) {
    // Side to move is checkmated, so the other side won.
    return { result: chess.turn() === 'w' ? 'black' : 'white', termination: 'checkmate' };
  }
  if (chess.isStalemate()) return { result: 'draw', termination: 'stalemate' };
  if (chess.isInsufficientMaterial()) return { result: 'draw', termination: 'insufficient' };
  if (chess.isThreefoldRepetition()) return { result: 'draw', termination: 'repetition' };
  if (chess.isDrawByFiftyMoves()) return { result: 'draw', termination: 'fiftyMove' };
  // Catch-all draw (the specific cases above are handled first).
  if (chess.isDraw()) return { result: 'draw', termination: 'fiftyMove' };
  return null;
}

export function turnFor(movesUci: string[]): 'white' | 'black' {
  return chessFromMoves(movesUci).turn() === 'w' ? 'white' : 'black';
}

export function pgnFor(movesUci: string[]): string {
  return chessFromMoves(movesUci).pgn();
}

export function debitClock(args: {
  mover: 'white' | 'black';
  whiteTimeMs: number;
  blackTimeMs: number;
  lastMoveAt: Date | null;
  incrementSeconds: number;
  now?: number;
}): { whiteTimeMs: number; blackTimeMs: number } {
  const now = args.now ?? Date.now();
  const elapsed = args.lastMoveAt ? now - args.lastMoveAt.getTime() : 0;
  const incMs = args.incrementSeconds * 1000;

  let { whiteTimeMs, blackTimeMs } = args;
  if (args.mover === 'white') {
    whiteTimeMs = Math.max(0, whiteTimeMs - elapsed) + incMs;
  } else {
    blackTimeMs = Math.max(0, blackTimeMs - elapsed) + incMs;
  }
  return { whiteTimeMs, blackTimeMs };
}

export function remainingForSideToMove(g: GameRow, now = Date.now()): number | null {
  if (g.kind !== 'live' || g.whiteTimeMs == null || g.blackTimeMs == null) return null;
  const turn = turnFor(g.movesUci);
  const base = turn === 'white' ? g.whiteTimeMs : g.blackTimeMs;
  const elapsed = g.lastMoveAt ? now - g.lastMoveAt.getTime() : 0;
  return Math.max(0, base - elapsed);
}

export function eloUpdate(
  g: GameRow,
  white: UserRow,
  black: UserRow,
  result: GameResult,
): { white: number; black: number } | null {
  if (!g.rated) return null;
  return updateElo(white.rating, black.rating, result);
}

export function toGame(
  g: GameRow,
  white: UserRow | null,
  black: UserRow | null,
  friendIds: Set<string>,
): Game {
  const chess = chessFromMoves(g.movesUci);
  return {
    id: g.id,
    kind: g.kind as 'live' | 'correspondence',
    white: white ? toProfile(white, friendIds.has(white.id)) : null,
    black: black ? toProfile(black, friendIds.has(black.id)) : null,
    timeControl: g.timeControl,
    status: g.status as Game['status'],
    result: g.result,
    termination: g.termination,
    movesUci: g.movesUci,
    pgn: g.pgn,
    fen: chess.fen(),
    turn: chess.turn() === 'w' ? 'white' : 'black',
    whiteTimeMs: g.whiteTimeMs,
    blackTimeMs: g.blackTimeMs,
    createdAt: g.createdAt.toISOString(),
    updatedAt: g.updatedAt.toISOString(),
    finishedAt: g.finishedAt ? g.finishedAt.toISOString() : null,
  };
}
