import { eq } from 'drizzle-orm';
import { db } from '../db/index.js';
import { deviceToken as deviceTokenTable } from '../db/schema.js';
import type { GameRow, UserRow } from '../db/schema.js';
import { pushEnabled } from '../env.js';
import { turnFor } from '../lib/game-logic.js';
import { getUserRow } from '../lib/games-service.js';
import { isUserInGame } from '../ws/hub.js';
import { sendApns, type ApnsEnvironment } from './apns.js';

interface Alert {
  title: string;
  body: string;
}

export function displayNameOf(u: UserRow | null | undefined): string {
  return u?.displayName?.trim() || u?.username || 'A friend';
}

async function sendToUser(
  userId: string,
  alert: Alert,
  extra: Record<string, unknown>,
): Promise<void> {
  if (!pushEnabled) return;
  const rows = await db
    .select()
    .from(deviceTokenTable)
    .where(eq(deviceTokenTable.userId, userId));
  if (rows.length === 0) return;

  const payload = { aps: { alert, sound: 'default' }, ...extra };
  await Promise.all(
    rows.map(async (row) => {
      const res = await sendApns(row.token, row.environment as ApnsEnvironment, payload);
      if (res.shouldDelete) {
        await db.delete(deviceTokenTable).where(eq(deviceTokenTable.id, row.id));
      } else if (res.correctedEnvironment && res.correctedEnvironment !== row.environment) {
        await db
          .update(deviceTokenTable)
          .set({ environment: res.correctedEnvironment, updatedAt: new Date() })
          .where(eq(deviceTokenTable.id, row.id));
      }
    }),
  );
}

function fire(p: Promise<void>): void {
  p.catch((e) => console.error('[push]', e instanceof Error ? e.message : e));
}

export function notifyChallengeReceived(toUserId: string, fromName: string, kind: string): void {
  const mode = kind === 'live' ? 'live' : 'correspondence';
  fire(
    sendToUser(
      toUserId,
      { title: 'New challenge', body: `${fromName} challenged you to a ${mode} game.` },
      { type: 'challenge' },
    ),
  );
}

export function notifyChallengeAccepted(toUserId: string, byName: string, gameId: string): void {
  fire(
    sendToUser(
      toUserId,
      { title: 'Challenge accepted', body: `${byName} accepted your challenge. It's game time.` },
      { type: 'gameStart', gameId },
    ),
  );
}

export function notifyTurnIfCorrespondence(game: GameRow): void {
  if (game.kind !== 'correspondence' || game.status !== 'active') return;
  const turn = turnFor(game.movesUci);
  const targetId = turn === 'white' ? game.whiteId : game.blackId;
  const moverId = turn === 'white' ? game.blackId : game.whiteId;
  if (!targetId) return;
  // Skip the push if they're already watching the game over a live socket.
  if (isUserInGame(targetId, game.id)) return;

  fire(
    (async () => {
      const mover = await getUserRow(moverId);
      await sendToUser(
        targetId,
        { title: 'Your move', body: `It's your turn vs ${displayNameOf(mover)}.` },
        { type: 'yourTurn', gameId: game.id },
      );
    })(),
  );
}
