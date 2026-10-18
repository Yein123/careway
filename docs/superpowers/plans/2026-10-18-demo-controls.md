# CareWay Demo Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let one presenter run three live demo scenarios on the deployed app from an `/admin` web page, with Android push, same-day booking, a Home delivery section, cancel confirmation and the real logos.

**Architecture:** Every admin control is a Cloud Function callable that checks the `admin` custom claim and reuses the existing booking/delivery logic. Shared transactions are pulled out of the scheduled jobs so the admin path and the scheduler run identical code. Push is a Firestore trigger on `users/{uid}/notifications`, which sends FCM to the tokens a device claims at sign-in. The Flutter side adds an `admin` user role and route, a `PushService`, a deliveries list, and small screen changes.

**Tech Stack:** Flutter 3.38 (Riverpod, go_router), Firebase Auth/Firestore/Functions v2 (TypeScript, Node 22), firebase-admin messaging, `firebase_messaging`, `flutter_local_notifications`, `flutter_launcher_icons`, Jest + Firestore emulator, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-18-demo-controls-design.md`

## Global Constraints

- Region `asia-southeast1`. Time zone for dates is MYT (UTC+8) via `mytDate`/`mytTime` in `functions/src/places.ts`.
- Demo accounts, all with password `careway123` (`DEMO_PASSWORD`):
  - `parent@gmail.com` — Siti (parent), patient Adam, 9, Child
  - `user@gmail.com` — Aisyah binti Hassan, patient Zainab binti Ahmad, 72, Parent
  - `self@gmail.com` — Hafiz bin Osman, 58, patient himself, relationship `Myself`
  - `caregiver@gmail.com` — Ravi S.
  - Extra caregivers kept: `farid@`, `nurul@`, `meiling@careway.demo`. Remove `aisyah@` and `ravi@careway.demo` from the seed.
- Demo groups have the id prefix `demo-`. Reset touches only the demo accounts' data and `demo-` groups.
- Same-day groups (pickup less than 24h away) have `lockAt: null` and lock only through `adminLockGroup`.
- Medicine notifications only on entering `collecting` and `delivered`.
- Copy:
  - too-soon error: "That time has already passed."
  - cancel dialog: title "Cancel this request?", body "We'll stop looking for a caregiver. Nothing has been charged.", buttons "Keep request" / "Yes, cancel"
- Push is Android only. Every push call is a no-op on web (`kIsWeb`).
- Never commit keys. `firebase_options.dart` and `google-services.json` stay gitignored. Commit messages have no Co-Authored-By/AI trailer.
- Icons:
  - guardian: `assets/images/careway-icon-512-square.png`, adaptive background `#6C4EE3`
  - caregiver: `assets/images/careway-caregiver-icon-512.png`

## Review Focus

1. **Booking a same-day slot whose pickup is already past** (the presenter leaves the page open): the server must reject it with `too-soon`, and the group list must hide those slots. Tests: Task 1 and Task 6.
2. **Pressing an admin button twice, or while the scheduler moves the same doc:** the second call fails with `failed-precondition` and leaves the data unchanged. Test in Task 4.
3. **Switching accounts on one phone:** after sign-out and sign-in as someone else, the old account no longer holds the token. Test in Task 5.
4. **Cancelling a confirmed same-day group booking before admin locks it:** treated as before lock (the before-lock refund rule), not after lock. Test in Task 1.
5. **Reset while a demo booking has a live offer to a non-demo caregiver doc:** the reset deletes those offers too, and leaves no orphaned `currentOfferId` behind. Test in Task 3.

---

### Task 1: Same-day booking rules (functions)

**Files:**
- Modify: `functions/src/booking/request.ts` (lines 26, 59, 119–152, and `joinGroup`)
- Modify: `functions/src/booking/cancel.ts:37-38`
- Test: `functions/test/booking_flow.test.ts`

**Interfaces:**
- Produces: `groupLockAt(pickupAt: Date, now: Date): Date | null` exported from `request.ts`. It returns `pickupAt − 24h` when that is after `now` (pickup ≥ 24h away), else `null`. Task 3 uses it.

