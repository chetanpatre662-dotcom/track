# AI

FitTrack's AI Coach uses **Google Gemini**, accessed exclusively through the Node.js backend via the official `@google/genai` SDK. The API key lives only in backend env (`GEMINI_API_KEY`) and is never shipped in the Flutter app.

## Model

- Default: `gemini-2.0-flash` (`GEMINI_MODEL`).
- Fallback: `gemini-2.0-flash-lite` (`GEMINI_MODEL_FALLBACK`), used on transient errors.
- Deprecated model names / APIs are not used.

## Request flow

```
Flutter → POST /api/ai/* (Bearer ID token)
   → verify token, derive UID
   → build COMPACT context from Firestore (never the whole DB)
   → call Gemini with responseMimeType: application/json + a strict schema
   → parse + Zod-validate the JSON
   → validate any exerciseIds against the Firestore exercise library
   → return the validated structured object (or a safe fallback / NOT_CONFIGURED)
```

## Context building (`backend/src/ai`)

Only the fields relevant to the request are sent:

- **User:** age, height, weight, goal(s), fitness level, equipment, workout location, activity level.
- **Workout:** today's workout, recent workouts, muscle groups trained, sets/reps/weight, volume, frequency, last-trained dates (for recovery-aware suggestions).
- **Nutrition:** today's calories/protein/carbs/fat, remaining targets, recent meals.
- **Lifestyle:** sleep/wake, routine completion, water.
- **Exercise library slice:** only candidate exercises matching the user's equipment/location/target muscle — so the model can only pick real IDs.

The full database is never sent.

## Structured responses

### Workout recommendation
```jsonc
{
  "title": "string",
  "goal": "string",
  "durationMinutes": 45,
  "exercises": [
    { "exerciseId": "barbell-bench-press", "sets": 3, "repMin": 8, "repMax": 12, "restSeconds": 90, "reason": "string" }
  ],
  "notes": "string"
}
```
`exerciseId`s are validated against Firestore; any invalid ID causes a repair pass or the item is dropped. The model cannot invent IDs.

### Nutrition recommendation
```jsonc
{
  "summary": "string",
  "suggestions": [
    { "food": "string", "reason": "string", "estimatedProtein": 0, "estimatedCalories": 0 }
  ]
}
```

## Validation & resilience

- Responses are parsed as JSON and validated with Zod; on invalid output the backend retries once with a repair instruction, then falls back to a safe, useful message. The app never crashes on bad AI output.
- `NOT_CONFIGURED` (503) is returned when no key is present — a controlled error, never a fake success.

## Safety guardrails (enforced in the system prompt and post-validation)

The AI must not, and the backend rejects/reframes attempts to:

- diagnose diseases or prescribe medication;
- give dangerous exercise instructions;
- encourage extreme dieting, dehydration, or unsafe rapid weight loss;
- modify completed workouts, nutrition records, routines, or the profile without explicit user confirmation in the app.

Nutrition guidance is general and non-medical; for medical/nutritional conditions the AI recommends consulting a qualified professional.

## User confirmation

AI recommendations are proposals. Adding recommended exercises to a workout, changing targets, etc. always requires an explicit user action in the app — the backend never auto-writes user data from an AI response.
