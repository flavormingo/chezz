import { remainingForSideToMove, turnFor } from '../lib/game-logic.js';
import { endGame, getGameRow } from '../lib/games-service.js';
import { emitGameOver } from './broadcast.js';
import { activeGameIds } from './hub.js';

const SWEEP_INTERVAL_MS = 1000;

let timer: ReturnType<typeof setInterval> | null = null;

async function tick(): Promise<void> {
  // Only games with a live socket are swept; an unwatched game flags on the next reconnect.
  const ids = activeGameIds();
  if (ids.length === 0) return;

  await Promise.all(
    ids.map(async (id) => {
      const g = await getGameRow(id);
      if (!g || g.status !== 'active' || g.kind !== 'live') return;
      if (g.whiteTimeMs == null || g.blackTimeMs == null) return;

      const remaining = remainingForSideToMove(g);
      if (remaining == null || remaining > 0) return;

      // The side to move flagged, so the opponent wins.
      const loser = turnFor(g.movesUci);
      const result = loser === 'white' ? 'black' : 'white';
      await endGame(id, result, 'timeout');
      emitGameOver(id, result, 'timeout');
    }),
  );
}

export function startClockSweep(): void {
  if (timer) return;
  timer = setInterval(() => {
    void tick().catch((err) => console.error('[clock-sweep] tick failed:', err));
  }, SWEEP_INTERVAL_MS);
  timer.unref();
}
