# SETUP

This guide gets FitTrack AI running locally and prepares it for release. You need your own **Firebase project** and **Gemini API key**; everything else is implemented.

## 0. Prerequisites

Already verified on the target machine:

- Flutter 3.41.2 / Dart 3.11.0
- Node.js 20+ (24.14 tested) / npm 11
- JDK 17 (Temurin)
- Git

Additionally required for building the release APK:

- Android SDK + platform-tools + a build-tools version, with licenses accepted (`flutter doctor --android-licenses`).
- Firebase CLI (`npm i -g firebase-tools`) and FlutterFire CLI (`dart pub global activate flutterfire_cli`).

Run `flutter doctor` and resolve any Android toolchain issues before `flutter build apk`.

## 1. Create the Firebase project

1. Go to the [Firebase console](https://console.firebase.google.com) and create a project.
2. Enable these products:
   - **Authentication** → Sign-in method → enable **Email/Password**.
   - **Cloud Firestore** → create database (production mode; rules are provided).
   - **Storage** → get started (rules are provided).
   - **Cloud Messaging** → no setup needed beyond the project.
3. Add an **Android app** with package name `com.fittrack.fittrack` (matches `frontend/android/app/build.gradle` `applicationId`). Download `google-services.json` and place it at `frontend/android/app/google-services.json`. *(git-ignored)*

## 2. Wire Firebase into Flutter

```bash
cd frontend
dart pub global activate flutterfire_cli   # once
flutterfire configure                      # select your project + Android
```

This generates `frontend/lib/firebase_options.dart` *(git-ignored)*. The app reads it at startup once the Authentication slice is wired.

## 3. Backend service account + environment

1. Firebase console → Project Settings → **Service accounts** → *Generate new private key*. Save the JSON as `backend/serviceAccountKey.json` *(git-ignored)*, **or** copy its `project_id`, `client_email`, `private_key` into the inline env vars below.
2. Configure env:

```bash
cd backend
cp .env.example .env
```

Fill in:

| Variable | Value |
| --- | --- |
| `GOOGLE_APPLICATION_CREDENTIALS` | `./serviceAccountKey.json` (Option A), or leave blank and use the three inline vars |
| `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` | inline credentials (Option B) |
| `FIREBASE_STORAGE_BUCKET` | `your-project-id.appspot.com` |
| `GEMINI_API_KEY` | key from [Google AI Studio](https://aistudio.google.com/app/apikey) |
| `GEMINI_MODEL` | `gemini-2.0-flash` (default) |

## 4. Deploy Firestore & Storage rules and indexes

```bash
cd firebase
firebase use --add            # select your project
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## 5. Seed the exercise & food reference data

```bash
cd backend
npm run seed                  # writes the exercise library to Firestore via Admin SDK
```

## 6. Run locally

```bash
# terminal 1 — backend
cd backend && npm run dev     # http://localhost:8080/health

# terminal 2 — app (emulator or device)
cd frontend && flutter run
```

The Android emulator reaches the backend at `http://10.0.2.2:8080` (already the default `API_BASE_URL`). For a physical device, pass your machine's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

### Optional: Firebase Local Emulator Suite

> **JDK requirement:** the current `firebase-tools` (v15+) Firestore/Storage emulators require **JDK 21 or newer**. The rest of this project builds fine on JDK 17, but the emulator (and the Firestore rules *unit tests* that run against it) need JDK 21. Install a JDK 21+ (e.g. Temurin 21) and ensure it is the active `java` before running the emulator.

```bash
cd firebase && firebase emulators:start
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

To validate/deploy Firestore & Storage rules without the emulator, use:

```bash
cd firebase && firebase deploy --only firestore:rules,storage --project <your-project>
```
Deployment validates rule syntax server-side and requires only that `firebase login` has been run and a project selected.

## 7. Tests

```bash
cd backend && npm test
cd frontend && flutter test
```

## 8. Release build

```bash
cd frontend
flutter build apk --release
# signed release: configure android/key.properties + a keystore (see Android docs)
```

## What must be completed manually by you

1. Create the Firebase project and enable Auth / Firestore / Storage / FCM.
2. Provide `google-services.json` and run `flutterfire configure`.
3. Provide a backend service account (`serviceAccountKey.json` or inline env vars).
4. Provide a `GEMINI_API_KEY`.
5. Deploy rules/indexes and run the seed script.
6. Install/accept the Android SDK to produce a release APK.

Until steps 1–5 are done, the app compiles and boots, backend builds and serves `/health`, but live Firebase/Gemini round-trips return controlled "not configured" errors rather than crashing.
