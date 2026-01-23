# ExamMate – Competitive Exam Planner App

ExamMate is a simple Flutter-based Android app designed for Indian students preparing for competitive exams such as JEE, NEET, UPSC, SSC, and Banking. The app focuses on daily consistency, not complexity.

This project is built from scratch by a beginner, using AI for development, testing, and debugging, without any paid tools or APIs.

---

## Features

- Exam selection (JEE, NEET, UPSC, SSC, Banking)
- Exam countdown timer
- Daily task planner
- Streak tracking
- Progress screen
- Clean, distraction-free UI
- Local storage only (no login, no backend)

---

## Target Users

- Indian competitive exam aspirants
- Students seeking simple planning, daily discipline, and minimal features

---

## Tech Stack

| Layer      | Technology                     |
|------------|-------------------------------|
| Frontend   | Flutter                       |
| Language   | Dart                          |
| Storage    | Local (SharedPreferences)      |
| Platform   | Android (initial release)      |
| IDE        | Android Studio                 |
| AI Usage   | External (ChatGPT or similar)  |

No paid APIs, backend, or in-IDE AI.

---

## Project Folder Structure

```
lib/
├── main.dart
├── screens/
│   ├── splash_screen.dart
│   ├── exam_selection_screen.dart
│   ├── home_screen.dart
│   ├── task_screen.dart
│   └── progress_screen.dart
├── models/
│   └── task.dart
└── utils/
    └── constants.dart
```

Folders:
- `screens/`: UI screens
- `models/`: Data models (e.g., Task)
- `utils/`: Constants, helpers
- `main.dart`: App entry and routing

---

## App Flow

1. Launches: Splash Screen
2. Exam selection
3. Home dashboard
4. Daily task management
5. Streak and progress tracking

Navigation uses Flutter Named Routes.

---

## Development Approach

- AI is used for writing, reviewing, testing, and debugging code
- IDE is used to paste code, run the app, and view errors
- No IDE-integrated AI

---

## AI Workflow

1. Request code for a single file from AI
2. Copy-paste into project
3. Run the app
4. Copy any errors back to AI and apply fixes

---

## Testing

- Manual and AI-assisted testing
- File-level and navigation tests
- Edge cases: no tasks, streak reset, app restart
- No automated tests yet

---

## Debugging

- All errors are copied exactly and fixed with AI guidance
- No guessing or silent fixes

---

## Dependencies

Minimal dependencies.

Example:
```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.2.2
```
Dependencies added only as required.

---

## Platform Support

- Android (current)
- iOS (planned)
- Web (optional, planned)

---

## Monetization (Planned)

- Google AdMob (banner, interstitial)
- Optional premium version:
  - Ad-free
  - Unlimited tasks
  - Planner export (PDF)

Monetization after first stable release.

---

## Privacy Policy

- No login
- No personal data collected
- No backend
- All data stays on the device

---

## Roadmap

- Daily task auto-reset
- Improved streak logic
- Reminder notifications
- Dark mode
- iOS release
- Ads integration

---

## Beginner Rules Followed

- One feature at a time
- One file per screen
- No premature optimization
- Avoid overengineering
- Shipping is prioritized over perfection

---

## Contribution

This is a learning-first project. Contributions welcome for:
- UI improvements
- Bug fixes
- Feature suggestions

---

## Final Note

This app is built to help learners ship, learn, and grow, not to impress developers.

---
