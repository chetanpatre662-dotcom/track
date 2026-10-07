# ARCHITECTURE

FitTrack AI is one product composed of a Flutter Android client, a Node.js/TypeScript backend, and Firebase as the data platform.

```
┌─────────────────────────┐        HTTPS (Firebase ID token)        ┌──────────────────────────┐
│      Flutter (Android)   │ ─────────────────────────────────────▶ │   Node.js / Express API   │
│  Riverpod · go_router    │                                         │  TypeScript · Zod · pino  │
│  Material 3              │ ◀───────────────────────────────────── │  Firebase Admin · Gemini  │
└───────────┬─────────────┘             JSON envelope                └────────────┬─────────────┘
            │                                                                      │
            │ Firebase SDKs (Auth, Firestore, Storage, FCM)                        │ Admin SDK
            ▼                                                                      ▼
        ┌───────────────────────────── Firebase ─────────────────────────────────────┐
        │  Authentication · Cloud Firestore · Storage · Cloud Messaging               │
        └─────────────────────────────────────────────────────────────────────────────┘
```

## Why a backend in front of Firebase?

The Flutter app talks to Firestore/Auth/Storage/FCM directly for ordinary CRUD (fast, offline-capable, secured by rules). The backend exists for operations that must not run on the client:

- **AI (Gemini):** the API key must never ship in the app. All AI calls go through the backend, which builds a compact context, calls Gemini, validates the structured JSON response, and validates recommended exercise IDs against Firestore.
- **Privileged/aggregate operations:** account deletion (Auth + data + storage cleanup), server-authored data, and anything requiring the Admin SDK.
- **Token verification:** the backend verifies the Firebase ID token and derives the UID from it; client-supplied UIDs are never trusted.

## Frontend layering (clean architecture)

```
lib/
  core/            config, theme, routing, error, utils, providers (cross-cutting)
  models/          immutable domain models + JSON (de)serialization
  services/        low-level integrations (Firebase, Dio API client, platform channels)
  repositories/    orchestrate services, return Result<T>, translate errors → Failure
  providers/       Riverpod providers exposing repositories/state to the UI
  features/        one folder per feature (auth, onboarding, home, workout, exercise,
                   nutrition, water, routine, ai, progress, profile, alarm, games)
  widgets/         shared reusable widgets (state views, cards, inputs)
  main.dart
```

Rules of the layering:

- UI never imports Firebase/Dio directly; it goes through providers → repositories → services.
- Repositories return `Result<T>` (`Success` / `Err(Failure)`); exceptions never reach the UI.
- Models are immutable, null-safe, and own their serialization.

## State management

Riverpod is the single state solution. Repositories are exposed as providers; screen state uses `AsyncNotifier`/`Notifier` or `StateNotifier`. No mixing with other state systems.

## Backend layering

```
src/
  config/        env validation (Zod), Firebase Admin init
  middleware/    auth (ID-token verification), error handler, validation, rate limits
  routes/        thin Express routers per resource
  controllers/   request/response handling, call services
  services/      business logic (workouts, nutrition, ai, notifications, ...)
  repositories/  Firestore data access
  validators/    Zod schemas per endpoint
  models/        shared TypeScript types
  ai/            Gemini client, prompt builders, response validators
  notifications/ FCM send helpers
  utils/         logger, errors, http helpers
  app.ts         Express app assembly
  server.ts      bootstrap + graceful shutdown
```

Every response uses a consistent envelope: `{ success: true, data }` or `{ success: false, error: { code, message, details? } }`.

## Alarm architecture (native)

The wake-up alarm requires exact, boot-persistent scheduling and a full-screen UI even when the app is killed — beyond what Dart timers can do. It is implemented in Kotlin:

- `AlarmManager.setAlarmClock` for exact, user-visible alarms.
- A full-screen-intent notification + full-screen `Activity` for the ringing UI.
- `BroadcastReceiver`s for fire/dismiss and a `BootReceiver` to reschedule after reboot.
- A persisted state machine (`SCHEDULED → RINGING → MANUALLY_DISMISSED → CHALLENGE_ACTIVE → GAME_STARTED → GAME_COMPLETED → COMPLETED`, with `TIMEOUT → RERINGING` and `SNOOZED`).
- A `MethodChannel`/`EventChannel` bridge to Flutter for scheduling, state changes, and game-completion callbacks.

The morning **games** are real, playable Flutter implementations; the alarm occurrence is only completed when a game reports genuine completion. There is no "skip game" affordance while the challenge is enabled (the whole feature can be disabled in settings).

## Date/time

Timestamps are stored in UTC. Routine/alarm times are interpreted in the user's local timezone (`timezone` + `flutter_timezone`). Per-day documents key on a local `dateKey` (`yyyy-MM-dd`).