- [ ] **Step 1: Write failing tests** in `booking_flow.test.ts`:
  - `same-day personal booking 3h ahead is accepted` → `requestBookingLogic` with `apptAt = NOW + 3h` resolves to status `pending_caregiver`.
  - `appointment in the past is rejected too-soon` → `apptAt = NOW − 1min` rejects with `details.code === 'too-soon'` and message `That time has already passed.`
  - `new same-day group has lockAt null and the founder's hold lasts until pickup` → level 1 `newGroup` with pickup `NOW + 2h`, appt `NOW + 3h`. The group doc has `lockAt === null`, `heldSeats[0].until` equals pickup, and the booking has `lockAt === null`.
  - `group 3 days out keeps lockAt = pickup − 24h`.
  - `joining a group whose pickup has passed is rejected too-soon`.
  - `cancelling a confirmed same-day group booking before admin lock uses the before-lock outcome` → confirmed booking in a group with `lockAt: null` and status `open`. The `cancelBookingLogic` result equals `cancelOutcome({..., afterLock: false})`.
- [ ] **Step 2: Run** `npm --prefix functions run test:emu -- -t "same-day|too-soon|lockAt"`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - Replace the `MIN_LEAD_MS` check with: reject if `apptAt <= now`, and (Level 1) if `pickupAt <= now`. Delete `MIN_LEAD_MS`.
  - Use `groupLockAt` wherever `pickupAt − 24h` was written.
  - The founder's hold `until` is `lockAt ?? pickupAt`.
  - `joinGroup` rejects `too-soon` when `toDate(g.pickupAt) <= now`.
  - In `cancel.ts`: `afterLock = group?.status === 'locked' || (lockAt != null && now >= lockAt)`, where for group bookings `lockAt = toDate(b.lockAt)` (no fallback) and personal bookings keep the `apptAt − 24h` fallback.
- [ ] **Step 4: Run** the same command. Expected: PASS. Then run all of `test:emu`: PASS.
- [ ] **Step 5: Commit** `feat(functions): allow same-day bookings; same-day groups lock only on demand`.

### Task 2: Shared lock/advance transactions and medicine notify filter

**Files:**
- Modify: `functions/src/booking/lock.ts`, `functions/src/delivery/progress.ts`
- Test: `functions/test/money_flow.test.ts` (lock), `functions/test/steps_delivery.test.ts` (delivery)

**Interfaces:**
- Produces:
  - `lockGroupTx(db: Firestore, groupId: string, now: Date): Promise<boolean>`: runs the existing per-group transaction (settle and refund) regardless of `lockAt`. It returns `false` when the group isn't `open`/`full`. `lockGroupsLogic` loops over due groups calling it.
  - `advanceDeliveryTx(db: Firestore, deliveryId: string, now: Date, opts: { force: boolean }): Promise<string | null>`: moves one stage and returns the new stage, or `null` if there is nothing to do. `force: false` keeps the 1-minute wait (scheduler). `force: true` skips it (admin).
  - `NOTIFY_STAGES = ['collecting', 'delivered']`.

- [ ] **Step 1: Write failing tests:**
  - `lockGroupTx locks a same-day group with lockAt null and refunds the price drop` → seed a group with `lockAt: null` and two confirmed riders. After `lockGroupTx`, status is `locked` and a refund receipt exists.
  - `lockGroupTx on a locked group returns false and writes nothing`.
  - `delivery notifies only at collecting and delivered` → a paid delivery advanced through all 5 transitions with `force: true`. Guardian notifications have titles exactly `["Medicine run: collecting the documents", "<patient>'s medicine was delivered"]`, and `steps` has all 6 keys.
  - `advanceDeliveryTx without force waits a minute` → returns `null` at `paidAt + 30s`.
- [ ] **Step 2: Run** `npm --prefix functions run test:emu -- -t "lockGroupTx|notifies only|waits a minute"`. Expected: FAIL.
- [ ] **Step 3: Implement** by extracting the existing transaction bodies, unchanged apart from the `force` flag and the `NOTIFY_STAGES` guard around `notifyTx`.
- [ ] **Step 4: Run** all of `test:emu`. Expected: PASS. The existing scheduler tests still pass.
- [ ] **Step 5: Commit** `refactor(functions): share lock/advance transactions; notify medicine only at collecting and delivered`.

### Task 3: Demo seed and reset for today

**Files:**
- Modify: `functions/src/seed.ts`
- Create: `functions/src/demo/reset.ts`
- Test: `functions/test/seed.test.ts` (new)

