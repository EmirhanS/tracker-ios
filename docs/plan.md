# SportTracker (Flutter, iOS) — v1 with seasons and configurable scoring rules

## Context

SportTracker is a gamified training tracker for amateur sports teams. Players log workouts and team activities, earn points based on the active season's scoring rules, and compete on a leaderboard. This first version runs on the iOS Simulator with no backend: all data lives in memory, seeded with sample data. A Supabase backend will be added later, so the data layer is built around repository interfaces.

Scope of this version: v1 screens (welcome, dashboard, log activity, my activities, leaderboard) **plus** season setup with configurable scoring rules. Only the **General Fitness** template is built in.

Toolchain: Flutter 3.38.5 stable, Dart 3.10.4. Dependencies: `flutter_riverpod`, `go_router`, `intl`, `flutter_lints` (dev). No code generation.

## Folder tree

```
lib/
  main.dart                       # ProviderScope with repository overrides (Supabase swap point)
  app.dart                        # MaterialApp.router, theme
  core/
    router/app_router.dart        # go_router config, redirects
    strings/app_strings.dart      # all user-facing strings (English), error-to-text mapping
    theme/app_theme.dart          # Material 3, burgundy seed, light + dark
    widgets/                      # shared widgets (empty state, points chip, ...)
  domain/                         # plain Dart, no Flutter imports
    models/player.dart
    models/season.dart            # Season, SeasonStatus
    models/scoring_rule.dart      # ScoringRule, sealed Scoring, DistanceTier
    models/activity.dart          # Activity, ActivityInput
    points/points_engine.dart     # PointsEngine, PointsResult, PointsError
    validation/rule_validator.dart
    validation/season_validator.dart
    templates/season_templates.dart
    exceptions.dart               # SeasonLockedException
  data/
    repositories/player_repository.dart      # interfaces
    repositories/season_repository.dart
    repositories/activity_repository.dart
    in_memory/in_memory_*_repository.dart    # implementations
    in_memory/seed_data.dart
    in_memory/id_generator.dart
    providers.dart                # repository providers (UI depends only on these)
  features/
    session/current_player_provider.dart     # auth placeholder
    welcome/welcome_screen.dart
    shell/app_shell.dart                     # bottom navigation
    dashboard/
    log_activity/
    my_activities/
    leaderboard/
    season/                                  # setup flow + read-only rules screen
test/
  domain/   points_engine_test, rule_validator_test, season_validator_test, season_templates_test
  data/     in_memory_season_repository_test, in_memory_activity_repository_test
```

## Domain design

### Models

* `Player { id, name }`
* `Season { id, name, startDate, endDate, captainId, status (draft | active), rules }` with `isActive`, `isLocked` helpers.
* `ScoringRule { id, name, emoji?, isEnabled, scoring }`
* `sealed class Scoring`:
  * `FixedScoring(points, minDurationMinutes?)`
  * `TimeBasedScoring(pointsPerBlock, minutesPerBlock, minDurationMinutes)`
  * `DistanceTierScoring(tiers: List<DistanceTier(minKm, points)>)`
  * `requiresDuration` / `requiresDistance` getters drive which inputs the Log screen shows.
* `ActivityInput { durationMinutes?, distanceKm? }`
* `Activity { id, playerId, seasonId, ruleId, ruleName, date, durationMinutes?, distanceKm?, notes?, points, createdAt }`. Points and rule name are frozen at log time; totals are sums over activities, so deleting an activity removes its points by construction.

### Points engine

* `PointsEngine.calculate(rule, input) -> PointsResult` where `PointsResult = PointsSuccess(points) | PointsFailure(error)`.
* `PointsError`: `ruleDisabled`, `durationRequired`, `belowMinimumDuration(minimum)`, `distanceRequired`, `belowMinimumDistance(minimum)`.
* Time-based: `(duration ~/ minutesPerBlock) * pointsPerBlock`, fails below minimum. Distance tiers: highest threshold first, first match wins; below lowest tier is invalid.

### Validation

* `RuleValidator.validate(rule, otherRules)`: name required and unique (case-insensitive), points 0-100, time-based `minutesPerBlock >= 1` and `minDuration >= minutesPerBlock`, tiers non-empty with positive unique thresholds and non-decreasing points.
* `SeasonValidator.validateDetails(name, start, end)` (end after start) and `validateForStart(season)` (at least one enabled rule, every enabled rule valid).
* `SeasonLockedException` thrown by the repository when rules of an active season are modified.

### General Fitness template

One point is roughly 30 minutes of moderate effort; harder or longer efforts scale up; max 6 per activity so nothing dominates.

| Rule            | Type           | Values                                                           |
| --------------- | -------------- | ---------------------------------------------------------------- |
| Gym session     | Fixed          | 3 pts, min 45 min                                                |
| Running         | Distance tiers | 3 km -> 1, 5 km -> 2, 10 km -> 4, 15 km -> 6; below 3 km invalid |
| Cycling         | Time-based     | 1 pt per 30 min, min 30 min                                      |
| Team sport      | Fixed          | 4 pts, min 60 min                                                |
| Yoga / mobility | Fixed          | 1 pt, min 30 min                                                 |

Templates copy rules with fresh ids into the season, so editing a season never touches the template.

## Data layer

* Interfaces are `Future`-based CRUD plus `Stream<List<T>> watchAll()` so a Supabase implementation drops in later.
* `SeasonRepository`: `createDraft`, `updateSeason` (throws `SeasonLockedException` if active), `startSeason` (validates, sets active), `watchActiveSeason`.
* Seed: 7 players, one active season "Autumn 2026" from General Fitness (captain = first player), ~25 activities over the last few weeks with points computed through `PointsEngine` at seed time.

## App and features

* Strings in one `AppStrings` class. Theme: `ColorScheme.fromSeed(0xFF8C1C2C)`, light + dark, system mode.
* Routes: `/welcome`, shell with `/dashboard`, `/log`, `/activities`, `/leaderboard`; `/season/new`, `/season/:id/template`, `/season/:id/rules`, `/season/:id/rules/:ruleId`, `/season/:id/review`, `/scoring-rules`. Redirect to welcome without a current player; season setup only for the captain.
* Current player is a Riverpod `Notifier<Player?>`, isolated so Google/Apple sign-in can replace it.
* Dashboard: season points, points this week (Mon-Sun), 5 most recent activities. Empty state when no active season, with a setup button.
* Log activity: rule picker from enabled rules, date, duration/distance as required, notes, live preview and validation errors.
* My activities: swipe-to-delete. Leaderboard: ranked by season points.
* Season setup: create -> template -> rules editor -> review and start (with confirmation). Read-only "Scoring rules" screen for everyone.

## Build order (analyze + test green and a commit after each step)

1. Scaffold, dependencies, strings, theme, this document.
2. Domain models, `Scoring`, `PointsEngine`, tests.
3. Validators, templates, tests.
4. Repository interfaces, in-memory implementations, seed data, tests.
5. App shell: main, providers, router, welcome, bottom nav.
6. Dashboard, Log activity, My activities, Leaderboard.
7. Season setup flow, scoring rules screen, captain gating, empty states.
8. Final checks and iOS Simulator run instructions.

## Note on this machine

The build host runs Windows, so the iOS Simulator cannot be launched here. Step 8 delivers written iOS Simulator run instructions plus proof that `flutter analyze` is clean and `flutter test` passes.
