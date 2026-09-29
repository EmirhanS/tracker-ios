# SportTracker

A gamified training tracker for amateur sports teams. Players log workouts and
team activities, earn points from a challenge's scoring rules, and compete on a
leaderboard.

This is **v1**. It has no backend: all data is held in memory and seeded with
sample data on start. The data layer sits behind repository interfaces so a
Supabase implementation can replace it later without touching the screens.

## Requirements

* Flutter 3.38.5 (stable), Dart 3.10.4
* Xcode with an iOS Simulator, to run the app on iOS

## Run it

```sh
flutter pub get
open -a Simulator            # macOS only
flutter run -d iPhone
```

See [docs/ios_simulator.md](docs/ios_simulator.md) for the full iOS Simulator
instructions.

On Windows or Linux there is no iOS Simulator. Use the desktop target instead:

```sh
flutter run -d windows
```

## Check it

```sh
flutter analyze
flutter test
```

### If `flutter test` exits with "Null check operator used on a null value"

`test_core` reads `LOCALAPPDATA` (Windows) or `HOME` and dereferences it with
`!`. Some sandboxes and CI images leave it empty, and the crash then points at
Flutter rather than at the environment. Set it before the command:

```sh
LOCALAPPDATA="$USERPROFILE\\AppData\\Local" flutter test
```

## Layout

| Path            | What lives there                                            |
| --------------- | ----------------------------------------------------------- |
| `lib/core`      | Router, strings, theme, shared widgets                      |
| `lib/domain`    | Plain Dart models, points engine, validators, templates     |
| `lib/features`  | One folder per screen or flow                               |
| `test/`         | Unit tests for the domain and the data layer                |

The design is written up in [docs/plan.md](docs/plan.md).
