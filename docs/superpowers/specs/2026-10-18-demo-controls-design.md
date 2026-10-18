# CareWay Demo Controls — Design Spec

Date: 2026-10-18
Builds on: `2026-10-17-careway-app-design.md`
Source design: Claude Design canvas "CareWay App" (https://claude.ai/artifact/Ma9WUEARAsaM2fWnyYkkCt), artboards 2 · Home and 38 · Medicine deliveries (list).

## 1. Purpose

The app is going to be demoed live on the **deployed** Firebase project (`careway-tehwoq`). Today a demo depends on timers (18-minute offer expiry, 5-minute group lock, 1-minute delivery steps) and on a caregiver signing in to respond. The goal: one presenter runs three scenarios on cue from an admin web page, and every state change shows up on the phone within a second or two, with a real Android push notification.

### The three demo scenarios
1. **Guardian books for a parent or child.** Aisyah books for Zainab (Parent, 72) or Adam (Child).
2. **Individual books for themselves.** Hafiz books for himself (patient relationship "Myself").
3. **Caregiver updates a visit.** Ravi works through the steps of a confirmed visit for today, and the guardian follows it live.

### Decided by the user
- Controls live on an **`/admin` web page** in the same Flutter web build, used only by an account with the `admin` custom claim.
- Admin can: reseed demo data for today, add groups for today, **accept and reject on behalf of the caregiver**, force "not found", lock a group ("group set"), and move medicine deliveries forward.
- **Real push notifications** (FCM), **Android APK only**.
- Demo uses **one phone**, so accounts are switched on the same device.
- Scenario 3 uses a **pre-made visit**, so it works whether or not scenario 1 ran.
- Home gets the **medicine delivery section** from the canvas, with **See all** opening a new **Medicine deliveries** list. This is the way into delivery status (not the Visits tab).
- The CareWay logo (`assets/images/careway-icon-512-square.png`) is the app icon and in-app logo.
- **Cancel request** on a pending booking asks for confirmation.
- Medicine delivery notifies **only** at *collecting the documents* and *delivered*.
- **Appointments can be booked for today.** Days less than 24 hours away are no longer greyed out. A booking is allowed as long as its pickup time is still ahead.
- **Same-day groups never auto-lock.** They lock only through the admin page.
- After a date is selected, the **calendar stays open**.

### Assumptions
- `careway-caregiver-icon-512.png` is used as the logo on the caregiver sign-in screen and caregiver shell. The launcher icon is the main CareWay icon, since one APK has one launcher icon.
- The new individual account is `hafiz@careway.demo` (Hafiz bin Osman, 58, Elmina, lives alone), password `careway123` like the other demo accounts.
- Aisyah's family gains a child patient: Adam, 9, relationship Child. Children under 18 already get Level 2 under the existing rules.
- For scenario 3 the guardian side is shown on a laptop browser (Flutter web, signed in as Aisyah) next to the admin page, because the phone is signed in as Ravi. Web gets the in-app live updates but no system push.
- The admin account is a separate email (e.g. `admin@careway.demo`) created once by the grant script. It is not a guardian or caregiver.

### Out of scope
Web push, iOS, a production operations console (user management, refunds UI, analytics), wording changes for self-booking.

## 2. Admin page (`/admin`)

### Access
- Route `/admin` in `lib/core/router.dart`, outside the guardian/caregiver shells. The redirect sends signed-out users to `/signin?next=/admin`. Signed-in users without the `admin` claim (`getIdTokenResult().claims['admin'] == true`) see a "Not authorised" page.
- The sign-in screen routes an admin account to `/admin` after sign-in.
- Laid out for a laptop (wide, two or three columns). At narrow widths it stacks into one column.

### Layout
A header with **Reset all for today** and **Send push**, then one panel per scenario:

| Panel | Prepare | Live state shown | Controls |
|---|---|---|---|
| **S1 · Guardian (Aisyah)** | Reset Aisyah's family data and add today's groups | Aisyah's non-terminal bookings and deliveries, each with status chip, offered caregiver, offer expiry | Booking: **Accept**, **Reject**, **Not found**, **Lock group now** (Level 1 only). Delivery: **Accept**, **Reject**, **Next stage**, **Run to delivered** |
| **S2 · Individual (Hafiz)** | Reset Hafiz's data and add today's groups | Hafiz's non-terminal bookings | Same booking controls as S1 |
| **S3 · Caregiver (Ravi)** | Create a confirmed, paid Level 2 visit today for Zainab, assigned to Ravi, about 1 hour from now | That visit's current step and timeline | **Advance step** (backup for tapping on the phone) |

The "Waiting" state needs no button: a booking sits in `pending_caregiver` until Accept, Reject or Not found is pressed. The panel shows it as **Waiting for caregiver**.

Buttons only enable when their action is valid for the row's current status (for example, Accept only while an offer is `offered`). While a call is running the button shows a spinner. On error a snackbar shows the server message.

**Send push**: pick a demo user (a dropdown of seeded accounts), enter title and body, and optionally a link. It writes a normal notification, so it shows up in the in-app list and as a push.

### Data
The page streams `bookings`, `deliveries`, `offers` and `groups` filtered to demo families and caregivers, with an `admin` read rule (§6). Live status updates without refreshing.

## 3. Admin callables (Cloud Functions)

All of these live in `functions/src/admin/` and are exported from `index.ts`. Each one starts with `requireAdmin(req.auth)`: `permission-denied` unless `token.admin === true`. Each one reuses the existing logic, so notifications, receipts, refunds and caregiver access behave exactly as in real use.

| Callable | Input | Behaviour |
|---|---|---|
| `adminRespondOffer` | `{ targetCol: 'bookings'\|'deliveries', id, accept: boolean }` | Finds the current `offered` offer for the target and calls `respondToOfferLogic` **as that offer's caregiver**. On reject the existing cascade offers the next caregiver. `failed-precondition` if there's no open offer |
| `adminForceNotFound` | `{ targetCol, id }` | Marks the open offer `expired` and ends the target as `not_matched`, through the same code path `offerNext` uses when the list runs out (guardian gets the existing "not found" notification) |
| `adminLockGroup` | `{ groupId }` | Runs the lock/settle body of `lockGroupsLogic` for one group, ignoring `lockAt`. The per-group transaction is extracted into `lockGroupTx(db, groupRef, now)` and the scheduled job calls the same function |
| `adminAdvanceDelivery` | `{ deliveryId, toEnd?: boolean }` | Moves a paid delivery one stage (or every remaining stage) using the transition extracted from `progressDeliveriesLogic` (`advanceDeliveryTx`). It skips the 1-minute wait |
| `adminAdvanceStep` | `{ bookingId }` | Calls `advanceStepLogic` as the booking's assigned caregiver |
| `adminSeed` | `{ scope: 'all'\|'aisyah'\|'hafiz'\|'groupsToday'\|'s3Visit' }` | See §4 |
| `adminNotify` | `{ uid, title, body, link? }` | `notify(db, uid, { type: 'admin', … })` |

`seedDemo` keeps working as before (emulator, or the admin claim).

### Granting the claim
`functions/scripts/grant-admin.js <email>`: uses `firebase-admin` with application default credentials (`gcloud auth application-default login`), creates the user if missing (password from a prompt or argument, never committed), and sets `{ admin: true }`. The README documents this. No service-account key goes into the repo.

## 4. Demo data

`seed.ts` changes:
- **Accounts:** add `hafiz@careway.demo` (role guardian), with his own family and one patient: himself, relationship **Myself**, independent mobility, and himself as main contact. Aisyah's family gains **Adam** (9, Child).
- **Groups for today:** for each pickup point, add an open group today if its pickup time is still at least 30 minutes ahead. Pickup times are the existing slots shifted to the next half hour from now, so there's always something bookable during a demo. Same-day groups get `lockAt: null` (§5).
- **Reset** (`scope: 'all'`, `'aisyah'`, `'hafiz'`): deletes, for the given demo families, their `bookings`, `deliveries`, related `offers`, `receipts`, demo `groups` and `users/{uid}/notifications`, then re-runs the seed for those accounts. It only touches documents tied to `@careway.demo` accounts and demo group ids (prefix `demo-`). Deletes are batched in chunks of up to 400.
- **S3 visit** (`scope: 's3Visit'`): a booking for Zainab, Level 2, `status: 'confirmed'`, paid (a receipt is written), caregiver Ravi with the patient-access document, appointment about 1 hour from now, steps empty. The guardian gets a "Visit confirmed" notification.

Ravi's caregiver profile is checked to make sure he qualifies for a Level 2 job for Zainab (escort skill). If he doesn't, he gets the skill in seed data.

## 5. Booking rules changes

- **App:** `dayBookable` in `lib/features/booking/booking_draft.dart` is true for today and later days. Today only lists times/groups whose pickup is still ahead of now.
- **Server:** the `MIN_LEAD_MS` check in `functions/src/booking/request.ts` becomes "pickup time (or appointment time when there's no pickup) must be after now". Error `too-soon` with the message "That time has already passed."
- **Group lock:** when a group is created (in `request.ts` and the seed) and pickup is less than 24 hours away, `lockAt` is `null`. `lockGroupsLogic` already queries `lockAt <= now`, so null lock times never match: same-day groups lock only through `adminLockGroup`. `booking_common.dart:46` falls back to `apptAt − 24h` when `lockAt` is null, so it's changed to show "Locks before pickup" when `lockAt` is null.
- **Calendar:** in `book_screen.dart`, picking a day no longer closes the calendar. It closes only when the date field is tapped again or the next field is opened.

## 6. Push notifications (Android)

### App
- Add `firebase_messaging` and `flutter_local_notifications`. The Android manifest gets `POST_NOTIFICATIONS`. There's a default notification channel `careway_updates` (high importance) and the small icon is a monochrome version of the logo.
- `lib/data/push.dart` (`PushService`):
  - After sign-in, asks for permission (Android 13+), gets the token and calls `claimPushToken({ token })`. The callable removes the token from every other user and adds it to the caller's `users/{uid}.fcmTokens`. This runs server-side because rules don't let a user write to another user's doc.
  - On sign-out it removes the token from `users/{uid}.fcmTokens` **before** `signOut()`.
  - `onTokenRefresh` swaps the old token for the new one.
  - Foreground messages are shown with `flutter_local_notifications`, so the pop-up appears even while the app is open.
  - Tapping a notification (foreground, background or cold start) opens its `link` with go_router. It doesn't navigate if the link belongs to the other role.
- Web: `PushService` does nothing on web (`kIsWeb`).

### Functions
- `onNotificationCreated = onDocumentCreated('users/{uid}/notifications/{id}')`: reads `fcmTokens` and sends `sendEachForMulticast` with `notification: { title, body }`, `data: { link }`, `android: { priority: 'high', notification: { channelId: 'careway_updates' } }`. Tokens that come back `registration-token-not-registered` or `invalid-argument` are removed.
- `claimPushToken` callable: `{ token }`. Removes the token from every other user that has it, then adds it to the caller.

## 7. Medicine delivery notifications

In `progressDeliveries` / `advanceDeliveryTx`, the stage still advances and is recorded in `steps` at every stage, but `notifyTx` only runs when the new stage is **`collecting`** ("Medicine run: collecting the documents") or **`delivered`**. The live delivery screen keeps showing every stage.

## 8. Home delivery section and deliveries list

### Data
- `DeliveryRepo.watchFamily(familyId)` streams the family's deliveries, newest first. It's exposed as `familyDeliveriesProvider` in `lib/data/providers.dart`. A Firestore index on `deliveries(familyId, createdAt desc)` is added if needed.

### Home (`home_screen.dart`, canvas artboard 2)
A **"Medicine delivery (n)"** section after Upcoming, with **See all** → `/deliveries`. It shows only when the family has at least one delivery. `n` is the number of in-progress deliveries.
- One card per in-progress delivery (status anywhere from `booked` up to but not including `delivered`; draft/unpaid shown as "Pay to confirm"). Each card has a blue medicine icon tile, "{Patient}'s medicine", "{Pharmacy} · to your doorstep", a **Live** chip, a 6-segment progress bar (done segments `#2F64A8`, current `#8FB0DA`, upcoming `#E3ECF8`), a footer with "{stage label} · {helper}" and **Track ›**. Tapping it opens `/delivery/:id/live`.
- With nothing in progress, the section shows the most recent delivered one as a single compact row. With no deliveries at all, the section is hidden.

### Medicine deliveries list (`/deliveries`, new `delivery_list_screen.dart`, canvas artboard 38)
- Back button, title "Medicine deliveries", subtitle "Track and look back at every delivery".
- **In progress**: the same card as on Home. **Delivered**: compact rows ("{EEE d MMM} · {Patient}", "{Pharmacy} · {items}", a green **Delivered** chip) → `/delivery/:id/done`.
- A **New delivery** button pinned at the bottom → `/delivery/new`.
- Empty state: "No deliveries yet" above the New delivery button.

## 9. Cancel confirmation

In `pending_screen.dart`, **Cancel request** opens a `showCwSheet` (or an `AlertDialog` styled with app tokens): title "Cancel this request?", body "We'll stop looking for a caregiver. Nothing has been charged.", buttons **Keep request** (default) and **Yes, cancel** (danger). `cancelBooking` only runs on Yes. The same confirmation is used anywhere else a `pending_caregiver` booking can be cancelled (Visits, Upcoming).

## 10. Logo and app icon

- Add `flutter_launcher_icons` (dev dependency), configured in `pubspec.yaml`: `image_path: assets/images/careway-icon-512-square.png`, Android adaptive icon with background `#6C4EE3` (the icon's purple, sampled from the file) and the same image as foreground, plus web favicon and PWA icons. Generated files are committed.
- Android app label stays "CareWay".
- In-app logo: wherever the app currently draws a placeholder brand mark (welcome, sign in, get started), use `Image.asset('assets/images/careway-icon-512-square.png')` with rounded corners. The caregiver sign-in uses `careway-caregiver-icon-512.png`. `assets/images/` is already declared in `pubspec.yaml`.

## 11. Security rules

- `isAdmin()` = `request.auth.token.admin == true`.
- Admins get read on `bookings`, `deliveries`, `offers`, `groups`, `users`, and `families/**` (for the panels). Admins get no direct writes: every change goes through the callables.
- Users may update their own `fcmTokens` field (array of strings, at most 10 entries).

## 12. Error handling

- Admin callables return `HttpsError` with a clear message (`failed-precondition: No open offer for this booking`). The admin page shows it in a snackbar and re-enables the button.
- Each admin action runs in a transaction that re-reads current status, so double-clicks and races with the scheduled jobs are safe (the second call fails with `failed-precondition`).
- A push send failure is logged and never fails the notification write.

## 13. Testing

- **Functions (emulator, `test:emu`):**
  - every admin callable rejects callers without the claim
  - accept/reject on behalf of a caregiver produces the same documents as `respondToOffer`
  - force-not-found ends as `not_matched` with a guardian notification
  - lock-group settles and refunds
  - advance-delivery only notifies at `collecting` and `delivered`
  - reset only deletes demo-scoped documents
  - a same-day booking is accepted and its group has `lockAt: null`, and a past pickup is rejected
  - `claimPushToken` moves a token between users
  - `onNotificationCreated` prunes invalid tokens (with the messaging client stubbed)
- **Rules tests:** admin read allowed and admin write denied, non-admin read of other families denied, `fcmTokens` self-update allowed.
- **Flutter widget tests:**
  - cancel dialog (Keep doesn't call the API, Yes does)
  - Home delivery section (hidden / in-progress card / delivered row)
  - deliveries list grouping
  - `dayBookable` today true
  - the calendar stays open after selection
  - admin route guard redirects non-admins
- **Manual on deployed:** install the APK, sign in as Aisyah, press Accept in admin, and see a push within a few seconds. Then switch to Ravi on the same phone and confirm Aisyah's pushes stop and Ravi's arrive.
