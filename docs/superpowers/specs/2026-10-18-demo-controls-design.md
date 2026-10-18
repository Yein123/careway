# CareWay Demo Controls — Design Spec

Date: 2026-10-18
Builds on: `2026-10-17-careway-app-design.md`
Source design: Claude Design canvas "CareWay App" (https://claude.ai/artifact/Ma9WUEARAsaM2fWnyYkkCt), artboards 2 · Home and 38 · Medicine deliveries (list).

## 1. Purpose

A presenter demos the app live on the **deployed** Firebase project (`careway-tehwoq`) with **one Android phone**. A laptop shows an admin web page that triggers each outcome on cue, so nothing waits on timers or on a second person. Every change reaches the phone within a couple of seconds as a real push notification.

### Demo scenarios and accounts
All passwords are `careway123`.

| # | Scenario | Account | Who | Patient |
|---|---|---|---|---|
| 1a | Guardian books for their child | `parent@gmail.com` | Siti (parent) | Adam, 9, Child |
| 1b | Guardian books for their parent | `child@gmail.com` | Aisyah (adult child) | Zainab, 72, Parent |
| 2 | Individual books for themselves | `self@gmail.com` | Hafiz, 58 | Himself, Myself |
| 3 | Caregiver updates a visit | `caregiver@gmail.com` | Ravi S. | A ready visit for Zainab today |

The existing `farid@`, `nurul@` and `meiling@careway.demo` caregivers stay, so **Reject** has someone to cascade to. The old `aisyah@` and `ravi@careway.demo` accounts are replaced by the table above.

### Decided by the user
- An `/admin` web page with controls for: reseed demo data for today, accept/reject on behalf of the caregiver, not found, group set (lock), delivery progress, caregiver visit steps.
- Real push (FCM), Android only. One phone, so accounts are switched on the device.
- Scenario 3 uses a pre-made visit.
- Home medicine delivery section plus a Medicine deliveries list (canvas 2 and 38).
- Logo `assets/images/careway-icon-512-square.png` becomes the app icon and in-app logo.
- Confirm before cancelling a pending booking.
- Medicine pushes only at *collecting the documents* and *delivered*.
- Today is bookable while its pickup time is still ahead. Same-day groups lock only from admin.
- The calendar stays open after a date is picked.

### Out of scope
Custom push from admin, web push, iOS, a real operations console.

## 2. Admin page (`/admin`)

- Route outside the guardian/caregiver shells. Requires the `admin` claim; anyone else sees "Not authorised". An admin who signs in is sent to `/admin`.
- Laid out for a laptop. It stacks into one column on narrow screens.

Contents, top to bottom:
1. **Reset demo for today**, one button: wipes the demo data and reseeds everything (§4).
2. **Live requests**: every non-terminal booking and delivery of the four demo accounts, newest first. Each row shows account, patient, type (Group / Escort / Medicine), a status chip ("Waiting for caregiver", "Pay to confirm", "Confirmed", stage…) and the buttons that make sense for its status:
   - booking or delivery with an open offer → **Accept**, **Reject**, **Not found**
   - Level 1 booking confirmed in an unlocked group → **Group set** (lock now)
   - paid delivery → **Next stage**, **Run to delivered**
3. **Caregiver visit (scenario 3)**: the visit's current step, with **Advance step** as a backup if the caregiver phone isn't used.

Buttons show a spinner while a call runs. Errors appear in a snackbar.

## 3. Admin callables (`functions/src/admin/`)

Each one calls `requireAdmin(req.auth)` (`permission-denied` unless `token.admin === true`) and reuses the existing logic, so notifications, receipts and refunds behave the same as in real use.

| Callable | Input | Does |
|---|---|---|
| `adminReset` | `{}` | §4 |
| `adminRespondOffer` | `{ col, id, accept }` | Calls `respondToOfferLogic` as the caregiver holding the open offer. A reject cascades as normal |
| `adminNotFound` | `{ col, id }` | Expires the open offer and ends the request as `not_matched` (same path as an exhausted cascade) |
| `adminLockGroup` | `{ groupId }` | Lock and settle one group now. The per-group transaction is extracted from `lockGroupsLogic` and shared with it |
| `adminAdvanceDelivery` | `{ id, toEnd }` | One stage (or all remaining), using the transition extracted from `progressDeliveriesLogic`. No 1-minute wait |
| `adminAdvanceStep` | `{ bookingId }` | Calls `advanceStepLogic` as the assigned caregiver |

`functions/scripts/grant-admin.js <email> <password>` creates the admin user if needed and sets `{ admin: true }`, using application default credentials (`gcloud auth application-default login`). No keys are committed.

## 4. Demo data (`seed.ts`)

**Reset demo for today** does this:
1. Deletes the data belonging to the four demo accounts: their bookings, deliveries, the offers on those, receipts, notifications, and demo groups (id prefix `demo-`). It doesn't touch anything else.
2. Creates or updates the accounts and families in the §1 table. The caregiver gets the skills needed for both group and escort jobs.
3. Creates open Level 1 groups **for today**, with pickups at the next half hours that are still at least 30 minutes away, plus the following days as before. Same-day groups have `lockAt: null`.
4. Creates the scenario 3 visit: Zainab (child@gmail.com's family), Level 2, confirmed and paid, caregiver@gmail.com assigned, appointment about 1 hour from now, no steps yet.

Note: Firebase Auth sends no email to these addresses (no verification or reset flows are used), so the `@gmail.com` names are just logins.

## 5. Booking today

- App: `dayBookable` (`booking_draft.dart`) allows today. Today only shows times and groups whose pickup is still ahead.
- Server: the 24-hour `MIN_LEAD_MS` check in `request.ts` becomes "pickup (or appointment) must be in the future". Error `too-soon`: "That time has already passed."
- Groups whose pickup is less than 24h away get `lockAt: null`, so the scheduled lock job never picks them up. They lock only through **Group set**. `booking_common.dart` handles a null `lockAt`.
- Calendar (`book_screen.dart`): picking a day no longer closes it.

## 6. Push (Android)

- App: `firebase_messaging` + `flutter_local_notifications`, `POST_NOTIFICATIONS` permission, channel `careway_updates`. Web does nothing.
  - After sign-in the app asks for permission and calls `claimPushToken({ token })`. The server moves the token from any other user to the caller.
  - On sign-out the token is removed from the user before signing out.
  - Foreground messages are shown as a local notification. Tapping any notification opens its `link`.
- Functions: `onDocumentCreated('users/{uid}/notifications/{id}')` sends to that user's `fcmTokens` and prunes invalid tokens. A send failure only logs.

## 7. Medicine notifications

Stages still advance and show on the live screen. A notification (and therefore a push) is written only on entering **`collecting`** and **`delivered`**.

## 8. Home delivery section and list

- `familyDeliveriesProvider` streams the family's deliveries, newest first (index on `deliveries(familyId, createdAt desc)` if needed).
- **Home**, after Upcoming: a "Medicine delivery (n)" section with **See all** → `/deliveries`. It shows a card for each in-progress delivery, as in canvas 2: blue icon, "{Patient}'s medicine", "{Pharmacy} · to your doorstep", a Live chip, a 6-segment progress bar, "{stage} · {helper}" and **Track ›** → `/delivery/:id/live`. If nothing is in progress it shows the latest delivered one as a row. If there are no deliveries at all, the section is hidden.
- **`/deliveries`** (canvas 38): "In progress" cards, then "Delivered" rows (→ `/delivery/:id/done`), with a **New delivery** button at the bottom.

## 9. Cancel confirmation

**Cancel request** on a pending booking asks "Cancel this request?", with the body "We'll stop looking for a caregiver. Nothing has been charged." and the buttons **Keep request** / **Yes, cancel**. It only cancels on Yes.

## 10. Logo and icon

- `flutter_launcher_icons`: Android launcher icon (adaptive, background `#6C4EE3`), web favicon and PWA icons, all from `careway-icon-512-square.png`.
- In-app logo: the welcome, sign-in and get-started screens use the same image. The caregiver sign-in uses `careway-caregiver-icon-512.png`.

## 11. Rules

`isAdmin()` gets read access to bookings, deliveries, offers, groups, users and families, for the admin page. Admins have no direct writes; all changes go through callables. `fcmTokens` is written only by `claimPushToken` and the sign-out removal (self only).

## 12. Testing

- Functions (emulator):
  - admin callables reject non-admins
  - accept/reject on behalf of the caregiver gives the same result as `respondToOffer`
  - not found leads to `not_matched` plus a notification
  - group set settles
  - delivery notifies only at `collecting` and `delivered`
  - reset only touches demo data
  - same-day booking accepted, past pickup rejected, `lockAt` null
  - `claimPushToken` moves the token
- Rules: admin read allowed and admin write denied.
- Widgets:
  - cancel dialog
  - Home delivery section states
  - deliveries list
  - today bookable
  - calendar stays open
  - admin guard
- Manual, on deployed:
  - install the APK, sign in as `child@gmail.com`, press **Accept** on admin, and check a push arrives
  - switch to `caregiver@gmail.com` and check the pushes follow the new account
