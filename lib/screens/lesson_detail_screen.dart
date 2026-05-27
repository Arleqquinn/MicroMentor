import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../services/database_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  LessonDetailScreen({required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final DatabaseService _db = DatabaseService();

  int currentQuestionIndex = 0;
  bool showQuiz = false;
  int? selectedAnswerIndex;
  bool isCorrect = false;
  List<String> shuffledAnswers = [];
  late String correctAnswer;

  int correctAnswersCount = 0;
  bool isFinishingLesson = false;

  void _prepareQuestion() {
    final q = widget.lesson.questions[currentQuestionIndex];
    correctAnswer = q.answers[q.correctIndex];
    shuffledAnswers = List<String>.from(q.answers)..shuffle();
    selectedAnswerIndex = null;
  }

  Future<void> _handleAnswer(int index) async {
    if (selectedAnswerIndex != null || isFinishingLesson) return;

    final selectedIsCorrect = shuffledAnswers[index] == correctAnswer;

    setState(() {
      selectedAnswerIndex = index;
      isCorrect = selectedIsCorrect;
      if (selectedIsCorrect) {
        correctAnswersCount++;
      }
    });

    await Future.delayed(Duration(milliseconds: 1100));

    if (currentQuestionIndex < widget.lesson.questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _prepareQuestion();
      });
    } else {
      await _finishLesson();
    }
  }

  Future<void> _finishLesson() async {
    if (isFinishingLesson) return;

    setState(() {
      isFinishingLesson = true;
    });

    final beforeStats = await _db.getUserStats();
    final beforeAchievements = List<String>.from(
      beforeStats['achievements'] ?? [],
    );

    await _db.saveProgress(widget.lesson.id);

    final afterStats = await _db.getUserStats();
    final afterAchievements = List<String>.from(
      afterStats['achievements'] ?? [],
    );

    final newAchievements = afterAchievements
        .where((a) => !beforeAchievements.contains(a))
        .toList();

    final totalQuestions = widget.lesson.questions.length;
    final percent = ((correctAnswersCount / totalQuestions) * 100).round();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Урок завершён'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow(
              icon: Icons.check_circle,
              color: Colors.green,
              text:
                  'Правильных ответов: $correctAnswersCount из $totalQuestions',
            ),
            SizedBox(height: 10),
            _resultRow(
              icon: Icons.quiz,
              color: Colors.deepPurple,
              text: 'Результат: $percent%',
            ),
            SizedBox(height: 10),
            _resultRow(
              icon: Icons.stars_rounded,
              color: Colors.orange,
              text: 'Баллы: ${afterStats['points'] ?? 0}',
            ),
            SizedBox(height: 10),
            _resultRow(
              icon: Icons.local_fire_department,
              color: Colors.redAccent,
              text: 'Текущий стрик: ${afterStats['currentStreak'] ?? 0}',
            ),
            SizedBox(height: 10),
            _resultRow(
              icon: Icons.trending_up,
              color: Colors.green,
              text: 'Уровень: ${afterStats['level'] ?? 1}',
            ),
            if (newAchievements.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Новое достижение:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: 8),
              ...newAchievements.map(
                (achievementId) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _achievementIcon(achievementId),
                          color: Colors.deepPurple,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(_achievementTitle(achievementId))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Отлично'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _resultRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 15))),
      ],
    );
  }

  String _achievementTitle(String id) {
    switch (id) {
      case 'first_lesson':
        return 'Первый шаг';
      case 'five_lessons':
        return '5 уроков';
      case 'streak_3':
        return '3 дня подряд';
      case 'points_100':
        return '100 баллов';
      default:
        return id;
    }
  }

  IconData _achievementIcon(String id) {
    switch (id) {
      case 'first_lesson':
        return Icons.flag;
      case 'five_lessons':
        return Icons.menu_book;
      case 'streak_3':
        return Icons.local_fire_department;
      case 'points_100':
        return Icons.stars;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showQuiz && shuffledAnswers.isEmpty) {
      _prepareQuestion();
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: !showQuiz ? _buildContent() : _buildQuiz(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: Colors.deepPurple),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Микроурок рассчитан примерно на 3–5 минут.',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              widget.lesson.content,
              style: TextStyle(fontSize: 18, height: 1.5),
            ),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 52),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => setState(() => showQuiz = true),
            child: Text("Пройти тест"),
          ),
        ),
        SizedBox(height: 80),
      ],
    );
  }

  Widget _buildQuiz() {
    final q = widget.lesson.questions[currentQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: (currentQuestionIndex + 1) / widget.lesson.questions.length,
          borderRadius: BorderRadius.circular(12),
        ),
        SizedBox(height: 20),
        Text(
          "Вопрос ${currentQuestionIndex + 1} из ${widget.lesson.questions.length}",
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 10),
        Text(
          q.question,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 30),
        ...List.generate(shuffledAnswers.length, (index) {
          Color cardColor = Colors.white;
          Color borderColor = Colors.grey.shade300;

          if (selectedAnswerIndex != null) {
            if (shuffledAnswers[index] == correctAnswer) {
              cardColor = Colors.green.shade100;
              borderColor = Colors.green;
            } else if (selectedAnswerIndex == index) {
              cardColor = Colors.red.shade100;
              borderColor = Colors.redAccent;
            }
          }

          return GestureDetector(
            onTap: () => _handleAnswer(index),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 220),
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shuffledAnswers[index],
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  if (selectedAnswerIndex != null &&
                      shuffledAnswers[index] == correctAnswer)
                    Icon(Icons.check, color: Colors.green),
                ],
              ),
            ),
          );
        }),
        if (isFinishingLesson) ...[
          SizedBox(height: 12),
          Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
