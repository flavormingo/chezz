import { and, eq, inArray, or } from 'drizzle-orm';
import { db } from '../db/index.js';
import { friendship } from '../db/schema.js';

// Friendships are undirected; always store and query them canonically with userA < userB.
export function orderPair(a: string, b: string): { userA: string; userB: string } {
  return a < b ? { userA: a, userB: b } : { userA: b, userB: a };
}

export async function friendIdsOf(userId: string): Promise<Set<string>> {
  const rows = await db
    .select()
    .from(friendship)
    .where(or(eq(friendship.userA, userId), eq(friendship.userB, userId)));

  const ids = new Set<string>();
  for (const r of rows) ids.add(r.userA === userId ? r.userB : r.userA);
  return ids;
}

export async function friendsAmong(
  userId: string,
  candidateIds: string[],
): Promise<Set<string>> {
  if (candidateIds.length === 0) return new Set();
  const rows = await db
    .select()
    .from(friendship)
    .where(
      or(
        and(eq(friendship.userA, userId), inArray(friendship.userB, candidateIds)),
        and(eq(friendship.userB, userId), inArray(friendship.userA, candidateIds)),
      ),
    );
  const ids = new Set<string>();
  for (const r of rows) ids.add(r.userA === userId ? r.userB : r.userA);
  return ids;
}

export async function areFriends(a: string, b: string): Promise<boolean> {
  const { userA, userB } = orderPair(a, b);
  const rows = await db
    .select()
    .from(friendship)
    .where(and(eq(friendship.userA, userA), eq(friendship.userB, userB)))
    .limit(1);
  return rows.length > 0;
}
