import type { GameRow } from '../db/schema.js';
import {
  colorOf,
  endGame,
  getGameRow,
  makeMove,
  MoveError,
} from '../lib/games-service.js';
import { notifyTurnIfCorrespondence } from '../push/notify.js';
import { buildGameDTO, emitGameOver, emitMove } from './broadcast.js';
import { joinGame, sendTo, type Conn } from './hub.js';

interface IncomingMessage {
  type?: string;
  gameId?: string;
  uci?: string;
}

function err(conn: Conn, message: string): void {
  sendTo(conn, { type: 'error', message });
}

async function loadPlayableGame(conn: Conn, gameId: string | undefined): Promise<GameRow | null> {
  if (!gameId) {
    err(conn, 'gameId required');
    return null;
  }
  const g = await getGameRow(gameId);
  if (!g) {
    err(conn, 'Game not found');
    return null;
  }
  if (!colorOf(g, conn.userId)) {
    err(conn, 'You are not a player in this game');
    return null;
  }
  return g;
}

export async function handleMessage(conn: Conn, raw: string): Promise<void> {
  let msg: IncomingMessage;
  try {
    msg = JSON.parse(raw);
  } catch {
    err(conn, 'Invalid JSON');
    return;
  }

  switch (msg.type) {
    case 'ping':
      sendTo(conn, { type: 'pong' });
      return;

    case 'join': {
      const g = await loadPlayableGame(conn, msg.gameId);
      if (!g) return;
      joinGame(conn, g.id);
      const game = await buildGameDTO(g, conn.userId);
      sendTo(conn, { type: 'gameState', game });
      return;
    }

    case 'move': {
      const g = await loadPlayableGame(conn, msg.gameId);
      if (!g) return;
      if (typeof msg.uci !== 'string') {
        err(conn, 'uci required');
        return;
      }
      try {
        const { game, move, outcome } = await makeMove(g.id, conn.userId, msg.uci);
        emitMove(game, move);
        if (outcome) emitGameOver(game.id, outcome.result, outcome.termination);
        else notifyTurnIfCorrespondence(game);
      } catch (e) {
        err(conn, e instanceof MoveError ? e.message : 'Move failed');
      }
      return;
    }

    case 'resign': {
      const g = await loadPlayableGame(conn, msg.gameId);
      if (!g || g.status !== 'active') {
        if (g) err(conn, 'Game is not active');
        return;
      }
      const color = colorOf(g, conn.userId)!;
      const result = color === 'white' ? 'black' : 'white';
      await endGame(g.id, result, 'resignation');
      emitGameOver(g.id, result, 'resignation');
      return;
    }

    default:
      err(conn, `Unknown message type: ${String(msg.type)}`);
  }
}
