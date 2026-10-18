// FCM push delivery. Tokens live on users/{uid}.fcmTokens; one device token belongs to one user.
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { Messaging, getMessaging } from 'firebase-admin/messaging';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { db } from './db';
import { fail, requireAuth } from './errors';

function tokenOf(raw: unknown): string {
  const t = (raw as { token?: unknown } | null)?.token;
  if (typeof t !== 'string' || t.length === 0 || t.length > 4096) fail('bad-request', 'Invalid push token.');
  return t;
}

export async function claimPushTokenLogic(db: Firestore, uid: string, raw: unknown): Promise<{ ok: true }> {
  const token = tokenOf(raw);
  const others = await db.collection('users').where('fcmTokens', 'array-contains', token).get();
  const batch = db.batch();
  for (const d of others.docs) {
    if (d.id !== uid) batch.update(d.ref, { fcmTokens: FieldValue.arrayRemove(token) });
  }
  batch.set(db.doc(`users/${uid}`), { fcmTokens: FieldValue.arrayUnion(token) }, { merge: true });
  await batch.commit();
  return { ok: true };
}

export async function releasePushTokenLogic(db: Firestore, uid: string, raw: unknown): Promise<{ ok: true }> {
  const token = tokenOf(raw);
  await db.doc(`users/${uid}`).set({ fcmTokens: FieldValue.arrayRemove(token) }, { merge: true });
  return { ok: true };
}

const DEAD = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-argument']);

export async function sendPushLogic(
  db: Firestore,
  messaging: Pick<Messaging, 'sendEachForMulticast'>,
  uid: string,
  n: { title: string; body: string; link: string | null },
): Promise<number> {
  const tokens: string[] = (await db.doc(`users/${uid}`).get()).data()?.fcmTokens ?? [];
  if (tokens.length === 0) return 0;
  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: n.title, body: n.body },
    data: { link: n.link ?? '' },
    android: { priority: 'high', notification: { channelId: 'careway_updates' } },
  });
  const dead = tokens.filter((_, i) => !res.responses[i]?.success && DEAD.has(res.responses[i]?.error?.code ?? ''));
  if (dead.length > 0) await db.doc(`users/${uid}`).update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  return res.successCount;
}

export const claimPushToken = onCall((req) => claimPushTokenLogic(db(), requireAuth(req.auth), req.data));
export const releasePushToken = onCall((req) => releasePushTokenLogic(db(), requireAuth(req.auth), req.data));

// Firestore DB is nam5 (US multi-region), so the trigger must run in a compatible region, not asia-southeast1.
export const onNotificationCreated = onDocumentCreated({ document: 'users/{uid}/notifications/{nid}', region: 'us-central1' }, async (event) => {
  const n = event.data?.data();
  if (!n) return;
  try {
    await sendPushLogic(db(), getMessaging(), event.params.uid, {
      title: String(n.title ?? ''),
      body: String(n.body ?? ''),
      link: typeof n.link === 'string' ? n.link : null,
    });
  } catch (e) {
    console.error('push failed', event.params.uid, e);
  }
});
