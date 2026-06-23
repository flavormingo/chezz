import { createSign } from 'node:crypto';
import { env, appleEnabled } from '../env.js';

function base64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

// .p8 keys in .env often arrive with literal "\n" escapes rather than real newlines.
function normalizePem(key: string): string {
  return key.includes('\\n') ? key.replace(/\\n/g, '\n') : key;
}

// Apple's "client secret" is a short-lived ES256 JWT signed with the .p8 key, minted at startup.
export function generateAppleClientSecret(): string | undefined {
  if (!appleEnabled) return undefined;

  const now = Math.floor(Date.now() / 1000);
  const SIX_MONTHS = 60 * 60 * 24 * 180; // Apple's documented maximum.

  const header = { alg: 'ES256', kid: env.apple.keyId };
  const payload = {
    iss: env.apple.teamId,
    iat: now,
    exp: now + SIX_MONTHS,
    aud: 'https://appleid.apple.com',
    sub: env.apple.clientId,
  };

  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;

  const signer = createSign('SHA256');
  signer.update(signingInput);
  signer.end();
  // Apple requires JOSE raw r||s (ieee-p1363) signatures, not the default DER encoding.
  const signature = signer.sign(
    { key: normalizePem(env.apple.privateKey!), dsaEncoding: 'ieee-p1363' },
    'base64url',
  );

  return `${signingInput}.${signature}`;
}
