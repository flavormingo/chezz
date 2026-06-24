import type { UserRow } from '../db/schema.js';

export interface Profile {
  id: string;
  username: string;
  displayName: string | null;
  rating: number;
  avatarColor: string;
  image: string | null;
  createdAt: string;
  isFriend: boolean;
  discoverable: boolean;
}

export function toProfile(u: UserRow, isFriend: boolean): Profile {
  return {
    id: u.id,
    // '' rather than null: the client contract types username as a non-optional string.
    username: u.username ?? '',
    displayName: u.displayName ?? null,
    rating: u.rating,
    avatarColor: u.avatarColor,
    image: u.image ?? null,
    createdAt: u.createdAt.toISOString(),
    isFriend,
    discoverable: u.discoverable,
  };
}

// The signed-in user's own profile. `hasDiscoveryPhone` lets the client show "Findable" honestly
// and prompt for a number; it is intentionally NOT on toProfile, so we never leak whether OTHER
// users have a number set. Every /me self-return must use this, or the client would reset the flag.
export function selfProfile(u: UserRow): Profile & { hasDiscoveryPhone: boolean } {
  return { ...toProfile(u, false), hasDiscoveryPhone: u.phoneHash != null };
}
