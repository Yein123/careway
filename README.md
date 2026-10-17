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

On the sign-in screen (debug builds) tap **Load demo data**, then sign in:

| Role | Email | Password |
|---|---|---|
| Guardian | aisyah@careway.demo | careway123 |
| Group helper | farid@careway.demo, ravi@careway.demo | careway123 |
| Escort | nurul@careway.demo, meiling@careway.demo | careway123 |

Note: the Functions emulator does not run scheduled jobs (offer expiry, group lock, delivery progress) on its own.

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
