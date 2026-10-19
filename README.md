# CareWay

Flutter (Android + Web) app on Firebase that helps families get relatives to and through medical visits. Guardians book a shared ride (Level 1) or a one-to-one escort (Level 2), qualified caregivers accept the job, and the family follows the visit live. Also: medicine delivery with a distance-based fee.

- Design spec: `docs/superpowers/specs/2026-10-17-careway-app-design.md`
- Implementation plan: `docs/superpowers/plans/2026-10-17-careway-app.md`

## Layout

| Path | What |
|---|---|
| `lib/` | Flutter app (Riverpod + go_router). `domain/` pricing and needs rules, `data/` models and Firestore repositories, `features/` screens |
| `functions/` | Cloud Functions (TypeScript): matching, offers, payment, cancellation, group lock/settlement, visit steps, deliveries, demo seed |
| `firestore.rules`, `firestore.indexes.json` | Security rules and indexes |
| `tool/dev-env.sh` | Puts JDK 21 and Node 22 on PATH for the emulators |

## One-time setup

Firebase client config is **not committed** (it contains API keys). Generate it locally:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=careway-tehwoq --platforms=android,web
```

This writes `lib/firebase_options.dart` and `android/app/google-services.json` (both gitignored).

Requirements: Flutter 3.38+, Firebase CLI, JDK 21+ and Node 22 (see `tool/dev-env.sh` for the paths used on this machine).

```bash
flutter pub get
npm --prefix functions install
```

## Run locally against the emulators

```bash
source tool/dev-env.sh
firebase emulators:start --only auth,firestore,functions   # Firestore on 8085, Auth 9099, Functions 5001
flutter run -d chrome --dart-define=USE_EMULATOR=true       # in another terminal
```

On the sign-in screen (debug builds) tap **Load demo data**, then sign in (password `careway123` for all):

| Role | Email | Who |
|---|---|---|
| Guardian | parent@gmail.com | Siti, books for her child Adam |
| Guardian | user@gmail.com | Aisyah, books for her mother Zainab |
| Guardian (self) | self@gmail.com | Hafiz, books for himself |
| Caregiver | caregiver@gmail.com | Aina |
| Extra caregivers | farid@careway.demo, nurul@careway.demo, meiling@careway.demo | group helpers and escorts |

Note: the Functions emulator does not run scheduled jobs (offer expiry, group lock, delivery progress) on its own.

## Admin and live demo

One-time setup for the admin account (application default login only, no key file):

```bash
gcloud auth application-default login
node functions/scripts/grant-admin.js admin@careway.demo <password>
```

Open https://careway-tehwoq.web.app/admin and sign in with that account; admins always land on `/admin`. Signing in as `admin@gmail.com` (any sign-up with that email) is also treated as admin, with no script needed. To redeploy the web app: `flutter build web --release && firebase deploy --only hosting --project careway-tehwoq`. Press **Reset demo for today** before each run to re-seed today's groups and the scenario 3 visit.

Run sheet:

1. **S1, guardian (user@gmail.com, phone):** book today's group. On the admin page press **Accept**, **Reject**, **Not found** or **Group set**; each result arrives as a push on the phone. For a medicine delivery, press **Next stage**: pushes arrive at collecting and delivered only.
2. **S2, self booking (self@gmail.com):** same flow as S1.
3. **S3, caregiver:** sign in as caregiver@gmail.com on the phone, open today's visit and tap through the steps, while the guardian view runs in a laptop browser as user@gmail.com. On the admin page, **Advance step** stops before the last Level 2 step: the visit summary must be written on the caregiver phone first, then finish the visit there.

Run the today-booking demo (S1 and S2) while appointment slots remain: today's list only offers times still ahead, and Level 1 needs the pickup an hour earlier to be ahead too, so book before about 3:30 PM MYT. After that, today is greyed out in the calendar; pick a later day or press **Reset demo for today** the next morning.

Push notifications are Android only. The push trigger (`onNotificationCreated`) runs in `us-central1` because the Firestore database is `nam5`; all callables stay in `asia-southeast1`.

## Tests

```bash
flutter analyze && flutter test                  # app: unit + widget tests
source tool/dev-env.sh
npm --prefix functions test                      # functions: pure rules
npm --prefix functions run test:emu              # functions + security rules against the emulator
firebase emulators:exec --only auth,firestore,functions "node functions/scripts/e2e-emulator.js"   # end-to-end via real callables
```

## Deploy

Needs the Blaze plan on `careway-tehwoq` and Email/Password sign-in enabled in the Firebase console.

```bash
source tool/dev-env.sh
firebase deploy --only firestore:rules,firestore:indexes,functions --project careway-tehwoq
flutter build web            # or: flutter build apk
```

Payments are simulated; no money moves.
