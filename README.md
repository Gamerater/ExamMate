# ExamMate – Competitive Exam Planner

Welcome to **ExamMate**, a streamlined, distraction-free planner created for Indian students preparing for competitive exams such as JEE, NEET, UPSC, SSC, Banking, and custom exams. The app is designed from the ground up, focusing on daily consistency and usability over excessive features.

---

## At a Glance

- **Intuitive Exam Selection:** Quickly choose from JEE, NEET, UPSC, SSC, Banking, or add custom exams.
- **Personalized Countdown:** Track the number of days remaining until your specific exam date.
- **Comprehensive Daily Task Planner:** Prioritize, label, and color-code your study tasks for optimal organization.
- **Streak and Progress Tracking:** Visual tools to monitor consistent study habits and daily accomplishment streaks.
- **Zero Distractions:** Minimal UI, no ads (premium planned), no sign-in required. All data stays on the device.
- **100% Offline:** Your data is always stored locally and never leaves your device.

---

## Who Should Use ExamMate?

- Exam aspirants seeking a **simple, effective planning tool**
- Students who value **consistent daily routines and progress tracking**
- Anyone frustrated with complex, data-collecting or bloated planner apps

---

## Technology Overview

| Layer      | Technology            |
|------------|----------------------|
| Frontend   | Flutter (Material 3) |
| Language   | Dart                 |
| State      | setState(), StatefulWidgets (no external state management package) |
| Storage    | SharedPreferences (key-value persistence) |
| Platform   | Android (initial supported target) |
| IDE        | Android Studio       |

- **Routing:** Named routes with explicit mapping in `main.dart`
- **Persistence:** All tasks and app config stored via `SharedPreferences`
- **No Backend:** All features operate 100% offline, with no API calls or remote storage
- **No paid APIs:** Entirely free and open local ecosystem

---

## Project Structure

```
lib/
├── main.dart                   # Entry point & route configuration
├── screens/
│   ├── splash_screen.dart      # Splash/intro logic with animation
│   ├── exam_selection_screen.dart    # Exam selection interface
│   ├── home_screen.dart        # Dashboard with countdown and navigation
│   ├── task_screen.dart        # Task management (add/edit/prioritize)
│   ├── progress_screen.dart    # Analytics & streak display
│   └── settings_screen.dart    # App settings, theme toggling
├── models/
│   └── task.dart               # Task data model with migration for new fields
└── utils/
    └── constants.dart          # Color values, constant strings, and settings
```

Each directory is single-responsibility, making onboarding and scaling easier.

---

## User Journey

1. **Launch:** User is greeted with an animated splash screen.
2. **Select Exam & Date:** User sets up a personalized countdown by selecting their exam and exam date.
3. **Dashboard:** Displays the real-time countdown and a task overview.
4. **Task Management:** Add, edit, reorder, label, and categorize study tasks. Tasks can be color-coded and prioritized.
5. **Progress Tracking:** Review daily streak, history, and task statistics.

All navigation is handled via Flutter's named routing as defined in `main.dart`.

---

## Major Features

- **Customizable Exam Selection and Countdown:** Support for both preset and user-defined exams.
- **Task Handling:** Creation, editing, prioritization, deletion, completion toggling, and labeling of tasks.
- **Advanced Progress Logic:** Compute streaks, visualize completion stats, and indicate patterns.
- **Color and Priority Tagging:** Dynamically assign colors and labels to improve task visibility.
- **Local-first Data Storage:** No data leaves your device for ultimate privacy.

**Technical details:**  
Tasks are stored as JSON-encoded Maps using SharedPreferences. The `Task` model supports migration for new fields, ensuring backward compatibility.

---

## Quality & Testing

- **Manual Testing:** Comprehensive coverage by actually using edge cases (empty tasks, streak resets, app relaunch, etc.)
- **Navigation Testing:** All navigation flows validated through repeated cycles.
- **Error Handling:** All exceptions and edge cases are caught and addressed within UI or logic layers.
- **Plans for Automated Testing:** Currently using manual QA processes; unit/widget/integration test suites are planned.

---

## Dependencies

Dependencies are kept minimal and strictly reviewed for necessity:

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.2
```
No third-party state management or analytics libraries included.

---

## Platform Support

- **Android:** Fully supported and stable.
- **iOS:** In active development, support planned.
- **Web:** Experimental PWA support is under review.

---

## Monetization (Planned, non-intrusive)

- **Optional Google AdMob:** For banner/interstitial ads, only if enabled.
- **Premium Upgrade:** Removes ads, unlocks unlimited tasks, enables export to PDF planner.

---

## Privacy Promise

- No login required.
- No personal information collected, ever.
- No backend servers—your entire dataset is only on your device.

---

## Roadmap

- Automatic daily task reset at midnight to encourage healthy study habits
- Enhanced analytics for streaks and progress computation
- (Optional) Reminders/notifications (using local notifications library)
- Support for dark mode and improved accessibility
- iOS App Store release and Web PWA deployment
- Monetization only after essential features are fully stable

---

## Beginner Philosophy

- Focus strictly on **one feature at a time**; ensure stability and clarity.
- **One Dart file per screen** model to simplify navigation and maintainability.
- Avoid premature optimization and dependency overuse.
- Maximize readability and learnability.

---

## Contribute

Contributions are open for:

- UI/UX enhancements
- Bug fixes
- New or experimental features

Explore `lib/` for clear, single-responsibility files. Start small with PRs or issues!

---

## Final Thought

ExamMate is built for learners and self-discipline—engineered to help serious students track, plan, and stay consistent in their preparation, leveraging the full potential of Flutter and modern app design principles.

---