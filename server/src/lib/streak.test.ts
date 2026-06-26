import assert from 'node:assert/strict';
import { test } from 'node:test';
import { afterPlay, currentStreak } from './streak.js';

const day = (s: string) => new Date(`${s}T12:00:00Z`);

test('first play starts a streak of 1', () => {
  const r = afterPlay(0, null, day('2026-06-25'));
  assert.equal(r.count, 1);
});

test('playing again the same day is idempotent', () => {
  const r = afterPlay(5, day('2026-06-25'), new Date('2026-06-25T23:00:00Z'));
  assert.equal(r.count, 5);
});

test('a consecutive day increments the streak', () => {
  const r = afterPlay(5, day('2026-06-24'), day('2026-06-25'));
  assert.equal(r.count, 6);
});

test('a gap of two or more days resets to 1', () => {
  const r = afterPlay(5, day('2026-06-22'), day('2026-06-25'));
  assert.equal(r.count, 1);
});

test('currentStreak holds today and yesterday', () => {
  assert.equal(currentStreak(5, day('2026-06-25'), day('2026-06-25')), 5);
  assert.equal(currentStreak(5, day('2026-06-24'), day('2026-06-25')), 5);
});

test('currentStreak lapses to 0 after two idle days', () => {
  assert.equal(currentStreak(5, day('2026-06-23'), day('2026-06-25')), 0);
  assert.equal(currentStreak(0, null, day('2026-06-25')), 0);
});
