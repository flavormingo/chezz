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
