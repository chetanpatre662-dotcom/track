# DATABASE

Cloud Firestore. Private data is namespaced under `users/{uid}`; reference data is global and read-only to clients.

## Collections

### Private (owner-only)

```
users/{uid}                                     account meta (uid, email, createdAt, units, fcmTokens[])
users/{uid}/profile/data                        single profile doc (see schema below)
users/{uid}/routines/{routineId}                routine definitions
users/{uid}/routineCompletions/{completionId}   per-day completion records (dateKey, routineId, status)
users/{uid}/workouts/{workoutId}                workouts & templates
users/{uid}/workouts/{workoutId}/exercises/{workoutExerciseId}
users/{uid}/workouts/{workoutId}/exercises/{workoutExerciseId}/sets/{setId}
users/{uid}/foodLogs/{foodLogId}                logged food entries (dateKey, mealType, macros)
users/{uid}/meals/{mealId}                      saved meals / favorites / custom foods
users/{uid}/waterLogs/{waterLogId}              water entries (dateKey, amountMl)
users/{uid}/bodyMeasurements/{measurementId}    weight/waist/chest/... time series
users/{uid}/personalRecords/{recordId}          PRs (exerciseId, recordType, value, achievedAt)
users/{uid}/alarms/{alarmId}                     alarm definitions + persisted state
users/{uid}/aiConversations/{conversationId}     AI chat threads
users/{uid}/aiConversations/{conversationId}/messages/{messageId}
```

### Global (read-only to clients, written by backend Admin SDK)

```
exercises/{exerciseId}
foods/{foodId}
exerciseCategories/{categoryId}
muscleGroups/{muscleGroupId}
appConfig/{configId}
```

## Key schemas

### profile/data
```jsonc
{
  "name": "string",
  "photoUrl": "string?",
  "dateOfBirth": "timestamp?",
  "gender": "male|female|other|prefer_not_to_say",
  "heightCm": 178,
  "weightKg": 74.5,
  "fitnessLevel": "beginner|intermediate|advanced",
  "goals": ["muscle_gain", "fat_loss"],
  "activityLevel": "sedentary|light|moderate|active|very_active",
  "workoutDaysPerWeek": 4,
  "preferredWorkoutTime": "18:00",
  "workoutLocation": "home|gym|both",
  "equipment": ["dumbbell", "barbell", "bench"],
  "lifestyle": {
    "wakeTime": "06:30", "sleepTime": "23:00",
    "breakfastTime": "08:00", "lunchTime": "13:00", "dinnerTime": "20:00",
    "snackTimes": ["11:00", "16:00"],
    "waterReminderMinutes": 90
  },
  "targets": {                       // estimated; user-overridable; `isCustom` marks overrides
    "calories": 2400, "protein": 150, "carbs": 260, "fat": 70, "waterMl": 3000,
    "isCustom": false
  },
  "units": "metric|imperial",
  "updatedAt": "timestamp"
}
```

### exercises/{exerciseId}
```jsonc
{
  "id": "barbell-bench-press",
  "name": "Barbell Bench Press",
  "primaryMuscle": "chest",
  "secondaryMuscles": ["triceps", "shoulders"],
  "category": "chest",
  "location": "gym",                 // home | gym | both
  "equipment": ["barbell", "bench"],
  "difficulty": "intermediate",      // beginner | intermediate | advanced
  "type": "strength",                // strength|hypertrophy|cardio|mobility|bodyweight|hiit|stretching
  "instructions": ["...", "..."],
  "safetyNotes": ["..."],
  "recommendedSets": 3,
  "recommendedRepMin": 6,
  "recommendedRepMax": 12,
  "recommendedRestSeconds": 120,
  "imageUrl": "string?",
  "videoUrl": "string?",
  "keywords": ["chest", "press", "bench", "push"]
}
```

### workouts/{workoutId}
```jsonc
{
  "name": "Push Day",
  "type": "strength",
  "isTemplate": false,
  "status": "planned|in_progress|paused|completed|cancelled",
  "muscleGroups": ["chest", "shoulders", "triceps"],
  "startedAt": "timestamp?", "endedAt": "timestamp?",
  "durationSeconds": 0, "notes": "string?",
  "totalVolume": 0,                  // derived (kg·reps) cached at finish
  "createdAt": "timestamp", "updatedAt": "timestamp"
}
```
Each `exercises/{workoutExerciseId}`: `{ exerciseId, order, notes }`.
Each `sets/{setId}`: `{ setNumber, weightKg?, reps?, distanceM?, durationSeconds?, calories?, completed }`.

## Security rules

See [`firebase/firestore.rules`](../firebase/firestore.rules). Summary:

- `users/{uid}/**` — read/write only when `request.auth.uid == uid`.
- `exercises`, `foods`, `exerciseCategories`, `muscleGroups`, `appConfig` — readable by any signed-in user, never client-writable (seeded by the Admin SDK, which bypasses rules).
- Default deny on everything else.

Rule tests (in the testing slice) verify: user A cannot read/write user B's data; unauthenticated reads of private data are denied; reference data is readable when signed in and not writable by clients.

## Indexes

See [`firebase/firestore.indexes.json`](../firebase/firestore.indexes.json). Composite indexes are pre-declared for: workouts by status/date and template/updated; food logs by date/meal; water logs by date; routine completions; personal records; body measurements; AI conversations & messages; and exercise filtering (muscle+location, muscle+difficulty, type+location).

## Date handling

Timestamps stored in UTC. Per-day documents carry a `dateKey` (`yyyy-MM-dd` in the user's local timezone) so "today" queries are simple equality matches.
