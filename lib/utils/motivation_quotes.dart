class MotivationQuotes {
  // Quotes for beginners or those who lost their streak (0-2 days)
  static final List<String> _starterQuotes = [
    "Discipline is choosing what you want most over what you want now.",
    "Motivation gets you started but habit keeps you going.",
    "Do the work even when you do not feel like it.",
    "Feelings are temporary but results are permanent.",
    "Self-control is the true sign of strength.",
    "Action creates motivation not the other way around.",
    "There is no substitute for focused hard work.",
    "Your future is created by what you do today.",
    "Stop wishing for it and start working for it.",
    "Master your mood or it will master you.",
    "The exam does not care about your excuses.",
    "Your competition is working hard right now.",
    "Results are just a reflection of your daily habits.",
    "Preparation today prevents regret tomorrow.",
    "The pain of discipline is less than the pain of regret.",
    "You are building your future with every page you turn.",
    "Hard work beats talent when talent fails to work hard.",
    "Earn your rest by completing your tasks first.",
    "This struggle is temporary but the glory is forever.",
    "Luck favors those who are well prepared.",
  ];

  // Quotes for those with momentum (3+ days)
  static final List<String> _keeperQuotes = [
    "Consistency is far more important than intensity.",
    "Small daily improvements lead to stunning results.",
    "A river cuts through rock not by power but by persistence.",
    "Slow progress is still better than no progress.",
    "Focus on the process and the results will follow.",
    "Success is the sum of small efforts repeated daily.",
    "You do not rise to your goals you fall to your systems.",
    "The only bad study session is the one that did not happen.",
    "Routine is the foundation of excellence.",
    "One percent better every day adds up over time.",
    "Protect your momentum at all costs.",
    "Do not let a single day go to waste.",
    "Consistency builds confidence and mastery.",
    "Momentum is hard to build but very easy to lose.",
    "A missed day is a lost opportunity to improve.",
    "Keep the chain unbroken to see real change.",
    "Do not negotiate with your daily routine.",
    "Your streak is proof of your dedication.",
    "Stay on the path you have chosen for yourself.",
    "Continuity is the secret to deep learning.",
  ];

  /// Returns a daily quote based on the user's streak.
  /// Logic:
  /// 1. If Streak < 3: Show "Starter" quotes (Discipline/Reality).
  /// 2. If Streak >= 3: Show "Keeper" quotes (Progress/Streak).
  /// 3. Rotates daily using the Day of the Year to avoid repetition.
  static String getQuote(int streak) {
    final DateTime now = DateTime.now();
    // Calculate a simple "Day ID" (e.g., 2026 * 366 + 25)
    final int dayId =
        (now.year * 366) + now.difference(DateTime(now.year, 1, 1)).inDays;

    if (streak < 3) {
      // Use modulo to cycle through the list safely
      return _starterQuotes[dayId % _starterQuotes.length];
    } else {
      return _keeperQuotes[dayId % _keeperQuotes.length];
    }
  }
}
