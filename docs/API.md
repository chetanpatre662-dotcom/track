# API

Base URL: `http://localhost:8080` (dev) · `http://10.0.2.2:8080` from the Android emulator.

## Conventions

- All `/api/*` routes (except where noted) require a Firebase ID token:
  `Authorization: Bearer <idToken>`. The backend verifies it and derives the UID; client-supplied UIDs are ignored.
- Success: `{ "success": true, "data": ... }`
- Error: `{ "success": false, "error": { "code": "STRING_CODE", "message": "...", "details"?: ... } }`
- Error codes: `BAD_REQUEST` (400), `UNAUTHORIZED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `CONFLICT` (409), `VALIDATION_ERROR` (422), `TOO_MANY_REQUESTS` (429), `INTERNAL_ERROR` (500), `SERVICE_UNAVAILABLE`/`NOT_CONFIGURED` (503).
- Rate limits: global `/api` window; stricter window on `/api/ai/*`.

## Health

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/health` | none | Liveness + whether Firebase/Gemini are configured. |

## Auth & profile

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/auth/verify` | Verify ID token; ensure the `users/{uid}` doc exists; return account meta. |
| DELETE | `/api/auth/account` | Delete auth user + owned Firestore/Storage data. |
| GET | `/api/profile` | Get profile. |
| PUT | `/api/profile` | Upsert profile (validated). Recomputes estimated targets unless custom. |

## Exercises

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/exercises` | List with combinable filters: `location, muscle, equipment, difficulty, type`, plus `limit`, `cursor`. |
| GET | `/api/exercises/search?q=` | Keyword search over name/muscle/keywords. |
| GET | `/api/exercises/:id` | Single exercise. |

## Workouts

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/workouts` | List (filter `status`, `isTemplate`, pagination). |
| POST | `/api/workouts` | Create workout/template. |
| GET | `/api/workouts/:id` | Full workout with exercises & sets. |
| PUT | `/api/workouts/:id` | Update (metadata, exercises, sets, status transitions). |
| DELETE | `/api/workouts/:id` | Delete. |
| POST | `/api/workouts/:id/duplicate` | Duplicate as a new workout/template. |

## Nutrition & water

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/nutrition/today?date=` | Day totals + entries grouped by meal. |
| POST | `/api/nutrition/food` | Add a food log entry. |
| PUT | `/api/nutrition/food/:id` | Edit entry (recomputes totals). |
| DELETE | `/api/nutrition/food/:id` | Remove entry. |
| GET | `/api/water/today?date=` | Day total + entries. |
| POST | `/api/water` | Add water entry. |
| DELETE | `/api/water/:id` | Remove entry. |

## Routines & progress

| Method | Path | Description |
| --- | --- | --- |
| GET/POST | `/api/routines` | List / create routine. |
| PUT/DELETE | `/api/routines/:id` | Update / delete. |
| POST | `/api/routines/:id/complete` | Mark completion for a date. |
| GET | `/api/progress` | Aggregate summary for a range (`range=7d|30d|90d|1y|all`). |
| GET | `/api/progress/workouts` | Frequency, duration, volume, muscle frequency. |
| GET | `/api/progress/nutrition` | Calories/macros/water trends. |
| GET | `/api/progress/bodyweight` | Body-weight series. |

## AI (Gemini via backend)

Stricter rate limit. All require auth. Responses are validated structured JSON; recommended exercise IDs are validated against Firestore.

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/ai/chat` | Contextual chat; persists to `aiConversations`. |
| POST | `/api/ai/workout-recommendation` | Structured workout plan (validated exercise IDs). |
| POST | `/api/ai/nutrition-recommendation` | Structured nutrition suggestions. |
| POST | `/api/ai/daily-insight` | Short personalized daily insight. |
| POST | `/api/ai/exercise-substitution` | Alternatives for an exercise given constraints. |
| POST | `/api/ai/generate-workout` | Home/gym workout generation by equipment/time/goal. |

If `GEMINI_API_KEY` is unset, AI endpoints return `503 NOT_CONFIGURED` (never a fake success).

## Water

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/water/today?date=` | Day's water entries + total ml. |
| POST | `/api/water` | Add a water entry (`dateKey`, `amountMl`). |
| DELETE | `/api/water/:id` | Remove an entry. |

## Routines

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/routines` | All routines. |
| GET | `/api/routines/today?date=` | Scheduled routines for a date + completion %. |
| POST | `/api/routines` | Create routine. |
| PUT | `/api/routines/:id` | Update routine. |
| DELETE | `/api/routines/:id` | Delete routine (and its completions). |
| POST | `/api/routines/:id/complete` | Set completion status for a date. |

## Games (morning challenge)

| Method | Path | Description |
| --- | --- | --- |
| GET | `/api/games/summary` | Recent game history + current streak. |
| POST | `/api/games/result` | Record a game result. |

## Notifications

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/notifications/register-token` | Register an FCM token for the user. |
| DELETE | `/api/notifications/token` | Remove an FCM token. |

## AI (Gemini via backend)

All require auth and use a stricter rate limit. Responses are validated
structured JSON; recommended exercise IDs are validated against the library.
Returns `503 NOT_CONFIGURED` when `GEMINI_API_KEY` is unset.

| Method | Path | Description |
| --- | --- | --- |
| POST | `/api/ai/daily-insight` | Short personalized daily insight. |
| POST | `/api/ai/workout-recommendation` | Structured workout plan (valid exercise IDs). |
| POST | `/api/ai/generate-workout` | Home/gym workout generation by location/muscle/time. |
| POST | `/api/ai/nutrition-recommendation` | Nutrition suggestions. |
| POST | `/api/ai/exercise-substitution` | Alternatives for an exercise. |
| POST | `/api/ai/recovery` | Recovery-aware muscle focus/rest guidance. |
| POST | `/api/ai/progress-analysis` | Natural-language training trend analysis. |
| POST | `/api/ai/chat` | Contextual coach chat; persists to `aiConversations`. |

Full request/response schemas are defined by the Zod validators in `backend/src/validators` and are the source of truth.
