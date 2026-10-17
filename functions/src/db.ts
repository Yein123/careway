import { getFirestore, Timestamp } from 'firebase-admin/firestore';

export const db = () => getFirestore();

export const ts = (d: Date) => Timestamp.fromDate(d);

export function toDate(v: unknown): Date | null {
  if (v == null) return null;
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return new Date(String(v));
}

export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;
