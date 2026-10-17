import { onCall } from 'firebase-functions/v2/https';

export const ping = onCall(() => ({ ok: true }));