**Interfaces:**
- Consumes: `groupLockAt` (Task 1).
- Produces:
  - `DEMO_ACCOUNTS: Record<'parent'|'user'|'self'|'caregiver', { email: string; name: string }>`
  - `seedDemoLogic(db, auth, now): Promise<{ uids: Record<string,string>; groups: number; s3BookingId: string }>`
  - `resetDemoLogic(db, auth, now): Promise<{ deleted: number; seeded: Awaited<ReturnType<typeof seedDemoLogic>> }>`

Seed contents, beyond what the spec §4 fixes:
- **Families:**
  - `demo-parent-family` for Siti with patient `adam`: age 9, `Child`, mobility independent.
  - `demo-user-family` for Aisyah with `zainab`, keeping the current fields, plus `limahkow`.
  - `demo-self-family` for Hafiz with patient `hafiz`: 58, `Myself`, independent, contacts `[{ name: 'Hafiz', role: 'Patient' }]`.
- **Caregivers:** the existing list with `ravi@careway.demo` replaced by `caregiver@gmail.com`. `caregiver@gmail.com` gets skills `['wheelchair','transfer','consultSitIn','medicineCollection']` and certs `['firstAid','patientHandling','trainedEscort']`, so it qualifies for Level 2.
- **Group plan:** keep the same three pickup points, with the `denai-alam` helper now `caregiver@gmail.com`.
  - Days 2–8: the fixed times, as today.
  - **Today:** for each point, pickup = the next :00/:30 that is at least 30 min after `now`, staggered by +30 min per point. Skip it if the pickup falls after 21:00 MYT.
  - `lockAt = groupLockAt(pickupAt, now)`. Group ids are `demo-${date}-${pointId}`.
- **S3 visit:** booking id `demo-s3-visit`.
  - Family `demo-user-family`, patient `zainab`, level 2, `status: 'confirmed'`.
  - Caregiver fields as `respondToOfferLogic` writes them, for `caregiver@gmail.com`.
  - `apptAt = now + 60 min`, pickup Elmina home.
  - `payment: { method: 'fpx', paidAt: now }`, `price.paidSen` = the escort estimate.
  - A receipt, the access doc via `accessRef`, and a guardian notification "Visit confirmed".

- [ ] **Step 1: Write failing tests** in `seed.test.ts`:
  - `seed creates the four demo accounts with their patients` → auth users exist for all four emails. `self@gmail.com`'s family has one patient with `relationship === 'Myself'`.
  - `seed creates today's groups with lockAt null and pickups at least 30 min ahead`, at `now = 2026-10-17T02:00:00Z` (10:00 MYT).
  - `seed creates demo-s3-visit confirmed for caregiver@gmail.com, appt 1h ahead`.
  - `reset deletes demo bookings, deliveries, their offers, receipts, notifications and demo- groups, and keeps other docs` → seed, add a demo booking with an open offer to `nurul`, add a non-demo `groups/other` and `bookings/other`, reset. The demo booking and offer are gone, the `other` docs remain, and `demo-s3-visit` exists again.
  - `reset is idempotent` → two resets in a row give the same doc counts.
- [ ] **Step 2: Run** `npm --prefix functions run test:emu -- seed.test`. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - `resetDemoLogic` resolves the demo uids by email (missing ones are skipped). It then queries `bookings`/`deliveries`/`receipts` by `familyId in [demo family ids]`, offers by `bookingId`/`deliveryId` in those ids (chunks of 30), each demo user's `notifications`, and groups by `__name__` prefix `demo-` (range query `>= 'demo-'`, `< 'demo.'`).
  - Deletes run in `BulkWriter`. Then it calls `seedDemoLogic`.
- [ ] **Step 4: Run.** Expected: PASS, and the whole `test:emu` passes. Update the `seedFamily`-independent tests that referenced `aisyah@careway.demo`, if any (`grep -rn "careway.demo" functions/test functions/scripts`).
- [ ] **Step 5: Commit** `feat(functions): gmail demo accounts, today's groups, scenario 3 visit and demo reset`.

### Task 4: Admin callables, claim script and admin read rules

**Files:**
- Create: `functions/src/admin/admin.ts`, `functions/scripts/grant-admin.js`
- Modify: `functions/src/errors.ts` (add `requireAdmin`), `functions/src/index.ts`, `firestore.rules`
- Test: `functions/test/admin.test.ts` (new), `functions/test/rules.test.ts`

