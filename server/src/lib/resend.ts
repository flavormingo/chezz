import { Resend } from 'resend';
import { env, resendEnabled } from '../env.js';

const client = resendEnabled ? new Resend(env.resend.apiKey!) : null;

// Fire-and-forget: callers must not await (awaiting leaks address existence via timing).
export function sendEmailOtp(email: string, otp: string): void {
  if (!client) {
    console.log(`[dev-otp] email code for ${email}: ${otp}`);
    return;
  }
  client.emails
    .send({
      from: env.resend.emailFrom,
      to: email,
      subject: 'Your chezz sign-in code',
      text: `Your chezz sign-in code is ${otp}. It expires in 10 minutes.`,
    })
    .then((result) => {
      // The Resend SDK returns API errors as a value, not a throw, so failures are silent otherwise.
      if (result.error) console.error('[resend] sendEmailOtp error:', result.error);
    })
    .catch((err: unknown) => {
      console.error('[resend] sendEmailOtp failed:', err);
    });
}

export function sendEmailChangeCode(email: string, otp: string): void {
  if (!client) {
    console.log(`[dev-otp] email-change code for ${email}: ${otp}`);
    return;
  }
  client.emails
    .send({
      from: env.resend.emailFrom,
      to: email,
      subject: 'Confirm your new chezz email',
      text: `Use code ${otp} to confirm this as your new chezz email. It expires in 10 minutes.`,
    })
    .then((result) => {
      if (result.error) console.error('[resend] sendEmailChangeCode error:', result.error);
    })
    .catch((err: unknown) => console.error('[resend] sendEmailChangeCode failed:', err));
}
