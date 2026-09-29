# Running SportTracker on the iOS Simulator

The iOS Simulator only runs on macOS. This project was built on Windows, so the
steps below were written from the Flutter iOS workflow and have not been run on
this machine. `flutter analyze` and `flutter test` were run here and both pass.

## What you need

| Tool           | Version                        |
| -------------- | ------------------------------ |
| macOS          | Sonoma or newer                |
| Xcode          | 15 or newer, from the App Store |
| Flutter        | 3.38.5 stable                  |
| Dart           | 3.10.4 (comes with Flutter)    |
| CocoaPods      | 1.13 or newer                  |

## First time setup

1. Install Xcode, then accept the licence and install the command line tools:

   ```sh
   sudo xcodebuild -license accept
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   xcodebuild -runFirstLaunch
   ```

2. Install an iOS simulator runtime. In Xcode: **Settings → Components**, then
   add an iOS runtime (iOS 17 or newer).

3. Install CocoaPods:

   ```sh
   sudo gem install cocoapods
   ```

4. Check that Flutter is happy:

   ```sh
   flutter doctor
   ```

   The lines for **Xcode** and **Connected device** must both be green.

## Run the app

```sh
cd sporttracker
flutter pub get

open -a Simulator          # starts the simulator
flutter devices            # shows the simulator in the list
flutter run                # or: flutter run -d "iPhone 15"
```

The first build takes a few minutes because CocoaPods has to fetch the iOS
pods. Later builds are much faster.

While the app runs:

* `r` — hot reload
* `R` — hot restart (this also rebuilds the seed data)
* `q` — quit

## What you should see

1. **Welcome** — pick a player from the roster of seven. Pick **Mia Halvorsen**
   to be the captain.
2. **Dashboard** — season points, points this week, and the five newest
   activities of the player you picked.
3. **Log** — choose an activity, set the date, fill in the duration or the
   distance the rule asks for. The box above the button shows the points you
   will earn, or why the entry does not score yet.
4. **My activities** — swipe a row to the left to delete it. The total in the
   app bar drops straight away.
5. **Leaderboard** — the whole team ranked by season points.
6. The **rule icon** in the dashboard app bar opens the read-only scoring rules.

To see the season setup flow, sign out with the **switch account** icon and
start the app from a state with no season. The seed data always starts one
season, so the quickest way is to comment out the season in
`lib/data/in_memory/seed_data.dart`, or to run the widget tests, which cover the
whole setup flow (`test/features/season_setup_test.dart`).

## Build a release .app

```sh
flutter build ios --simulator
```

The result lands in `build/ios/iphonesimulator/Runner.app`. Drag it onto a
running simulator window to install it.

## If something goes wrong

| Problem                                    | What to do                                                     |
| ------------------------------------------ | -------------------------------------------------------------- |
| `No devices found`                          | Start the simulator first: `open -a Simulator`                 |
| CocoaPods errors on the first build         | `cd ios && pod repo update && pod install`                     |
| Stale build after changing dependencies     | `flutter clean && flutter pub get`                             |
| `flutter doctor` complains about the licence | `sudo xcodebuild -license accept`                              |

## Note for Windows or Linux

You cannot run iOS from Windows or Linux. To see the app work on those hosts,
use the desktop target that ships with this project:

```sh
flutter run -d windows
```

The app is the same: the data layer is in memory and has no platform code.