**Interfaces:**
- Consumes:
  - `respondToOfferLogic` and `advanceStepLogic` (existing)
  - `offerNext` (existing)
  - `lockGroupTx` and `advanceDeliveryTx` (Task 2)
  - `resetDemoLogic` (Task 3)
- Produces (callable names and inputs, used by Task 11):
  - `requireAdmin(auth: { uid: string; token?: Record<string, unknown> } | undefined): string`: `unauthenticated` when signed out, `permission-denied` unless `token.admin === true`.
  - `adminReset({})` → `{ deleted }`
  - `adminRespondOffer({ col: 'bookings'|'deliveries', id, accept: boolean })` → `{ status }`. Reads the target's `currentOfferId`, loads the offer, and calls `respondToOfferLogic(db, offer.caregiverId, { offerId, accept }, now)`. With no `currentOfferId` it fails `no-offer` ("No open offer for this request.").
  - `adminNotFound({ col, id })` → `{ status: 'not_matched' }`. In one transaction it requires `status === 'pending_caregiver'`, marks the current offer `expired`, and sets `offeredUids` to the union of `offeredUids` and `rankedUids`. Then it calls `offerNext(db, col, id, now, currentOfferId)`, which takes the existing exhausted-cascade path.
  - `adminLockGroup({ groupId })` → `{ locked: boolean }`. `false` fails `not-lockable`.
  - `adminAdvanceDelivery({ id, toEnd?: boolean })` → `{ stage }`. Loops `advanceDeliveryTx(force: true)` while `toEnd`. Fails `not-active` if the first call returns `null`.
  - `adminAdvanceStep({ bookingId })` → `{ step }`, as the booking's `caregiverId`.
- Each pure function `adminXLogic(db, input, now)` lives in `admin.ts`. `index.ts` wraps each one with `onCall((req) => { requireAdmin(req.auth); return adminXLogic(db(), req.data, new Date()); })`. `adminReset` also passes `getAuth()`.
- Rules: `function isAdmin() { return signedIn() && request.auth.token.admin == true; }`. Add `allow read: if isAdmin();` to `bookings`, `deliveries`, `offers`, `groups`, `users/{uid}`, `families/{fid}` and its `patients`. No write changes.
- `grant-admin.js <email> <password>` initialises firebase-admin with `projectId: 'careway-tehwoq'` and application default credentials, then creates the user if missing. It sets the custom claims `{ admin: true }` and `users/{uid}` to `{ name: 'Demo admin', email, role: 'admin' }`, and prints `Admin granted to <email>. Sign out and in again to refresh the token.`

- [ ] **Step 1: Write failing tests** in `admin.test.ts`:
  - `requireAdmin rejects a missing or false claim`, as `permission-denied`.
  - `adminRespondOffer accept makes the booking awaiting_payment for the offered caregiver and notifies the guardian`.
  - `adminRespondOffer reject cascades to the next caregiver` → with two seeded caregivers, the second gets the new `currentOfferId`.
  - `adminRespondOffer twice: second call fails no-offer` (Review Focus 2).
  - `adminNotFound ends as not_matched with the not-matched notification`.
  - `adminLockGroup locks a lockAt-null group, and a second call fails not-lockable`.
  - `adminAdvanceDelivery toEnd reaches delivered`.
  - `adminAdvanceStep records picked_up as the assigned caregiver`.

  In `rules.test.ts`: `admin token reads any booking, group, offer and family`, and `admin token cannot write bookings`, using `env.authenticatedContext('adm', { admin: true })`.
- [ ] **Step 2: Run** `npm --prefix functions run test:emu -- admin.test rules.test`. Expected: FAIL.
- [ ] **Step 3: Implement** as described in Interfaces.
- [ ] **Step 4: Run** all of `test:emu` and `npm --prefix functions run build`. Expected: PASS, and tsc reports no errors.
- [ ] **Step 5: Commit** `feat(functions): admin demo callables, grant-admin script and admin read rules`.

### Task 5: Push delivery (functions)

**Files:**
- Create: `functions/src/push.ts`
- Modify: `functions/src/index.ts`
- Test: `functions/test/push.test.ts` (new)

