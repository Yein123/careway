import { claimPushTokenLogic, releasePushTokenLogic, sendPushLogic } from '../src/push';
import { clearDb, describeEmu, testDb } from './helpers';

const db = testDb();
const tokens = async (uid: string) => ((await db.doc(`users/${uid}`).get()).data()?.fcmTokens ?? []) as string[];
const n = { title: 'T', body: 'B', link: '/x' };

describeEmu('push', () => {
  beforeEach(clearDb);

  test('claimPushToken moves the token from another user', async () => {
    await db.doc('users/u1').set({ fcmTokens: ['t1'] });
    await db.doc('users/u2').set({ name: 'x' });
    await claimPushTokenLogic(db, 'u2', { token: 't1' });
    expect(await tokens('u1')).toEqual([]);
    expect(await tokens('u2')).toEqual(['t1']);
  });

  test('claimPushToken rejects an empty or oversized token', async () => {
    await expect(claimPushTokenLogic(db, 'u2', { token: '' })).rejects.toEqual(expect.objectContaining({ details: expect.objectContaining({ code: 'bad-request' }) }));
    await expect(claimPushTokenLogic(db, 'u2', { token: 'a'.repeat(4097) })).rejects.toBeTruthy();
  });

  test('releasePushToken removes it', async () => {
    await db.doc('users/u1').set({ fcmTokens: ['t1', 't2'] });
    await releasePushTokenLogic(db, 'u1', { token: 't1' });
    expect(await tokens('u1')).toEqual(['t2']);
  });

  test('sendPush prunes unregistered tokens', async () => {
    await db.doc('users/u1').set({ fcmTokens: ['a', 'b'] });
    const calls: any[] = [];
    const messaging = {
      sendEachForMulticast: async (m: any) => {
        calls.push(m);
        return {
          successCount: 1,
          failureCount: 1,
          responses: [{ success: true }, { success: false, error: { code: 'messaging/registration-token-not-registered' } }],
        };
      },
    } as any;
    expect(await sendPushLogic(db, messaging, 'u1', n)).toBe(1);
    expect(await tokens('u1')).toEqual(['a']);
    expect(calls[0].android.notification.channelId).toBe('careway_updates');
    expect(calls[0].android.priority).toBe('high');
    expect(calls[0].data).toEqual({ link: '/x' });
    expect(calls[0].notification).toEqual({ title: 'T', body: 'B' });
  });

  test('sendPush with no tokens returns 0 without calling messaging', async () => {
    await db.doc('users/u1').set({ name: 'x' });
    const messaging = { sendEachForMulticast: jest.fn() } as any;
    expect(await sendPushLogic(db, messaging, 'u1', n)).toBe(0);
    expect(messaging.sendEachForMulticast).not.toHaveBeenCalled();
  });
});
