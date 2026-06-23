# chezz, server

Backend for the chezz iOS app: accounts, friends, contacts matching, challenges,
and **server-authoritative** online chess (live + correspondence). Implements
[`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md) exactly.

## Stack
- **Node 22 + TypeScript (ESM)**
- **Hono 4** HTTP (`@hono/node-server`)
- **BetterAuth**, Apple sign-in (primary) + email one-time code (Resend), username, bearer tokens
- **Drizzle ORM** + Postgres (`postgres.js`)
- **ws** for the live-game WebSocket layer (same HTTP server, mounted at `/ws`)
- **chess.js** for move legality / SAN / FEN / game-over detection

## Layout
```
src/
  index.ts          Hono app + Node server + ws upgrade + error/CORS/security
  auth.ts           BetterAuth (emailOTP/username/bearer + Apple, account linking)
  env.ts            typed, fail-fast env access
  http.ts           requireAuth middleware + apiError helper + AppEnv
  db/
    schema.ts       Drizzle schema (auth tables + domain tables)
    index.ts        postgres.js pool + drizzle instance
  lib/
    hash.ts         HMAC phone hashing + E.164 normalize (contact discovery)
    elo.ts          Elo update (K=32)
    resend.ts       Resend email-OTP send (fire-and-forget; dev → console)
    apple-secret.ts Apple client-secret JWT (ES256, from .p8)
    rate-limit.ts   in-process fixed-window limiter (contacts caps)
    profile-mapper.ts  user row → Profile
    friends.ts      friendship helpers (canonical pair, bulk isFriend)
    game-logic.ts   pure chess/clock/elo/DTO logic
    games-service.ts move/resign/draw/timeout persistence + Elo (shared by REST & WS)
  routes/           me, users, contacts, friends, challenges, games
  ws/
    hub.ts          per-user / per-game socket registry + push/broadcast
    server.ts       upgrade auth + connection lifecycle
    handler.ts      join/move/resign/draw/ping message handling
    broadcast.ts    contract-shaped WS message emitters
    clock-sweep.ts  single interval flagging clock timeouts across games
```

## Run locally
```bash
cp .env.example .env          # fill DATABASE_URL + the two secrets at minimum
# Need a Postgres. Easiest:
docker compose up -d postgres
npm install
npm run db:push               # create tables
npm run dev                   # http://localhost:3000  (tsx watch)
```
Without a `RESEND_API_KEY` the server runs in **dev OTP mode**: email codes are printed
to the console (`[dev-otp] email code for a@b.com: 123456`) instead of being mailed.
Apple sign-in is simply disabled until the `APPLE_*` vars are set.

Auth methods (both passwordless): **Sign in with Apple** (primary) and an **optional
email one-time code**. Accounts link by verified email, so Apple + email-OTP with the
same address resolve to one user. Phone is only an optional, unverified discovery field
(set via `POST /api/v1/me/discovery-phone`) used to find friends from contacts.

Health check: `GET /health` → `{ "ok": true }`.

## Scripts
| script | what |
|---|---|
| `npm run dev` | watch + run via tsx |
| `npm run build` | `tsc` → `dist/` |
| `npm start` | run compiled `dist/index.js` |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run db:generate` | emit SQL migration from schema to `drizzle/` |
| `npm run db:push` | apply schema to the database |

## Deploy
See [`../docs/DEPLOY.md`](../docs/DEPLOY.md), single VPS with Docker Compose + Caddy TLS.
