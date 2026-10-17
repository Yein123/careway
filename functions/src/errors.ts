import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Business-rule failure. The client maps `details.code` to friendly copy:
 * seat-taken, group-full, offer-expired, off-duty, too-soon, level1-not-allowed,
 * no-patient, not-payable, addon-unavailable, summary-required, docs-missing, bad-request.
 */
export function fail(code: string, message: string): never {
  throw new HttpsError('failed-precondition', message, { code });
}

export function denied(message = 'Not allowed.'): never {
  throw new HttpsError('permission-denied', message);
}

export function requireAuth(auth: { uid: string } | undefined): string {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return auth.uid;
}
