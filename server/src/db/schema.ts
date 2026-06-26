import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

// BetterAuth's Drizzle adapter maps by the camelCase JS keys below; they must match its field
// names (the snake_case DB column names are free to differ).
export const user = pgTable(
  'user',
  {
    id: text('id').primaryKey(),
    name: text('name').notNull(),
    email: text('email').notNull().unique(),
    emailVerified: boolean('email_verified').notNull().default(false),
    image: text('image'),

    username: text('username').unique(),
    displayUsername: text('display_username'),

    rating: integer('rating').notNull().default(1200),
    avatarColor: text('avatar_color').notNull().default('#34E5A1'),
    discoverable: boolean('discoverable').notNull().default(true),
    displayName: text('display_name'),
    phoneHash: text('phone_hash').unique(),

    // Consecutive-day play streak, reported by the client (mirrors the on-device Streak logic) so
    // friends can see each other's streaks. streakLastPlayedAt drives lapse: served value decays to 0.
    streakCount: integer('streak_count').notNull().default(0),
    streakLastPlayedAt: timestamp('streak_last_played_at'),

    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow(),
  },
  (t) => [
    // The username plugin's uniqueness pre-check is racy, so enforce it case-insensitively here too.
    uniqueIndex('user_username_lower_unique').on(sql`lower(${t.username})`),
    index('user_username_lower_idx').on(sql`lower(${t.username})`),
  ],
);

export const session = pgTable('session', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => user.id, { onDelete: 'cascade' }),
  token: text('token').notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  ipAddress: text('ip_address'),
  userAgent: text('user_agent'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

export const account = pgTable('account', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => user.id, { onDelete: 'cascade' }),
  accountId: text('account_id').notNull(),
  providerId: text('provider_id').notNull(),
  accessToken: text('access_token'),
  refreshToken: text('refresh_token'),
  idToken: text('id_token'),
  accessTokenExpiresAt: timestamp('access_token_expires_at'),
  refreshTokenExpiresAt: timestamp('refresh_token_expires_at'),
  scope: text('scope'),
  password: text('password'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

export const verification = pgTable('verification', {
  id: text('id').primaryKey(),
  identifier: text('identifier').notNull(),
  value: text('value').notNull(),
  expiresAt: timestamp('expires_at').notNull(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

export const friendship = pgTable(
  'friendship',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userA: text('user_a')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    userB: text('user_b')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    createdAt: timestamp('created_at').notNull().defaultNow(),
  },
  (t) => [uniqueIndex('friendship_pair_unique').on(t.userA, t.userB)],
);

export const friendRequest = pgTable(
  'friend_request',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    fromUserId: text('from_user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    toUserId: text('to_user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    status: text('status').notNull().default('pending'),
    createdAt: timestamp('created_at').notNull().defaultNow(),
  },
  (t) => [
    index('friend_request_to_idx').on(t.toUserId),
    index('friend_request_from_idx').on(t.fromUserId),
  ],
);

export const challenge = pgTable(
  'challenge',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    fromUserId: text('from_user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    toUserId: text('to_user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    kind: text('kind').notNull(),
    timeControl: jsonb('time_control').$type<TimeControl | null>(),
    color: text('color').notNull(),
    status: text('status').notNull().default('pending'),
    gameId: uuid('game_id').references(() => game.id, { onDelete: 'set null' }),
    createdAt: timestamp('created_at').notNull().defaultNow(),
  },
  (t) => [
    index('challenge_to_idx').on(t.toUserId),
    index('challenge_from_idx').on(t.fromUserId),
  ],
);

export const game = pgTable(
  'game',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    kind: text('kind').notNull(),
    whiteId: text('white_id').references(() => user.id, { onDelete: 'set null' }),
    blackId: text('black_id').references(() => user.id, { onDelete: 'set null' }),
    timeControl: jsonb('time_control').$type<TimeControl | null>(),
    rated: boolean('rated').notNull().default(true),

    status: text('status').notNull().default('active'),
    result: text('result').$type<GameResult | null>(),
    termination: text('termination').$type<Termination | null>(),

    // Source of truth for the game; pgn and FEN are derived from this UCI move list.
    movesUci: jsonb('moves_uci').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    pgn: text('pgn').notNull().default(''),

    // Game Review, computed on-device and shared: the first participant to open the review uploads it
    // (first-write-wins) so both players see the identical analysis instead of each recomputing.
    review: jsonb('review').$type<unknown>(),

    whiteTimeMs: integer('white_time_ms'),
    blackTimeMs: integer('black_time_ms'),
    lastMoveAt: timestamp('last_move_at'),

    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow(),
    finishedAt: timestamp('finished_at'),
  },
  (t) => [
    index('game_white_idx').on(t.whiteId),
    index('game_black_idx').on(t.blackId),
    index('game_status_idx').on(t.status),
  ],
);

export const deviceToken = pgTable(
  'device_token',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    token: text('token').notNull().unique(),
    platform: text('platform').notNull().default('ios'),
    environment: text('environment').notNull().default('production'),
    createdAt: timestamp('created_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow(),
  },
  (t) => [index('device_token_user_idx').on(t.userId)],
);

export interface TimeControl {
  initialSeconds: number;
  incrementSeconds: number;
}
export type GameResult = 'white' | 'black' | 'draw';
export type Termination =
  | 'checkmate'
  | 'resignation'
  | 'timeout'
  | 'stalemate'
  | 'agreement'
  | 'insufficient'
  | 'fiftyMove'
  | 'repetition'
  | 'abandoned'
  | 'aborted';

export type UserRow = typeof user.$inferSelect;
export type GameRow = typeof game.$inferSelect;
export type ChallengeRow = typeof challenge.$inferSelect;
export type FriendRequestRow = typeof friendRequest.$inferSelect;
export type DeviceTokenRow = typeof deviceToken.$inferSelect;
