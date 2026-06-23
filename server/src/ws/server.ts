import type { IncomingMessage, Server } from 'node:http';
import type { Duplex } from 'node:stream';
import { WebSocketServer, type WebSocket } from 'ws';
import { auth } from '../auth.js';
import { handleMessage } from './handler.js';
import { addConn, removeConn, type Conn } from './hub.js';
import { startClockSweep } from './clock-sweep.js';

const AUTH_GRACE_MS = 5000;
const PATH = '/ws';

async function userIdFromHeaders(headers: Headers): Promise<string | null> {
  try {
    const session = await auth.api.getSession({ headers });
    return session?.user?.id ?? null;
  } catch {
    return null;
  }
}

async function userIdFromToken(token: string): Promise<string | null> {
  const headers = new Headers({ authorization: `Bearer ${token}` });
  return userIdFromHeaders(headers);
}

// Auth comes from the upgrade header, or a first-message {type:"auth", token} fallback for
// native WS clients that can't set headers on the upgrade.
export function attachWebSocketServer(server: Server): void {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req: IncomingMessage, socket: Duplex, head: Buffer) => {
    const { url } = req;
    if (!url || new URL(url, 'http://localhost').pathname !== PATH) {
      socket.destroy();
      return;
    }

    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) {
      if (typeof v === 'string') headers.set(k, v);
      else if (Array.isArray(v)) headers.set(k, v.join(', '));
    }

    void userIdFromHeaders(headers).then((userId) => {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, userId);
      });
    });
  });

  wss.on('connection', (ws: WebSocket, preAuthUserId: string | null) => {
    let conn: Conn | null = null;

    if (preAuthUserId) {
      conn = { ws, userId: preAuthUserId, games: new Set() };
      addConn(conn);
    }

    let authInFlight = false;

    const graceTimer = preAuthUserId
      ? null
      : setTimeout(() => {
          if (!conn) {
            ws.send(JSON.stringify({ type: 'error', message: 'Auth timeout' }));
            ws.close();
          }
        }, AUTH_GRACE_MS);

    ws.on('message', (data) => {
      const raw = data.toString();

      if (!conn) {
        let parsed: { type?: string; token?: string };
        try {
          parsed = JSON.parse(raw);
        } catch {
          ws.send(JSON.stringify({ type: 'error', message: 'Auth required' }));
          return;
        }
        if (parsed.type === 'auth' && typeof parsed.token === 'string') {
          if (authInFlight) return;
          authInFlight = true;
          void userIdFromToken(parsed.token).then((userId) => {
            authInFlight = false;
            // Already authed, or the socket closed (e.g. grace timeout) while we were resolving.
            if (conn || ws.readyState !== ws.OPEN) return;
            if (!userId) {
              ws.send(JSON.stringify({ type: 'error', message: 'Invalid token' }));
              ws.close();
              return;
            }
            if (graceTimer) clearTimeout(graceTimer);
            conn = { ws, userId, games: new Set() };
            addConn(conn);
          });
        } else {
          ws.send(JSON.stringify({ type: 'error', message: 'Auth required' }));
        }
        return;
      }

      void handleMessage(conn, raw).catch((err) => {
        console.error('[ws] message handler error:', err);
        ws.send(JSON.stringify({ type: 'error', message: 'Internal error' }));
      });
    });

    ws.on('close', () => {
      if (graceTimer) clearTimeout(graceTimer);
      if (conn) removeConn(conn);
    });

    ws.on('error', () => {
      if (conn) removeConn(conn);
    });
  });

  startClockSweep();
}
