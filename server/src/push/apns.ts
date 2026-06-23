import crypto from 'node:crypto';
import { connect, type ClientHttp2Session } from 'node:http2';
import { env, pushEnabled } from '../env.js';

export type ApnsEnvironment = 'sandbox' | 'production';

export interface ApnsResult {
  ok: boolean;
  status: number;
  reason?: string;
  shouldDelete: boolean;
  correctedEnvironment?: ApnsEnvironment;
}

const PROD_HOST = 'https://api.push.apple.com';
const SANDBOX_HOST = 'https://api.sandbox.push.apple.com';
const hostFor = (e: ApnsEnvironment) => (e === 'sandbox' ? SANDBOX_HOST : PROD_HOST);

let cachedKey: crypto.KeyObject | null = null;
let cachedJwt: { value: string; iat: number } | null = null;

function privateKey(): crypto.KeyObject {
  if (!cachedKey) {
    const pem = (env.apns.privateKey ?? '').replace(/\\n/g, '\n');
    cachedKey = crypto.createPrivateKey(pem);
  }
  return cachedKey;
}

function providerToken(): string {
  const nowSec = Math.floor(Date.now() / 1000);
  // Apple requires the provider token be refreshed within 20-60 min; reuse for 45.
  if (cachedJwt && nowSec - cachedJwt.iat < 45 * 60) return cachedJwt.value;

  const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const header = b64({ alg: 'ES256', kid: env.apns.keyId });
  const claims = b64({ iss: env.apns.teamId, iat: nowSec });
  const signingInput = `${header}.${claims}`;
  // Apple wants the raw r||s (ieee-p1363) signature, not DER.
  const sig = crypto
    .sign('sha256', Buffer.from(signingInput), { key: privateKey(), dsaEncoding: 'ieee-p1363' })
    .toString('base64url');

  const value = `${signingInput}.${sig}`;
  cachedJwt = { value, iat: nowSec };
  return value;
}

const sessions = new Map<string, ClientHttp2Session>();

function getSession(host: string): ClientHttp2Session {
  const existing = sessions.get(host);
  if (existing && !existing.closed && !existing.destroyed) return existing;

  const session = connect(host);
  session.setTimeout(60_000, () => session.close());
  const drop = () => {
    sessions.delete(host);
    if (!session.destroyed) session.destroy();
  };
  session.on('error', drop);
  session.on('goaway', drop);
  session.on('close', () => sessions.delete(host));
  sessions.set(host, session);
  return session;
}

function sendOnce(
  environment: ApnsEnvironment,
  token: string,
  body: string,
): Promise<{ status: number; reason?: string }> {
  return new Promise((resolve) => {
    let session: ClientHttp2Session;
    try {
      session = getSession(hostFor(environment));
    } catch (e) {
      resolve({ status: 0, reason: e instanceof Error ? e.message : 'connect_failed' });
      return;
    }

    const req = session.request({
      ':method': 'POST',
      ':path': `/3/device/${token}`,
      authorization: `bearer ${providerToken()}`,
      'apns-topic': env.apple.appBundleId,
      'apns-push-type': 'alert',
      'apns-priority': '10',
    });

    let status = 0;
    let data = '';
    req.setEncoding('utf8');
    req.on('response', (h) => {
      status = Number(h[':status']) || 0;
    });
    req.on('data', (chunk) => {
      data += chunk;
    });
    req.on('end', () => {
      let reason: string | undefined;
      if (data) {
        try {
          reason = JSON.parse(data).reason;
        } catch {}
      }
      resolve({ status, reason });
    });
    req.on('error', (e) => resolve({ status: 0, reason: e.message }));
    req.setTimeout(10_000, () => {
      req.close();
      resolve({ status: 0, reason: 'timeout' });
    });
    req.end(body);
  });
}

export async function sendApns(
  token: string,
  environment: ApnsEnvironment,
  payload: Record<string, unknown>,
): Promise<ApnsResult> {
  if (!pushEnabled) return { ok: false, status: 0, shouldDelete: false };

  const body = JSON.stringify(payload);
  const primary: ApnsEnvironment = environment === 'sandbox' ? 'sandbox' : 'production';

  const res = await sendOnce(primary, token, body);
  if (res.status === 200) return { ok: true, status: 200, shouldDelete: false };

  // A token minted for the other environment returns BadDeviceToken; retry the other host.
  if (res.reason === 'BadDeviceToken') {
    const other: ApnsEnvironment = primary === 'sandbox' ? 'production' : 'sandbox';
    const res2 = await sendOnce(other, token, body);
    if (res2.status === 200) {
      return { ok: true, status: 200, shouldDelete: false, correctedEnvironment: other };
    }
    return {
      ok: false,
      status: res2.status,
      reason: res2.reason,
      shouldDelete: res2.status === 410 || res2.reason === 'BadDeviceToken',
    };
  }

  if (res.status === 410 || res.reason === 'Unregistered') {
    return { ok: false, status: res.status, reason: res.reason, shouldDelete: true };
  }

  return { ok: false, status: res.status, reason: res.reason, shouldDelete: false };
}
