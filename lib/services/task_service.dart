import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';

enum SortOption { creation, highToLow, lowToHigh }

class TaskService {
  final TaskRepository _repo = TaskRepository();
  static const String _keyLastResetDate = 'last_task_reset_date';

  // --- SMART DAILY RESET LOGIC ---
  /// Checks if a new calendar day has started. If so, resets all completed tasks to active.
  /// Returns [true] if a reset occurred, allowing the UI to notify the user.
  Future<bool> performDailyResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastResetStr = prefs.getString(_keyLastResetDate);
    
    final now = DateTime.now();
    final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // If it's the same day, do nothing.
    if (lastResetStr == todayStr) return false;

    // It's a new day (or first launch). Fetch tasks.
    List<Task> allTasks = await _repo.getTasks();
    if (allTasks.isEmpty) {
      // No tasks to reset, just update the date.
      await prefs.setString(_keyLastResetDate, todayStr);
      return false; 
    }

    bool tasksWereReset = false;

    for (var i = 0; i < allTasks.length; i++) {
      if (allTasks[i].status == TaskStatus.completed || allTasks[i].isCompleted == true) {
        allTasks[i].status = TaskStatus.active;
        allTasks[i].isCompleted = false;
        allTasks[i].completedAt = null;
        tasksWereReset = true;
      }
    }

    // Save changes and update date tracker
    if (tasksWereReset) {
      await _repo.saveTasks(allTasks);
    }
    await prefs.setString(_keyLastResetDate, todayStr);
    
    return tasksWereReset;
  }

  // --- EXISTING LOGIC ---

  // Sorts tasks in-memory
  List<Task> sortTasks(List<Task> tasks, SortOption sortOption) {
    List<Task> sorted = List.from(tasks);
    sorted.sort((a, b) {
      // Completed always at bottom
      if (a.status == TaskStatus.completed && b.status != TaskStatus.completed) return 1;
      if (a.status != TaskStatus.completed && b.status == TaskStatus.completed) return -1;

      switch (sortOption) {
        case SortOption.highToLow:
          return b.effort.index.compareTo(a.effort.index);
        case SortOption.lowToHigh:
          return a.effort.index.compareTo(b.effort.index);
        case SortOption.creation:
        default:
          return a.createdAt.compareTo(b.createdAt);
      }
    });
    return sorted;
  }

  // Filters tasks by subject
  List<Task> filterTasks(List<Task> tasks, String? subjectFilter) {
    if (subjectFilter == null || subjectFilter == "All Subjects") return tasks;
    return tasks.where((t) {
      String sub = (t.subject == null || t.subject!.trim().isEmpty) ? 'General' : t.subject!.trim();
      return sub == subjectFilter;
    }).toList();
  }

  // Groups tasks into a Map
  Map<String, List<Task>> groupTasksBySubject(List<Task> tasks) {
    Map<String, List<Task>> grouped = {};
    for (var t in tasks) {
      String sub = (t.subject == null || t.subject!.trim().isEmpty) ? 'General' : t.subject!.trim();
      if (!grouped.containsKey(sub)) grouped[sub] = [];
      grouped[sub]!.add(t);
    }
    return grouped;
  }

  // Removes expired tasks and returns how many were removed
  Future<int> removeExpiredTasks() async {
    List<Task> allTasks = await _repo.getTasks();
    int removedCount = 0;
    final now = DateTime.now();

    allTasks.removeWhere((t) {
      if (t.isTemporary && t.deadline != null && t.deadline!.isBefore(now) && t.status != TaskStatus.completed) {
        removedCount++;
        return true;
      }
      return false;
    });

    if (removedCount > 0) {
      await _repo.saveTasks(allTasks);
    }
    return removedCount;
  }

  // Fetch unique subjects for the filter dropdown
  List<String> getUniqueSubjects(List<Task> tasks) {
    Set<String> subjects = {};
    for (var t in tasks) {
      subjects.add((t.subject == null || t.subject!.trim().isEmpty) ? 'General' : t.subject!.trim());
    }
    List<String> result = subjects.toList();
    result.sort(); // Alphabetical
    result.insert(0, "All Subjects");
    return result;
  }
}