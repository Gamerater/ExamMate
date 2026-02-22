import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskRepository {
  static const String _keyTasks = 'tasks_data';

  Future<List<Task>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString(_keyTasks);

    if (tasksString == null) return [];

    try {
      final dynamic decoded = jsonDecode(tasksString);
      if (decoded is List) {
        return decoded.map((item) => Task.fromMap(item)).toList();
      }
    } catch (e) {
      // Return empty safely on corruption
    }
    return [];
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> mapList =
        tasks.map((t) => t.toMap()).toList();
    await prefs.setString(_keyTasks, jsonEncode(mapList));
  }
}
