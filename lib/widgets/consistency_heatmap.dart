import 'package:flutter/material.dart';
import '../services/streak_service.dart';

class ConsistencyHeatmap extends StatelessWidget {
  const ConsistencyHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Configuration
    final now = DateTime.now();
    // Show last 35 days (5 weeks) for a clean grid
    const int totalDays = 35;

    // 2. Generate Dates (Oldest -> Newest)
    final List<DateTime> dates = List.generate(totalDays, (index) {
      return now.subtract(Duration(days: (totalDays - 1) - index));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Consistency (Last 30 Days)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        SizedBox(
          height: 100, // Fixed height for stability
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(), // No scrolling
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, // 7 Days a week
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0, // Square cells
            ),
            itemCount: totalDays,
            itemBuilder: (context, index) {
              return _buildDayCell(context, dates[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date) {
    // 1. Get Effort Data
    final service = StreakService();
    final dateKey =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final int effort = service.history[dateKey] ?? 0;

    // 2. Determine Color (The Design Logic)
    Color cellColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (effort == 0) {
      // Empty Day (No Shame - Neutral Color)
      cellColor = isDark ? Colors.white10 : Colors.grey[200]!;
    } else if (effort <= 2) {
      // Light Effort (MVP)
      cellColor = Colors.green.withOpacity(0.4);
    } else if (effort <= 5) {
      // Medium Effort
      cellColor = Colors.green.withOpacity(0.7);
    } else {
      // Strong Effort
      cellColor = Colors.green;
    }

    // 3. Highlight "Today" border
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(4),
        border: isToday ? Border.all(color: Colors.blueAccent, width: 2) : null,
      ),
    );
  }
}
