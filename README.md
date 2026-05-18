# Work Hours App

A personal, offline-first Flutter app for tracking work hours across multiple projects. Log time with a built-in timer, review your history, and keep an eye on earnings — all stored locally on your device.

## Features

- **Project Management** — Create projects with a name, color label, and optional hourly rate
- **Timer Tracking** — Start/stop a timestamp-based timer per project; no background service required
- **Time Entry History** — Browse, filter, and manage all logged entries with notes
- **Earnings Overview** — Automatically calculates earnings based on logged hours and the project's hourly rate
- **Settings** — App-level preferences stored via `shared_preferences`
- **Fully Offline** — No accounts, no cloud sync; all data lives in a local SQLite database

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart SDK `^3.11.5`) |
| Database | [Drift](https://drift.simonbinder.eu/) (SQLite) `^2.33.0` |
| State Management | [flutter_riverpod](https://riverpod.dev/) `^2.3.0` |
| Persistence | [path_provider](https://pub.dev/packages/path_provider) `^2.1.5` |
| Formatting | [intl](https://pub.dev/packages/intl) `^0.18.0` |
| Preferences | [shared_preferences](https://pub.dev/packages/shared_preferences) `^2.5.5` |

## Project Structure

```
lib/
├── database/
│   ├── daos/          # Data Access Objects for Projects & TimeEntries
│   ├── database.dart  # Drift database definition
│   └── tables.dart    # Table schemas (Projects, TimeEntries)
├── models/            # Domain models
├── providers/         # Riverpod providers
├── screens/
│   ├── homescreen.dart
│   ├── timer_screen.dart
│   ├── project_list_screen.dart
│   ├── history_screen.dart
│   └── settings_screen.dart
├── utils/             # Helper functions
├── widgets/           # Reusable UI components
└── main.dart
```

## Database Schema

**Projects**
- `id` — auto-increment primary key
- `name` — project name (1–50 chars)
- `color` — hex color string (e.g. `#FF5733`)
- `hourlyRate` — optional, used for earnings calculation

**TimeEntries**
- `id` — auto-increment primary key
- `projectId` — foreign key → Projects (cascade delete)
- `startTime` / `endTime` — Unix timestamps (milliseconds)
- `note` — optional note (up to 500 chars)

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.5`
- Android SDK (for Android builds)

### Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Build (Android)

```bash
flutter build apk --release
```

## Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Supported |
| iOS | ⚠️ Not configured |
| Web / Desktop | 🧪 Scaffold present, untested |

## License

Private utility app — not published to pub.dev.