**Interfaces:**
- Produces:
  - `claimPushTokenLogic(db, uid, { token: string }): Promise<{ ok: true }>`: removes `token` from every `users` doc where `fcmTokens array-contains token` (except `uid`), then `arrayUnion` adds it on `users/{uid}`. The token must be a non-empty string of at most 4096 chars; otherwise it fails `bad-request`.
  - `releasePushTokenLogic(db, uid, { token })`: `arrayRemove` on `users/{uid}`.
  - `sendPushLogic(db, messaging: Pick<Messaging,'sendEachForMulticast'>, uid, n: { title: string; body: string; link: string | null }): Promise<number>`:
    - sends to `users/{uid}.fcmTokens` with `notification: { title, body }`, `data: { link: link ?? '' }` and `android: { priority: 'high', notification: { channelId: 'careway_updates' } }`
    - removes tokens whose error code is `messaging/registration-token-not-registered` or `messaging/invalid-argument`
    - returns the success count, and 0 with no tokens
  - Exports: `claimPushToken` and `releasePushToken` (`onCall` with `requireAuth`), and `onNotificationCreated = onDocumentCreated('users/{uid}/notifications/{nid}', …)`, which calls `sendPushLogic` with `getMessaging()` and catches/logs errors.

- [ ] **Step 1: Write failing tests:**
  - `claimPushToken moves the token from another user` → `u1` has `fcmTokens:['t1']`. After `u2` claims `t1`, `u1` has `[]` and `u2` has `['t1']` (Review Focus 3).
  - `releasePushToken removes it`.
  - `sendPush prunes unregistered tokens` → a stub messaging returns `[success, error(registration-token-not-registered)]` for `['a','b']`. Afterwards `fcmTokens` is `['a']`, the return is 1, and the stub received `android.notification.channelId === 'careway_updates'`.
  - `sendPush with no tokens returns 0 without calling messaging`.
- [ ] **Step 2: Run** `npm --prefix functions run test:emu -- push.test`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** all of `test:emu` and `build`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(functions): FCM push on new notifications with per-device token claim`.

### Task 6: Same-day booking in the app

**Files:**
- Modify:
  - `lib/features/booking/booking_draft.dart:153-155` (`dayBookable`)
  - `lib/features/booking/book_screen.dart:255-258` (calendar stays open)
  - `lib/data/models/group.dart` (`lockAt` becomes `DateTime?`)
  - `lib/features/booking/booking_common.dart:45-48` (`afterLock`)
  - `lib/features/booking/payment_screen.dart:210`
  - `lib/features/booking/group_list_screen.dart` (hide groups whose `pickupAt` is not after now)
- Test: `test/domain/booking_status_test.dart`, `test/features/booking_flow_test.dart`

**Interfaces:**
- Produces: `bool dayBookable(DateTime day, DateTime now)`, which is true when `day`'s local date is on or after `now`'s local date. `afterLock(Booking b, DateTime now)`: when `b.groupId != null && b.lockAt == null`, it returns `false`. Otherwise it is unchanged.
- Payment copy with a null `lockAt` on a group booking: "When the group is set before pickup, you get the difference back automatically. " (it replaces the `dayTimeLabel(...)` clause).

- [ ] **Step 1: Write failing tests:**
  - `dayBookable allows today and refuses yesterday`
  - `afterLock is false for a same-day group booking without lockAt`
  - widget: `calendar stays open after picking a date` → on `/book`, tap the today cell, and the `_Calendar` month header text is still found
  - widget: `group list hides a group whose pickup has passed` → fake groups at `now − 10 min` and `now + 2 h`, and only the second card shows
- [ ] **Step 2: Run** `flutter test test/domain/booking_status_test.dart test/features/booking_flow_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** In `onPick`, remove `_calOpen = false`; the field button still toggles it.
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: no issues, all pass.
- [ ] **Step 5: Commit** `feat(app): book for today; calendar stays open; same-day groups have no lock time`.

### Task 7: Cancel confirmation on pending booking

**Files:**
- Modify: `lib/features/booking/pending_screen.dart:143-158`
- Test: `test/features/booking_status_test.dart`

**Interfaces:**
- Produces: `Future<bool> confirmCancelRequest(BuildContext context)` in `pending_screen.dart`. It shows an `AlertDialog` with the copy from Global Constraints and returns `true` only on "Yes, cancel". "Keep request" is a `TextButton`. "Yes, cancel" is a `FilledButton` with `CwColors.danger` background (or the existing danger token in `theme.dart`).

- [ ] **Step 1: Write failing tests:**
  - `Cancel request asks first; Keep request does not cancel` → tap "Cancel request", expect "Cancel this request?", tap "Keep request", and `FakeApi.cancelled` is empty.
  - `Yes, cancel cancels and goes home` → `FakeApi.cancelled == [id]` and the location is `/home`. Add a `cancelled` list to `FakeApi` if it doesn't exist.
