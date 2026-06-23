import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { bearer, emailOTP, username } from 'better-auth/plugins';
import { db, schema } from './db/index.js';
import { appleEnabled, env } from './env.js';
import { generateAppleClientSecret } from './lib/apple-secret.js';
import { sendEmailOtp } from './lib/resend.js';

const appleClientSecret = generateAppleClientSecret();
const socialProviders =
  appleEnabled && appleClientSecret
    ? {
        apple: {
          clientId: env.apple.clientId!,
          clientSecret: appleClientSecret,
          // Mandatory for native sign-in: the id token's `aud` is the bundle id, not the Services ID.
          appBundleIdentifier: env.apple.appBundleId,
        },
      }
    : {};

export const auth = betterAuth({
  secret: env.betterAuthSecret,
  baseURL: env.betterAuthUrl,

  database: drizzleAdapter(db, {
    provider: 'pg',
    schema: {
      user: schema.user,
      session: schema.session,
      account: schema.account,
      verification: schema.verification,
    },
  }),

  trustedOrigins: [env.appBaseUrl, env.betterAuthUrl, 'https://appleid.apple.com'],

  // BetterAuth defaults OTP sends to 3/60s, which legit resends trip; loosen to 6/60s per IP.
  rateLimit: {
    customRules: {
      '/email-otp/send-verification-otp': { window: 60, max: 6 },
    },
  },

  account: {
    accountLinking: {
      // Only link providers that assert a verified email, else a typed email could hijack an account.
      enabled: true,
      trustedProviders: ['apple', 'email-otp'],
    },
  },

  user: {
    additionalFields: {
      rating: { type: 'number', defaultValue: 1200, input: false },
      avatarColor: { type: 'string', defaultValue: '#34E5A1', input: true },
      discoverable: { type: 'boolean', defaultValue: true, input: true },
      displayName: { type: 'string', required: false, input: true },
      phoneHash: { type: 'string', required: false, input: false },
    },
  },

  socialProviders,

  plugins: [
    // Token is returned in the set-auth-token response header, then sent as Authorization: Bearer.
    bearer(),

    username({
      minUsernameLength: 3,
      maxUsernameLength: 20,
      usernameNormalization: (u) => u.toLowerCase(),
    }),

    emailOTP({
      otpLength: 6,
      expiresIn: 600,
      allowedAttempts: 3,

      // Fire-and-forget on purpose: awaiting the send leaks address existence via timing.
      sendVerificationOTP: async ({ email, otp }) => {
        sendEmailOtp(email, otp);
      },
    }),
  ],
});

export type Auth = typeof auth;
