import { createHmac } from 'node:crypto';
import { type CountryCode, parsePhoneNumberFromString } from 'libphonenumber-js';
import { env } from '../env.js';

// Deterministic by design: changing CONTACT_HASH_SECRET invalidates every stored contact hash.
export function hashPhone(e164: string): string {
  return createHmac('sha256', env.contactHashSecret).update(e164.trim()).digest('hex');
}

// Parse any input to canonical E.164 (e.g. "+14155552671"). A number with a country code parses on
// its own; a national-format one ("(415) 555-2671", "07911 123456") needs `defaultRegion` (the
// caller's device country, e.g. "US") to resolve its country code. The SAME function must normalize
// both the discoverable number and uploaded contacts or their hashes won't line up. Returns null for
// anything that isn't a valid number. `.number` matches what the old +-only normalizer produced for
// "+1.." inputs, so previously stored hashes stay valid.
export function normalizeE164(raw: string, defaultRegion?: string | null): string | null {
  if (typeof raw !== 'string' || !raw.trim()) return null;
  // Rewrite a leading "00" IDD prefix to "+" so it parses without a region and stays compatible
  // with hashes the old +-only normalizer produced from 00-form inputs.
  const input = raw.trim().replace(/^00/, '+');
  const region =
    defaultRegion && /^[A-Za-z]{2}$/.test(defaultRegion)
      ? (defaultRegion.toUpperCase() as CountryCode)
      : undefined;
  try {
    const parsed = parsePhoneNumberFromString(input, region);
    // isPossible (length-based), not isValid: don't reject real numbers in ranges libphonenumber's
    // metadata calls invalid (VoIP/new/reassigned). Garbage still fails; matching only needs a
    // canonical E.164, and a non-real number simply matches nobody.
    return parsed?.isPossible() ? parsed.number : null;
  } catch {
    return null;
  }
}