- [ ] **Step 2: Run** `flutter test test/features/booking_status_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** The `onPressed` awaits `confirmCancelRequest` and returns early on `false`.
- [ ] **Step 4: Run** `flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): confirm before cancelling a pending request`.

### Task 8: Home delivery section and Medicine deliveries list

**Files:**
- Create: `lib/features/delivery/delivery_list_screen.dart`
- Modify:
  - `lib/data/providers.dart` (add `familyDeliveriesProvider`)
  - `lib/features/home/home_screen.dart` (section after Upcoming)
  - `lib/core/router.dart` (`/deliveries`, inside the guardian shell's home branch, so the tab bar stays)
- Test: `test/features/delivery_test.dart`, `test/features/home_test.dart`

**Interfaces:**
- Consumes: `DeliveryRepo.watchForFamily(fid)` (existing), `deliveryStageKeys` and `deliveryStageLabels` (existing).
- Produces:
  - `final familyDeliveriesProvider = StreamProvider<List<MedDelivery>>`, newest `createdAt` first, empty without a family.
  - `bool isDeliveryInProgress(MedDelivery d)`: true for `pendingCaregiver`, `awaitingPayment`, `booked` … `onTheWay`.
  - `class DeliveryProgressCard extends StatelessWidget { const DeliveryProgressCard(this.delivery); }`: the canvas card, using `CwColors.deliveryBlue` for done segments, `Color(0xFF8FB0DA)` for the current one and `Color(0xFFE3ECF8)` for upcoming ones. The footer reads `"${deliveryStageLabels[stage]} · ${caregiverName ?? 'Finding a helper'}"` and `Track ›`, and tapping opens `/delivery/:id/live`. For `pendingCaregiver`/`awaitingPayment` the chip reads `Pending`/`Pay to confirm` instead of `Live`, and tapping opens `/delivery/:id`.
  - `class DeliveredRow`: "{EEE d MMM} · {first name}", "{pharmacyName}", a green `Delivered` chip, and it opens `/delivery/:id/done`.
  - `DeliveryListScreen` (`/deliveries`): back button, title "Medicine deliveries", subtitle "Track and look back at every delivery", sections "In progress" / "Delivered", empty text "No deliveries yet", and a bottom "New delivery" button → `/delivery/new`.
- Home section title "Medicine delivery" with count = number in progress, `See all` → `/deliveries`:
  - body = progress cards for in-progress deliveries
  - else the latest delivered one as a `DeliveredRow`
  - hidden when the list is empty

- [ ] **Step 1: Write failing tests:**
  - home: `no deliveries hides the Medicine delivery section`
  - home: `in-progress delivery shows a card with stage label and Track`, at status `atPharmacy` with "At the pharmacy · Farid A."; tapping it goes to `/delivery/d1/live`
  - home: `only delivered shows the latest delivered row`
  - delivery: `deliveries list groups In progress and Delivered and New delivery opens the request`

  Extend `guardianFakes` with an optional `deliveries:` parameter and add a `delivery({status, steps})` fixture.
- [ ] **Step 2: Run** `flutter test test/features/home_test.dart test/features/delivery_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): medicine delivery section on Home and a deliveries list`.

### Task 9: Logos and app icon

**Files:**
- Modify:
  - `lib/core/widgets/cw_page.dart:83-115` (`CwLogo`)
  - `lib/features/auth/sign_in_screen.dart:~265-300` (caregiver header mark)
  - caregiver home header in `lib/features/caregiver/cg_home_screen.dart`, if it shows the brand
  - `pubspec.yaml`
- Generated: `android/app/src/main/res/mipmap-*/`, `web/icons/*`, `web/favicon.png`, `web/manifest.json`
- Test: `test/core/widgets_test.dart`

**Interfaces:**
- Produces: `CwLogo({Color color, String? label, bool caregiver = false})`. It draws `Image.asset(caregiver ? 'assets/images/careway-caregiver-icon-512.png' : 'assets/images/careway-icon-512-square.png', width: 40, height: 40)` clipped with radius 12, with the existing wordmark and label. `color` is kept for API compatibility and no longer used, so remove it if there are no other callers. Delete `logoSvg` from `lib/core/art.dart` if it becomes unused.
- `pubspec.yaml` dev dependency `flutter_launcher_icons`, with this config:
  - `android: true`, `image_path: assets/images/careway-icon-512-square.png`
  - `adaptive_icon_background: "#6C4EE3"`, `adaptive_icon_foreground: assets/images/careway-icon-512-square.png`
  - `web: { generate: true, image_path: …, background_color: "#6C4EE3", theme_color: "#6C4EE3" }`

- [ ] **Step 1: Write failing tests:**
  - `CwLogo shows the guardian image`, finding an `Image` whose `AssetImage.assetName` ends with `careway-icon-512-square.png`
  - `CwLogo caregiver shows the caregiver image`
- [ ] **Step 2: Run** `flutter test test/core/widgets_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Use `CwLogo(caregiver: true, label: 'Caregiver')` in the caregiver sign-in header (white wordmark, so add a `light` flag to `CwLogo` if the wordmark colour needs to be white there). Then run `dart run flutter_launcher_icons`.
- [ ] **Step 4: Run** `flutter analyze && flutter test`, then `flutter build apk --debug`. Expected: PASS, build succeeds, and `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` exists.
- [ ] **Step 5: Commit** `feat(app): CareWay and caregiver logos, launcher and web icons`.

### Task 10: Push in the app (Android)

**Files:**
- Create: `lib/data/push.dart`
- Modify:
  - `pubspec.yaml` (add `firebase_messaging` and `flutter_local_notifications`)
  - `android/app/src/main/AndroidManifest.xml` (`POST_NOTIFICATIONS`; default channel meta-data `com.google.firebase.messaging.default_notification_channel_id` = `careway_updates`)
  - `android/app/build.gradle.kts` (core library desugaring, if `flutter_local_notifications` requires it)
  - `lib/data/api.dart` (`claimPushToken`, `releasePushToken`)
  - `lib/data/providers.dart` (`pushServiceProvider`)
  - `lib/app.dart` (start the service)
  - `lib/features/account/account_screen.dart:458` and `lib/features/caregiver/cg_tabs.dart:471` (sign out through a shared helper)
- Test: `test/data/push_test.dart` (new), `test/fakes/fake_api.dart`

**Interfaces:**
- Produces:
  - `CareWayApi.claimPushToken(String token)` and `CareWayApi.releasePushToken(String token)`, calling the Task 5 callables.
  - `abstract class PushPlatform { Future<bool> requestPermission(); Future<String?> getToken(); Stream<String> get onTokenRefresh; Stream<PushMessage> get onForeground; Stream<String> get onOpenedLink; Future<String?> initialLink(); Future<void> showLocal(PushMessage m); }` with `class PushMessage { final String title, body; final String link; }`. `FirebasePushPlatform` implements it with `FirebaseMessaging` and `FlutterLocalNotificationsPlugin` (channel `careway_updates`, "CareWay updates", importance high; payload = link).
  - `class PushService { PushService(this._platform, this._api, this._go); Future<void> onSignedIn(); Future<void> beforeSignOut(); void dispose(); }`:
    - `onSignedIn` requests permission, gets the token and calls `claimPushToken`. It also subscribes to refresh (claiming the new token), foreground (`showLocal`) and opened links (`_go(link)` when the link is non-empty).
    - `beforeSignOut` calls `releasePushToken` with the current token, ignoring errors.
  - `pushServiceProvider` is null on web. `CareWayApp` listens to `authStateProvider`: a non-null uid calls `onSignedIn`.
  - `Future<void> signOutEverywhere(WidgetRef ref)` in `lib/data/push.dart` awaits `beforeSignOut`, then `authRepo.signOut()`. Both sign-out buttons use it.

- [ ] **Step 1: Write failing tests** in `push_test.dart`, with a `FakePushPlatform` and `FakeApi`:
  - `onSignedIn claims the token`
  - `token refresh claims the new token`
  - `foreground message is shown locally`
  - `opened notification navigates to its link`
  - `beforeSignOut releases the token`
  - `beforeSignOut swallows API errors`
- [ ] **Step 2: Run** `flutter test test/data/push_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze && flutter test && flutter build apk --debug`. Expected: PASS and the build succeeds.
- [ ] **Step 5: Commit** `feat(app): Android push notifications that follow the signed-in account`.

### Task 11: Admin page

**Files:**
- Create: `lib/features/admin/admin_screen.dart`, `lib/features/admin/admin_providers.dart`
- Modify:
  - `lib/data/models/user.dart` (`enum UserRole { guardian, caregiver, admin }`)
  - `lib/core/router.dart` (`/admin` route and redirect)
  - `lib/data/api.dart` (admin methods)
  - `test/fakes/fake_api.dart`
- Test: `test/features/admin_test.dart` (new)

**Interfaces:**
- Consumes: the Task 4 callables.
- Produces:
  - `CareWayApi` methods:
    - `adminReset()`
    - `adminRespondOffer(String col, String id, bool accept)`
    - `adminNotFound(String col, String id)`
    - `adminLockGroup(String groupId)`
    - `adminAdvanceDelivery(String id, {bool toEnd = false})`
    - `adminAdvanceStep(String bookingId)`
  - `roleRedirect`: an admin user goes to `/admin` from anywhere except `/admin`. Non-admins on `/admin` go to their home (`/home` or `/cg`).
  - `admin_providers.dart`:
    - `adminBookingsProvider` streams `bookings` where `status in ['pending_caregiver','awaiting_payment','confirmed','in_progress']`, ordered by `createdAt desc`, limit 30
    - `adminDeliveriesProvider` streams deliveries with status `in` the non-terminal wire values, same ordering
    - `adminS3Provider` watches `bookings/demo-s3-visit`
    - all three through `FirebaseFirestore` behind a small `AdminRepo` interface so tests can fake it
  - `AdminScreen` layout:
    - header "CareWay demo admin", a **Reset demo for today** button, a **Sign out** button
    - section "Live requests": one row per item showing guardian name, patient, type chip (`Group`/`Escort`/`Medicine`), status chip, and buttons by rule:

      | Status | Buttons |
      |---|---|
      | `pending_caregiver` | Accept, Reject, Not found |
      | Level 1 `confirmed` with a `groupId` | Group set |
      | delivery `booked`…`on_the_way` | Next stage, Run to delivered |

    - section "Caregiver visit": the current step label (from `steps.last.key`, or "Not started") and **Advance step**
    - Each button shows a spinner while its call runs. Errors go to a snackbar via `friendlyError`.
    - Wide layout: `LayoutBuilder` puts the sections in two columns at ≥ 900 px.

- [ ] **Step 1: Write failing tests:**
  - `admin user lands on /admin`
  - `guardian visiting /admin is sent to /home`
  - `pending booking row shows Accept/Reject/Not found and Accept calls adminRespondOffer('bookings', id, true)`
  - `paid delivery row shows Next stage and Run to delivered`
  - `Reset demo for today calls adminReset`
  - `Caregiver visit shows the step and Advance step calls adminAdvanceStep('demo-s3-visit')`
- [ ] **Step 2: Run** `flutter test test/features/admin_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(app): demo admin page`.

### Task 12: Deploy, docs and live check

**Files:**
- Modify: `README.md` (demo accounts table, admin setup with `grant-admin.js`, the three-scenario run sheet), `firestore.indexes.json` (any index the new queries request)

- [ ] **Step 1:** Run `npm --prefix functions test && npm --prefix functions run test:emu && flutter analyze && flutter test`. Expected: all pass.
- [ ] **Step 2:** In the emulator, run `firebase emulators:exec --only auth,firestore,functions "node functions/scripts/e2e-emulator.js"`. Expected: passes. Update its emails if it used `aisyah@careway.demo`.
- [ ] **Step 3:** Ask the user before deploying. Then run `firebase deploy --only firestore:rules,firestore:indexes,functions --project careway-tehwoq` and `flutter build web` (plus hosting, if used) and `flutter build apk --release`. Expected: deploy succeeds.
- [ ] **Step 4:** The user runs `gcloud auth application-default login`, then `node functions/scripts/grant-admin.js admin@careway.demo <password>`. Sign in on web, so you land on `/admin`, and press **Reset demo for today**.
- [ ] **Step 5: Manual check:**
  - Install the APK, sign in as `user@gmail.com`, and book today's group. On admin press **Accept**: a push arrives within a few seconds.
  - Sign out and sign in as `caregiver@gmail.com`. Press Accept on another request: no push reaches the caregiver phone for the guardian's events.
  - The S3 visit's steps advance from the phone.
- [ ] **Step 6: Commit** `docs: demo accounts, admin setup and run sheet`.
