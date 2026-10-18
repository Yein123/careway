// Usage: node scripts/grant-admin.js <email> <password>
// Creates (if missing) a demo admin user and grants the `admin` custom claim.
// Uses Application Default Auth only: run `gcloud auth application-default login` first.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

async function main() {
  const [email, password] = process.argv.slice(2);
  if (!email || !password) {
    console.error('Usage: node scripts/grant-admin.js <email> <password>');
    process.exit(1);
  }
  initializeApp({ projectId: 'careway-tehwoq', credential: applicationDefault() });
  const auth = getAuth();
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await auth.createUser({ email, password, displayName: 'Demo admin' });
  }
  await auth.setCustomUserClaims(user.uid, { admin: true });
  await getFirestore().doc(`users/${user.uid}`).set({ name: 'Demo admin', email, role: 'admin' }, { merge: true });
  console.log(`Admin granted to ${email}. Sign out and in again to refresh the token.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
