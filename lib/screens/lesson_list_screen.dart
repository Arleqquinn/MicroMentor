import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../services/database_service.dart';
import 'lesson_detail_screen.dart';

class LessonListScreen extends StatefulWidget {
  final Course course;

  LessonListScreen({required this.course});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final DatabaseService _db = DatabaseService();

  List<String> completedLessons = [];
  Map<String, DateTime> completionDates = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final ids = await _db.getCompletedIds();
    final dates = await _db.getLessonCompletionDates();

    if (mounted) {
      setState(() {
        completedLessons = ids;
        completionDates = dates;
      });
    }
  }

  bool _isReviewAvailable(String lessonId) {
    final completionDate = completionDates[lessonId];
    if (completionDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return today.difference(completionDate).inDays >= 1;
  }

  String _statusText(Lesson lesson) {
    final isDone = completedLessons.contains(lesson.id);
    if (!isDone) return 'Новый урок';

    if (_isReviewAvailable(lesson.id)) {
      return 'Доступен для повторения';
    }

    return 'Пройден сегодня';
  }

  Color _statusColor(Lesson lesson) {
    final isDone = completedLessons.contains(lesson.id);
    if (!isDone) return Colors.blue;

    if (_isReviewAvailable(lesson.id)) {
      return Colors.orange;
    }

    return Colors.green;
  }

  IconData _statusIcon(Lesson lesson) {
    final isDone = completedLessons.contains(lesson.id);
    if (!isDone) return Icons.radio_button_off;

    if (_isReviewAvailable(lesson.id)) {
      return Icons.refresh;
    }

    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.title), centerTitle: true),
      body: FutureBuilder<List<Lesson>>(
        future: _db.getLessonsFromApi(widget.course.contentUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text("Не удалось загрузить уроки. Проверьте JSONBin."),
            );
          }

          final lessons = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _loadProgress,
            child: ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                final color = _statusColor(lesson);

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(_statusIcon(lesson), color: color),
                    ),
                    title: Text(
                      lesson.title,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Урок ${index + 1}"),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusText(lesson),
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(Icons.play_arrow, size: 18),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => LessonDetailScreen(lesson: lesson),
                        ),
                      );
                      await _loadProgress();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
