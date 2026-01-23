class Task {
  String title;
  bool isCompleted;

  Task({
    required this.title,
    this.isCompleted = false,
  });

  // Convert a Task object into a Map object (for saving to database/prefs)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  // Convert a Map object back into a Task object (for loading from database/prefs)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      title: map['title'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
