import { Firestore, Transaction } from 'firebase-admin/firestore';
import { ts } from './db';

export interface NotificationInput {
  type: string;
  title: string;
  body: string;
  link?: string;
}

/** Writes an in-app notification (spec: users/{uid}/notifications). */
export async function notify(db: Firestore, uid: string, n: NotificationInput, now = new Date()): Promise<void> {
  await db.collection(`users/${uid}/notifications`).add({ ...n, link: n.link ?? null, read: false, createdAt: ts(now) });
}

/**
 * Same as notify, inside a transaction. With [id], the notification can be
 * rewritten later (a job request is keyed by its offer id).
 */
export function notifyTx(tx: Transaction, db: Firestore, uid: string, n: NotificationInput, now = new Date(), id?: string): void {
  const col = db.collection(`users/${uid}/notifications`);
  tx.set(id ? col.doc(id) : col.doc(), { ...n, link: n.link ?? null, read: false, createdAt: ts(now) });
}
