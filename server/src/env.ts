function required(name: string): string {
  const v = process.env[name];
  if (!v || v.length === 0) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v;
}

function optional(name: string): string | undefined {
  const v = process.env[name];
  return v && v.length > 0 ? v : undefined;
}

export const env = {
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: required('DATABASE_URL'),
  betterAuthSecret: required('BETTER_AUTH_SECRET'),
  betterAuthUrl: process.env.BETTER_AUTH_URL ?? 'http://localhost:3000',
  appBaseUrl: process.env.APP_BASE_URL ?? process.env.BETTER_AUTH_URL ?? 'http://localhost:3000',
  contactHashSecret: required('CONTACT_HASH_SECRET'),

  uploadDir: process.env.UPLOAD_DIR ?? 'uploads',

  resend: {
    apiKey: optional('RESEND_API_KEY'),
    emailFrom: process.env.EMAIL_FROM ?? 'chezz <login@chezz.app>',
  },

  apple: {
    clientId: optional('APPLE_CLIENT_ID'),
    appBundleId: process.env.APPLE_APP_BUNDLE_ID ?? 'digital.mazz.chezz',
    teamId: optional('APPLE_TEAM_ID'),
    keyId: optional('APPLE_KEY_ID'),
    privateKey: optional('APPLE_PRIVATE_KEY'),
  },

  apns: {
    keyId: optional('APNS_KEY_ID'),
    privateKey: optional('APNS_PRIVATE_KEY'),
    teamId: optional('APNS_TEAM_ID') ?? optional('APPLE_TEAM_ID'),
  },
} as const;

export const resendEnabled = !!env.resend.apiKey;

export const appleEnabled =
  !!env.apple.clientId && !!env.apple.teamId && !!env.apple.keyId && !!env.apple.privateKey;

export const pushEnabled = !!env.apns.keyId && !!env.apns.privateKey && !!env.apns.teamId;
