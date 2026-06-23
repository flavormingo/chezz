// In-process fixed-window limiter. Single-instance only; use a shared store (Redis) if you scale out.
interface Bucket {
  count: number;
  resetAt: number;
}

export class RateLimiter {
  private readonly buckets = new Map<string, Bucket>();

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
  ) {}

  check(key: string): boolean {
    const now = Date.now();
    const bucket = this.buckets.get(key);

    if (!bucket || now >= bucket.resetAt) {
      this.buckets.set(key, { count: 1, resetAt: now + this.windowMs });
      return true;
    }
    if (bucket.count >= this.limit) return false;

    bucket.count += 1;
    return true;
  }

  sweep(): void {
    const now = Date.now();
    for (const [key, bucket] of this.buckets) {
      if (now >= bucket.resetAt) this.buckets.delete(key);
    }
  }
}

export const contactsByAccount = new RateLimiter(10, 60 * 60 * 1000);
export const contactsByIp = new RateLimiter(30, 60 * 60 * 1000);

setInterval(
  () => {
    contactsByAccount.sweep();
    contactsByIp.sweep();
  },
  10 * 60 * 1000,
).unref();
