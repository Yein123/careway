# CareWay App — Design Spec

Date: 2026-10-17
Source design: Claude Design canvas "CareWay App" (https://claude.ai/artifact/Ma9WUEARAsaM2fWnyYkkCt), 46 artboards.

## 1. Purpose

CareWay helps families in Sime Darby Property townships (Elmina, Denai Alam, Shah Alam) get elderly or dependent relatives to and through medical visits, and get repeat medicine delivered. Success for this build: a working Flutter app (Android + Web) on Firebase where a guardian can book a visit end to end, a qualified caregiver receives, accepts and runs it, and the guardian follows it live and rates it.

### Decided by the user
- One Flutter app, two roles: **Guardian** and **Caregiver**, role chosen by account.
- Platforms: **Android + Web**. New Firebase project. **Blaze plan enabled**; Cloud Functions are used.
- Auth: **email + password** (phone kept as profile data).
- Caregivers are **matched by skill and certificate** and must **accept** each patient (group or personal) → caregiver pending status.
- Level 1 group pricing: **pay at confirm at current group-size price, settle (refund the difference) once when the group locks 24h before pickup.**
- Medicine delivery fee and the Level 2 private ride: priced by a **fee model** (linear regression on route km, peak and night km) trained on Malaysian market prices; see `functions/src/models/fee_model.json` and README § Smart matching and pricing.

### Assumptions
- Payments (FPX, Touch 'n Go, DuitNow QR, card) are **simulated**: choosing a method and tapping Pay marks the payment `paid` after a short delay. Refunds are recorded, not executed.
- Notifications are **in-app** (Firestore). No push (FCM) in this build.
- Distances use **coordinates of known places** (seeded hospitals, pharmacies, pickup points, saved home places) and haversine × 1.3 road factor. No Maps API.
- Caregiver certificate verification is done by an admin flag set in seed data / Firestore console; there is no admin UI in this build.
- Copy labelled "AI fee estimate" in the design is shown as designed: the fee comes from the trained fee model.
- Prices are sample values in a single config file.

### Out of scope
Real payment gateway, push notifications, admin console, MySejahtera link (shown "Coming soon" as in design), iOS build, Maps/AI integration.

## 2. Architecture

```
careway/
  lib/
    main.dart, app.dart
    core/        theme (design tokens), router (go_router), widgets (CwButton, CwCard, StepHeader, TabBar, StatusChip, Seats…), utils (money, dates)
    config/      pricing.dart (all sample prices), places.dart
    data/
      models/    AppUser, Family, Patient, CaregiverProfile, Certificate, Booking, Offer, Group, Delivery, AppNotification, Payment
      repos/     AuthRepo, UserRepo, FamilyRepo, BookingRepo, GroupRepo, OfferRepo, DeliveryRepo, NotificationRepo (abstract + Firestore impl)
    domain/      pricing (group share, settlement, escort estimate, delivery fee), needs (patient → required skills/certs), booking state machine
    features/    onboarding, auth, home, booking, visits, family, delivery, notifications, account, caregiver/{home,job,visit,summary,schedule,patients,account}
  functions/     TypeScript Cloud Functions
  firestore.rules, firestore.indexes.json, firebase.json
  test/          unit (domain) + widget tests with fake repos
```

- **State:** Riverpod (providers wrap repo streams). **Routing:** go_router with a redirect on auth state + role (guardian → guardian shell with Home/Visits/Family/Account tabs; caregiver → caregiver shell with Today/Schedule/Patients/Account).
- **Server-authoritative logic in Cloud Functions** (anything involving another user's data, money, or time): matching and offers, offer expiry, group join/seat hold, group lock and settlement, payment confirmation, demo delivery progression. The client calls callable functions; it never writes another user's documents directly.
- **Shared pure logic** (pricing, needs) lives in Dart `domain/` for display and in `functions/src/domain/` for authority, with the same unit-tested rules and numbers.

## 3. Data model (Firestore)

| Path | Key fields |
|---|---|
| `users/{uid}` | name, phone, email, area, role `guardian\|caregiver`, familyId?, settings {language, textScale, notif {visitUpdates, reminders, promos}}, savedPlaces[{label,address,lat,lng}], paymentMethods[{type,label}] |
| `caregivers/{uid}` | displayName, agency, zone, onDuty, rating, ratingCount, languages[], skills[] (`wheelchair`, `transfer`, `consultSitIn`, `paediatric`, `dementia`, `medicineCollection`), certificates[{type,verified,expiresAt}] (`firstAid`, `patientHandling`, `trainedEscort`, `paediatric`), home {lat,lng} |
| `families/{fid}` | name, adminUid, memberUids[] |
| `families/{fid}/patients/{pid}` | name, age, relationship, phone, mobility `independent\|stick\|wheelchair\|transfer`, extraHelp[], conditions, surgery, allergy, medicines, clinics, talkNotes, contacts[], privacy {helperOnly, updatesTo}, updatedAt, updatedBy |
| `groups/{gid}` | hospitalId, clinic, date, pickupPointId, pickupTime, apptWindow, caregiverId, riderBookingIds[], heldSeats[{bookingId, until}], capacity 3, status `open\|full\|locked\|completed\|cancelled`, lockAt |
| `bookings/{bid}` | familyId, guardianUid, patientId, patientSnapshot, level 1\|2, pickup {label,lat,lng}, hospitalId, clinic, apptAt, groupId?, package `saver\|flex`?, addons[], requiredSkills[], requiredCerts[], caregiverId?, status (§4), price {lines[], paid, finalTotal?, refund?}, payment {method, status, paidAt}, steps[{key,at}], summary {…}, rating {stars,tags,text}, waitlist bool, createdAt |
| `offers/{oid}` | bookingId, caregiverId, kind `personal\|groupJoin\|groupNew`, rank, status `offered\|accepted\|declined\|expired\|cancelled`, expiresAt (now + 18 min) |
| `deliveries/{did}` | familyId, patientId, pharmacy {name,lat,lng}, window, deliverTo, docs{}, routeKm, fee {base, distance, total}, caregiverId?, status `pending_caregiver\|booked\|collecting\|at_pharmacy\|on_the_way\|delivered\|not_matched`, steps[], rating |
| `users/{uid}/notifications/{nid}` | type, title, body, link, read, createdAt |
| `receipts/{rid}` | uid, bookingId\|deliveryId, amount, kind `payment\|refund\|credit`, method, createdAt |

Static reference data (hospitals, clinics, pharmacies, pickup points with coordinates) lives in `config/places.dart` and is mirrored in functions.

## 4. Booking status and caregiver matching

### Booking states
```
draft → pending_caregiver → awaiting_payment → confirmed → in_progress → completed
                 ↘ not_matched        ↘ expired (unpaid 30 min)     ↘ cancelled (any pre-start state)
```
Payment happens **only after a caregiver accepts**, so a failed request is never charged.

### Needs derivation (`domain/needs`)
| Booking fact | Requirement |
|---|---|
| Level 2 | cert `trainedEscort` |
| mobility `transfer` | skill `transfer` + cert `patientHandling` |
| mobility `wheelchair` or add-on "Wheelchair on arrival" | skill `wheelchair` |
| patient age < 18 (always Level 2) | skill `paediatric` + cert `paediatric` |
| add-on "Consult sit-in" | skill `consultSitIn` |
| add-on "Medicine collection" / delivery | skill `medicineCollection` |
| add-on "Language help (X)" | languages contains X |
| always | cert `firstAid` |

Level 1 package and add-ons are chosen after the group helper accepts (design order), so Level 1 matching uses level, mobility and age only; the package screen offers only the add-ons (and languages) the accepted helper can do, and payment re-validates this. Level 1 never includes lifting/toilet help (design copy); a Level 1 booking with mobility `transfer` is blocked in Choose help and Level 2 is suggested.

### Matching (`functions: matchCaregivers`)
1. **Hard filter:** all required skills; all required certs `verified` and `expiresAt` after the appointment; `onDuty`; zone matches; no schedule overlap with accepted bookings or open offers (appointment ±3h window for Level 2, group trip window for Level 1).
2. **Score** (higher first): language match +3, served this patient before +2, rating ×1, distance to pickup −0.2/km, accepted jobs that day −0.5 each. **Personalisation:** repeat visits with the patient +0.5 each after the first (max +1), the family's average rating of the caregiver +1 per star above 3, optional skills suiting the patient (dementia, consult sit-in, wheelchair) +1.5 each, past jobs at the place +0.25 each (max +1). Caregivers the family rated ≤ 2 stars are excluded.
3. **Sequential offers:** offer to rank 1 with an 18-minute expiry. Decline or expiry → next candidate. List exhausted → booking `not_matched`, guardian notified, nothing charged.
4. `expireOffers` scheduled function runs every minute.

### Caregiver side
- Today screen shows **NEW JOB REQUEST** cards for `offered` offers with countdown, patient summary, needs, estimated earnings; Accept / Decline.
- Accept (callable, transaction): offer → `accepted`; booking → `awaiting_payment`, `caregiverId` set; guardian notified "Farid accepted — pay to confirm". Other open offers for the same booking cancelled.
- On-duty toggle controls eligibility.

### Groups (Level 1)
- **Start a new group:** creates the group and the booking; matching runs as above (`groupNew`); the accepting caregiver becomes the group helper.
- **Request to join:** a callable transaction places a **seat hold** (until offer expiry) if `riders + holds < 3` and the group is `open`; creates a `groupJoin` offer to the **group's helper only**, who must still qualify for this patient. Accept → `awaiting_payment`. Decline / expiry / no seat → booking `not_matched` with reason, which shows **Group not found**.
- **Full group:** "Join the waitlist" sets `waitlist: true`; if a seat frees, the guardian is notified to confirm, then the join flow runs.

## 5. Pricing

All numbers in `config/pricing.dart` (and mirrored in functions). Sample values:

| Riders in group | Group Saver / rider | Group Flex / rider |
|---|---|---|
| 1 | RM 40 (cap) | RM 55 |
| 2 | RM 30 | RM 45 |
| 3 | RM 22 | RM 35 |

Add-ons (per patient, never shared): Language help RM 8, Consult sit-in RM 10, Medicine collection RM 5, Visit summary RM 5, Wheelchair on arrival RM 5.

Level 2: escort RM 30/hour × estimated hours (default 4) + private ride both ways RM 24. Charged by actual time in 30-minute steps; a shorter visit is refunded at completion (recorded as a refund receipt).

### Group payment and settlement
- At pay time a rider pays `share(package, ridersIncludingMe) + addons`.
- **Lock** at `lockAt = pickup − 24h` (`lockGroups` scheduled every 5 min): group → `locked`; final share = `share(package, finalRiders)`; each rider's refund = paid share − final share (≥ 0), recorded as a refund receipt and notification. Nobody's price ever goes up.
- Cancel **before lock**: rider leaves; Saver → full refund; Flex → full refund (both are inside the free 24h window). The remaining riders' final price is computed at lock from the remaining count but **capped at what each already paid**.
- Cancel **after lock**: Saver → CareWay credit; Flex → 50% refund. The others' prices are unchanged.
- Worked example: A pays 40, B pays 30, C pays 22 → at lock A refunded 18, B refunded 8 → all paid 22, total 66.

### No group found (all options charge nothing)
Form a new group (rider 1, RM 40 cap, rides even if alone) · Switch to Level 2 escort · Tell me if a seat opens (waitlist) · Decide later (booking stays `draft`). If a new group also gets no caregiver, show "No caregiver available" with Level 2 suggested.

### Medicine delivery fee (formula)
`routeKm = 2 × haversine(home, pharmacy) × 1.3`, rounded to 0.1 km; the fee is the trained fee model's estimate for that km at the window's start hour (minimum RM 15). The Level 2 private ride uses the same model on the two one-way legs (an hour before the appointment, three hours after), stored on the booking as `rideSen`. Delivery requires all 3 documents ticked (appointment card, IC copy, authorisation letter) and goes through caregiver matching (skill `medicineCollection`) before payment, like a booking.

## 6. Screens (design artboard → Flutter route)

**Guardian** — 0a GetStarted `/start`, 0b SignIn `/signin`, 1 Welcome `/`, 2 Home `/home`, 3 Book `/book`, 4 Choose help `/book/help`, 5 Group list `/book/groups`, 6 Pending `/booking/:id/pending`, 7 Group found + package `/booking/:id/package`, 8 Not found `/booking/:id/not-found`, 9 Confirmed `/booking/:id/confirmed`, 10/19 Visit day (group/personal) `/booking/:id/live`, 11 Patient profile `/family/patient/:pid`, 13 Account `/account`, 14 Review escort `/book/escort`, 15/24 Payment `/booking/:id/pay`, 16 Escort booked → confirmed, 17 My visits `/visits` (incl. rating + feedback sheets), 18 Family `/family`, 21 Upcoming `/booking/:id`, 22 Notifications `/notifications`, 23 Book from service tile (prefilled `/book`), 25–30 Account sub-pages `/account/{payments,receipts,places,notifications,language,privacy}`, 31–37 Medicine delivery `/delivery/new`, `/delivery/:id/{booked,live,done,rate,feedback,thanks}`.

The guardian Pending screen gets a status line per state: "Finding a qualified caregiver", "Waiting for Farid to accept (expires 9:42)", "Accepted — pay to confirm". The prototype "see the result" buttons are removed; the screen reacts to the live booking status.

**Caregiver** — C1 login (shared sign-in, role-routed), C2 Today `/cg`, C3 Job details `/cg/job/:id`, C4 Update visit steps `/cg/job/:id/steps`, C5 Write summary `/cg/job/:id/summary`, C6 Schedule `/cg/schedule`, C7 Patients `/cg/patients`, C8 Account `/cg/account` (shows skills, certificates with verified/expiry badges, on-duty).

**Visual system** (from the design): Plus Jakarta Sans (google_fonts); primary #6C4EE3, primary dark #4B32B8, ink #1E1B2E, muted #625E78, surface #F7F6FB, line #E7E4F0, lilac #F1EDFD; teal #127A94 (Level 2), pink #C2365E (safety/errors), delivery blue #2F64A8; radii 14–16; buttons 56–58 px high; touch targets ≥ 44 px; phone layout, centred max-width 480 on web. Text size setting (Account → Language) scales text app-wide.

### Visit steps (caregiver → guardian live)
Group: Picked up → Arrived & registered → With the doctor → Pharmacy → Ride home → Home. Personal: same plus "Waiting for the doctor". Each tap (callable `advanceStep`) appends `{key, at}`, sets `in_progress` on the first step and `completed` on the last (requires the summary when the "Visit summary" add-on or Level 2), and notifies the guardian.

## 7. Cloud Functions (TypeScript, region asia-southeast1)

| Function | Type | Job |
|---|---|---|
| `requestBooking` | callable | validate, derive needs, create/hold group seat, start matching |
| `respondToOffer` | callable | accept/decline (transaction), advance cascade |
| `expireOffers` | scheduled 1 min | expire offers, cascade, release seat holds, expire unpaid bookings |
| `payBooking` / `payDelivery` | callable | simulated payment, write receipt, confirm, add rider to group |
| `cancelBooking` | callable | apply cancellation/refund rules, free seat, notify waitlist |
| `lockGroups` | scheduled 5 min | lock and settle groups (refunds) |
| `advanceStep`, `submitSummary` | callable | caregiver visit progress + guardian notifications |
| `progressDeliveries` | scheduled 1 min | demo: moves `booked` deliveries through stages ~1 per minute |
| `seedDemo` | callable (dev only, emulator or admin flag) | hospitals, 3 caregivers with varied skills/certs, open groups for next 7 days, demo family |

## 8. Security rules (summary)
- Users read/write their own `users/{uid}` (role field not changeable by client).
- Family docs/patients: members read/write; an assigned caregiver can read a patient only while they have an accepted, not-completed booking for that patient.
- Bookings/deliveries: readable by the family members and the assigned caregiver; **all writes via functions** except guardian rating/feedback fields on completed bookings.
- Offers: readable by the target caregiver; writes via functions.
- Groups: readable by signed-in users (limited fields: no patient data inside groups); writes via functions.
- Notifications/receipts: owner read; writes via functions (notification `read` flag writable by owner).

## 9. Errors and edge cases
- Every data screen has loading, empty and error states; failed actions show a snackbar with Retry.
- Callable errors map to friendly copy (e.g. `seat-taken` → Group not found screen; `offer-expired` → "This request expired").
- Booking < 24h before appointment is blocked in the date picker (design rule).
- Race: two riders requesting the last seat → transaction gives it to one; the other gets `seat-taken`.
- Caregiver goes off duty with open offers → offers declined automatically, cascade continues.
- Unpaid `awaiting_payment` for 30 minutes → `expired`, seat released, caregiver notified.

## 10. Testing and verification
- Dart unit tests: pricing (shares, settlement worked example, cancel rules, escort, delivery fee), needs derivation, state machine.
- Functions unit tests (Jest) for matching filter/score, cascade, settlement — run against the Firebase emulator.
- Widget tests: booking flow screens and caregiver offer card with fake repos.
- `flutter analyze` clean; app launched on Chrome against the emulator suite; end-to-end demo: guardian books Level 1 join → caregiver accepts → guardian pays → caregiver steps → guardian sees live → summary → rating.
- Deploy: `firebase deploy` (rules, indexes, functions) to the Blaze project; Android debug build compiles.
