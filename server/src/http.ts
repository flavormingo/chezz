import { eq } from 'drizzle-orm';
import type { Context, MiddlewareHandler } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { auth } from './auth.js';
import { db } from './db/index.js';
import { user as userTable, type UserRow } from './db/schema.js';

export type AppEnv = {
  Variables: {
    user: UserRow;
  };
};

export type AppContext = Context<AppEnv>;

export function apiError(status: number, code: string, message: string): never {
  throw new HTTPException(status as never, {
    res: new Response(JSON.stringify({ error: { code, message } }), {
      status,
      headers: { 'content-type': 'application/json' },
    }),
  });
}

export const requireAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const session = await auth.api.getSession({ headers: c.req.raw.headers });
  if (!session?.user) {
    apiError(401, 'unauthorized', 'Valid bearer session required.');
  }
  const rows = await db.select().from(userTable).where(eq(userTable.id, session.user.id)).limit(1);
  const row = rows[0];
  if (!row) {
    apiError(401, 'unauthorized', 'Account no longer exists.');
  }
  c.set('user', row);
  await next();
};
