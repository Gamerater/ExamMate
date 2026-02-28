import '../models/task.dart';
import '../repositories/task_repository.dart';

enum SortOption { creation, highToLow, lowToHigh }

class TaskService {
  final TaskRepository _repo = TaskRepository();

  // Sorts tasks in-memory
  List<Task> sortTasks(List<Task> tasks, SortOption sortOption) {
    List<Task> sorted = List.from(tasks);
    sorted.sort((a, b) {
      // Completed always at bottom
      if (a.status == TaskStatus.completed &&
          b.status != TaskStatus.completed) {
        return 1;
      }
      if (a.status != TaskStatus.completed &&
          b.status == TaskStatus.completed) {
        return -1;
      }

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
      String sub = (t.subject == null || t.subject!.trim().isEmpty)
          ? 'General'
          : t.subject!.trim();
      return sub == subjectFilter;
    }).toList();
  }

  // Groups tasks into a Map
  Map<String, List<Task>> groupTasksBySubject(List<Task> tasks) {
    Map<String, List<Task>> grouped = {};
    for (var t in tasks) {
      String sub = (t.subject == null || t.subject!.trim().isEmpty)
          ? 'General'
          : t.subject!.trim();
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
      if (t.isTemporary &&
          t.deadline != null &&
          t.deadline!.isBefore(now) &&
          t.status != TaskStatus.completed) {
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
      subjects.add((t.subject == null || t.subject!.trim().isEmpty)
          ? 'General'
          : t.subject!.trim());
    }
    List<String> result = subjects.toList();
    result.sort(); // Alphabetical
    result.insert(0, "All Subjects");
    return result;
  }
}
