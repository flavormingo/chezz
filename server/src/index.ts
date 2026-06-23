import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { HTTPException } from 'hono/http-exception';
import { secureHeaders } from 'hono/secure-headers';
import { auth } from './auth.js';
import { appleEnabled, env, pushEnabled, resendEnabled } from './env.js';
import { challengesRoutes } from './routes/challenges.js';
import { contactsRoutes } from './routes/contacts.js';
import { friendsRoutes } from './routes/friends.js';
import { gamesRoutes } from './routes/games.js';
import { meRoutes } from './routes/me.js';
import { usersRoutes } from './routes/users.js';
import { attachWebSocketServer } from './ws/server.js';

const app = new Hono();

app.use('*', secureHeaders());

app.use(
  '*',
  cors({
    origin: [env.appBaseUrl, env.betterAuthUrl, 'https://appleid.apple.com'],
    allowHeaders: ['Content-Type', 'Authorization'],
    allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    exposeHeaders: ['set-auth-token'],
    credentials: true,
  }),
);

app.get('/health', (c) => c.json({ ok: true }));

app.get('/uploads/:file', async (c) => {
  const file = c.req.param('file');
  // Strict filename pattern blocks path traversal.
  if (!/^[A-Za-z0-9._-]+\.(jpg|jpeg|png)$/.test(file)) {
    return c.json({ error: { code: 'not_found', message: 'Not found.' } }, 404);
  }
  try {
    const data = await readFile(path.join(env.uploadDir, file));
    const type = file.endsWith('.png') ? 'image/png' : 'image/jpeg';
    return new Response(data, {
      status: 200,
      headers: { 'content-type': type, 'cache-control': 'public, max-age=86400' },
    });
  } catch {
    return c.json({ error: { code: 'not_found', message: 'Not found.' } }, 404);
  }
});

app.on(['GET', 'POST'], '/api/auth/*', (c) => auth.handler(c.req.raw));

const v1 = new Hono();
v1.route('/me', meRoutes);
v1.route('/users', usersRoutes);
v1.route('/contacts', contactsRoutes);
v1.route('/friends', friendsRoutes);
v1.route('/challenges', challengesRoutes);
v1.route('/games', gamesRoutes);
app.route('/api/v1', v1);

app.onError((err, c) => {
  if (err instanceof HTTPException) {
    if (err.res) return err.res;
    return c.json({ error: { code: 'http_error', message: err.message } }, err.status);
  }
  console.error('[unhandled]', err);
  return c.json({ error: { code: 'internal', message: 'Internal server error.' } }, 500);
});

app.notFound((c) => c.json({ error: { code: 'not_found', message: 'Not found.' } }, 404));

const server = serve({ fetch: app.fetch, port: env.port }, (info) => {
  console.log(`chezz server listening on :${info.port}`);
  console.log(`  Email OTP:  ${resendEnabled ? 'Resend' : 'DEV (codes logged to console)'}`);
  console.log(`  Apple auth: ${appleEnabled ? 'enabled' : 'disabled (missing APPLE_* env)'}`);
  console.log(`  Push:       ${pushEnabled ? 'APNs' : 'disabled (missing APNS_* env)'}`);
});

// serve() returns the underlying Node http.Server; attach the ws upgrade to it.
attachWebSocketServer(server as unknown as import('node:http').Server);
