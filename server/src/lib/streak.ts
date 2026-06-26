// Consecutive-day play streak, mirroring the iOS Streak logic (Streak.swift). Day boundaries are
// computed in UTC from server time only (never a client-supplied date), so a client cannot inflate
// its streak: afterPlay caps the gain at +1 per server-day and is idempotent within the same day.

const DAY_MS = 86_400_000;

function startOfDayUTC(d: Date): number {
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

// New (count, lastPlayed) after a play event today. lastPlayed is the real instant `now`; day
// boundaries are recomputed on read (currentStreak / the next afterPlay) so we never persist a
// normalized-midnight value that could shift across a day when round-tripped through the DB.
export function afterPlay(
  prev: number,
  lastPlayed: Date | null,
  now: Date,
): { count: number; lastPlayed: Date } {
  const today = startOfDayUTC(now);
  if (!lastPlayed) return { count: 1, lastPlayed: now };
  const last = startOfDayUTC(lastPlayed);
  if (last === today) return { count: Math.max(prev, 1), lastPlayed: now }; // already counted today
  const gap = Math.round((today - last) / DAY_MS);
  return { count: gap === 1 ? prev + 1 : 1, lastPlayed: now };
}

// Displayable streak: lapses to 0 once 2+ calendar days have passed without play.
export function currentStreak(count: number, lastPlayed: Date | null, now: Date): number {
  if (!lastPlayed || count <= 0) return 0;
  const gap = Math.round((startOfDayUTC(now) - startOfDayUTC(lastPlayed)) / DAY_MS);
  return gap >= 0 && gap <= 1 ? count : 0;
}
