import { readFileSync } from 'fs';
import { resolve } from 'path';
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where, writeBatch } from 'firebase/firestore';
import { describeEmu, PROJECT } from './helpers';

let env: RulesTestEnvironment;

describeEmu('firestore rules', () => {
  beforeAll(async () => {
    const [host, port] = process.env.FIRESTORE_EMULATOR_HOST!.split(':');
    env = await initializeTestEnvironment({
      projectId: PROJECT,
      firestore: { rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8'), host, port: Number(port) },
    });
  });
  afterAll(async () => env?.cleanup());

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/g1'), { name: 'Aisyah', role: 'guardian', familyId: 'f1' });
      await setDoc(doc(db, 'users/g2'), { name: 'Other', role: 'guardian', familyId: 'f2' });
      await setDoc(doc(db, 'families/f1'), { name: 'Ahmad family', adminUid: 'g1', memberUids: ['g1'] });
      await setDoc(doc(db, 'families/f2'), { name: 'Other family', adminUid: 'g2', memberUids: ['g2'] });
      await setDoc(doc(db, 'families/f1/patients/p1'), { name: 'Zainab', age: 72 });
      await setDoc(doc(db, 'caregivers/cg1'), { displayName: 'Nurul', onDuty: true, rating: 4.9 });
      await setDoc(doc(db, 'bookings/b1'), { familyId: 'f1', caregiverId: 'cg1', status: 'completed', patientId: 'p1' });
      await setDoc(doc(db, 'bookings/b2'), { familyId: 'f1', caregiverId: 'cg1', status: 'confirmed', patientId: 'p1' });
      await setDoc(doc(db, 'groups/grp'), { hospitalId: 'hsb', date: '2026-10-26', status: 'open' });
      await setDoc(doc(db, 'offers/o1'), { caregiverId: 'cg1', status: 'offered' });
      await setDoc(doc(db, 'users/g1/notifications/n1'), { title: 'Hi', read: false });
      await setDoc(doc(db, 'receipts/r1'), { uid: 'g1', familyId: 'f1', amountSen: 2200 });
    });
  });

  const as = (uid: string) => env.authenticatedContext(uid).firestore();

  test('guardian cannot make themselves a caregiver', async () => {
    await assertFails(setDoc(doc(as('new'), 'users/new'), { name: 'X', role: 'caregiver' }));
    await assertSucceeds(setDoc(doc(as('new'), 'users/new'), { name: 'X', role: 'guardian', familyId: null }));
    await assertFails(updateDoc(doc(as('g1'), 'users/g1'), { role: 'caregiver' }));
    await assertSucceeds(updateDoc(doc(as('g1'), 'users/g1'), { name: 'Aisyah H.' }));
  });

  test('new user can create their family and link it', async () => {
    const db = as('new');
    await assertSucceeds(setDoc(doc(db, 'users/new'), { name: 'X', role: 'guardian', familyId: null }));
    const b = writeBatch(db);
    b.set(doc(db, 'families/fnew'), { name: 'X family', adminUid: 'new', memberUids: ['new'] });
    b.update(doc(db, 'users/new'), { familyId: 'fnew' });
    await assertSucceeds(b.commit());
    // Can't join someone else's family by editing familyId.
    await assertFails(updateDoc(doc(db, 'users/new'), { familyId: 'f1' }));
  });

  test('family patients: members only', async () => {
    await assertSucceeds(getDoc(doc(as('g1'), 'families/f1/patients/p1')));
    await assertSucceeds(setDoc(doc(as('g1'), 'families/f1/patients/p2'), { name: 'Lim', age: 80 }));
    await assertFails(getDoc(doc(as('g2'), 'families/f1/patients/p1')));
    await assertFails(setDoc(doc(as('g2'), 'families/f1/patients/p3'), { name: 'X' }));
  });

  test('caregiver reads a patient only with active access', async () => {
    await assertFails(getDoc(doc(as('cg1'), 'families/f1/patients/p1')));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'families/f1/patients/p1/access/cg1'), { bookingId: 'b2' });
    });
    await assertSucceeds(getDoc(doc(as('cg1'), 'families/f1/patients/p1')));
    await assertFails(setDoc(doc(as('cg1'), 'families/f1/patients/p1'), { name: 'changed' }));
  });

  test('clients cannot write bookings, offers, groups or receipts', async () => {
    await assertFails(setDoc(doc(as('g1'), 'bookings/x'), { familyId: 'f1', status: 'confirmed' }));
    await assertFails(updateDoc(doc(as('g1'), 'bookings/b2'), { status: 'completed' }));
    await assertFails(updateDoc(doc(as('cg1'), 'offers/o1'), { status: 'accepted' }));
    await assertFails(setDoc(doc(as('g1'), 'groups/new'), { status: 'open' }));
    await assertFails(setDoc(doc(as('g1'), 'receipts/x'), { uid: 'g1', amountSen: 1 }));
  });

  test('guardian may only rate their completed booking', async () => {
    await assertSucceeds(updateDoc(doc(as('g1'), 'bookings/b1'), { rating: { stars: 5, tags: [], text: '' } }));
    await assertFails(updateDoc(doc(as('g1'), 'bookings/b2'), { rating: { stars: 5 } }));
    await assertFails(updateDoc(doc(as('g2'), 'bookings/b1'), { rating: { stars: 1 } }));
    await assertFails(updateDoc(doc(as('g1'), 'bookings/b1'), { rating: { stars: 5 }, price: {} }));
  });

  test('bookings readable by the family and the assigned caregiver', async () => {
    await assertSucceeds(getDoc(doc(as('g1'), 'bookings/b1')));
    await assertSucceeds(getDoc(doc(as('cg1'), 'bookings/b1')));
    await assertFails(getDoc(doc(as('g2'), 'bookings/b1')));
    await assertSucceeds(getDocs(query(collection(as('g1'), 'bookings'), where('familyId', '==', 'f1'))));
    await assertSucceeds(getDocs(query(collection(as('cg1'), 'bookings'), where('caregiverId', '==', 'cg1'))));
  });

  test('notifications: owner reads and marks read only', async () => {
    await assertSucceeds(getDoc(doc(as('g1'), 'users/g1/notifications/n1')));
    await assertSucceeds(updateDoc(doc(as('g1'), 'users/g1/notifications/n1'), { read: true }));
    await assertFails(updateDoc(doc(as('g1'), 'users/g1/notifications/n1'), { title: 'x' }));
    await assertFails(setDoc(doc(as('g1'), 'users/g1/notifications/n2'), { title: 'fake' }));
    await assertFails(getDoc(doc(as('g2'), 'users/g1/notifications/n1')));
  });

  test('groups readable by signed-in users; offers by their caregiver', async () => {
    await assertSucceeds(getDoc(doc(as('g2'), 'groups/grp')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'groups/grp')));
    await assertSucceeds(getDoc(doc(as('cg1'), 'offers/o1')));
    await assertFails(getDoc(doc(as('g1'), 'offers/o1')));
  });

  test('caregiver can toggle only their own duty status', async () => {
    await assertSucceeds(updateDoc(doc(as('cg1'), 'caregivers/cg1'), { onDuty: false }));
    await assertFails(updateDoc(doc(as('cg1'), 'caregivers/cg1'), { rating: 5 }));
    await assertFails(updateDoc(doc(as('g1'), 'caregivers/cg1'), { onDuty: false }));
  });

  test('receipts readable by owner', async () => {
    await assertSucceeds(getDocs(query(collection(as('g1'), 'receipts'), where('uid', '==', 'g1'))));
    await assertFails(getDoc(doc(as('g2'), 'receipts/r1')));
  });
});
