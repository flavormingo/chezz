import type { WebSocket } from 'ws';

// In-memory, single-process connection registry. For multi-instance scaling, put a pub/sub (Redis) behind it.
export interface Conn {
  ws: WebSocket;
  userId: string;
  games: Set<string>;
}

const byUser = new Map<string, Set<Conn>>();
const byGame = new Map<string, Set<Conn>>();

export function addConn(conn: Conn): void {
  let set = byUser.get(conn.userId);
  if (!set) byUser.set(conn.userId, (set = new Set()));
  set.add(conn);
}

export function removeConn(conn: Conn): void {
  byUser.get(conn.userId)?.delete(conn);
  if (byUser.get(conn.userId)?.size === 0) byUser.delete(conn.userId);
  for (const gameId of conn.games) {
    byGame.get(gameId)?.delete(conn);
    if (byGame.get(gameId)?.size === 0) byGame.delete(gameId);
  }
}

export function joinGame(conn: Conn, gameId: string): void {
  conn.games.add(gameId);
  let set = byGame.get(gameId);
  if (!set) byGame.set(gameId, (set = new Set()));
  set.add(conn);
}

function send(ws: WebSocket, payload: unknown): void {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(payload));
}

export function sendTo(conn: Conn, payload: unknown): void {
  send(conn.ws, payload);
}

export function broadcastGame(gameId: string, payload: unknown): void {
  const set = byGame.get(gameId);
  if (!set) return;
  for (const conn of set) send(conn.ws, payload);
}

export function pushToUser(userId: string, payload: unknown): void {
  const set = byUser.get(userId);
  if (!set) return;
  for (const conn of set) send(conn.ws, payload);
}

export function activeGameIds(): string[] {
  return [...byGame.keys()];
}

export function isUserInGame(userId: string, gameId: string): boolean {
  const set = byGame.get(gameId);
  if (!set) return false;
  for (const conn of set) if (conn.userId === userId) return true;
  return false;
}
