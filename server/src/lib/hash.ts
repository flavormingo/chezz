import { createHmac } from 'node:crypto';
import { env } from '../env.js';

// Deterministic by design: changing CONTACT_HASH_SECRET invalidates every stored contact hash.
export function hashPhone(e164: string): string {
  return createHmac('sha256', env.contactHashSecret).update(e164.trim()).digest('hex');
}

export function normalizeE164(raw: string): string | null {
  let s = raw.trim().replace(/[\s().-]/g, '');
  if (s.startsWith('00')) s = `+${s.slice(2)}`;
  if (!s.startsWith('+')) return null;
  const digits = s.slice(1);
  if (!/^[1-9]\d{6,14}$/.test(digits)) return null;
  return `+${digits}`;
}
