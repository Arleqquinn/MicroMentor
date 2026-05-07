import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../services/database_service.dart';
import 'lesson_detail_screen.dart';
import 'lesson_list_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();

  late Future<Map<String, dynamic>> _statsFuture;
  late Future<Map<String, dynamic>> _planFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _initStats();
    _planFuture = _db.getDailyPlan();
  }

  Future<Map<String, dynamic>> _initStats() async {
    await _db.ensureUserDocument();
    return _db.getUserStats();
  }

  Future<void> _refreshData() async {
    final statsFuture = _initStats();
    final planFuture = _db.getDailyPlan();

    if (mounted) {
      setState(() {
        _statsFuture = statsFuture;
        _planFuture = planFuture;
      });
    }

    await Future.wait([statsFuture, planFuture]);
  }

  Future<void> _openLesson(Lesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonDetailScreen(lesson: lesson)),
    );
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text('MicroMentor'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statsFuture,
          builder: (context, statsSnapshot) {
            if (statsSnapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: const [
                  SizedBox(height: 250),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (statsSnapshot.hasError || !statsSnapshot.hasData) {
              return ListView(
                padding: EdgeInsets.all(24),
                children: [
                  SizedBox(height: 80),
                  Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Не удалось загрузить данные пользователя',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: Text('Попробовать снова'),
                  ),
                ],
              );
            }

            final stats = statsSnapshot.data!;
            final String name = stats['name'] ?? 'Студент';
            final int points = stats['points'] ?? 0;
            final int level = stats['level'] ?? 1;
            final int currentStreak = stats['currentStreak'] ?? 0;
            final int completedCount =
                (stats['completed'] as List<dynamic>? ?? []).length;

            return StreamBuilder<List<Course>>(
              stream: _db.getCourses(),
              builder: (context, coursesSnapshot) {
                final courses = coursesSnapshot.data ?? [];

                return ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildGreetingCard(
                      name: name,
                      currentStreak: currentStreak,
                    ),
                    SizedBox(height: 16),
                    _buildStatsRow(
                      points: points,
                      level: level,
                      completedCount: completedCount,
                    ),
                    SizedBox(height: 20),
                    _buildSectionTitle('План на сегодня'),
                    SizedBox(height: 10),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _planFuture,
                      builder: (context, planSnapshot) {
                        if (planSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Column(
                            children: [
                              _loadingPlanCard('Подбираем новый урок...'),
                              SizedBox(height: 12),
                              _loadingPlanCard('Подбираем повторение...'),
                            ],
                          );
                        }

                        if (planSnapshot.hasError || !planSnapshot.hasData) {
                          return Container(
                            padding: EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Не удалось загрузить план на сегодня. Курсы ниже доступны.',
                            ),
                          );
                        }

                        final plan = planSnapshot.data!;
                        final Lesson? newLesson = plan['newLesson'] as Lesson?;
                        final Course? newCourse = plan['newCourse'] as Course?;
                        final Lesson? reviewLesson =
                            plan['reviewLesson'] as Lesson?;
                        final Course? reviewCourse =
                            plan['reviewCourse'] as Course?;
                        final String reviewStatusText =
                            plan['reviewStatusText'] ?? 'Повторение недоступно';

                        return Column(
                          children: [
                            _buildDailyPlanCard(
                              icon: Icons.auto_stories,
                              color: Colors.deepPurple,
                              title: newLesson != null
                                  ? 'Новый урок'
                                  : 'Новых уроков пока нет',
                              subtitle: newLesson != null
                                  ? '${newLesson.title}\nКурс: ${newCourse?.title ?? ""}'
                                  : 'Вы уже прошли все доступные новые уроки.',
                              statusText: newLesson != null
                                  ? 'Рекомендуем для текущей сессии'
                                  : 'Можно перейти к повторению',
                              buttonText: newLesson != null ? 'Начать' : null,
                              onPressed: newLesson != null
                                  ? () => _openLesson(newLesson)
                                  : null,
                            ),
                            SizedBox(height: 12),
                            _buildDailyPlanCard(
                              icon: Icons.refresh,
                              color: Colors.orange,
                              title: reviewLesson != null
                                  ? 'Повторение'
                                  : 'Повторение пока недоступно',
                              subtitle: reviewLesson != null
                                  ? '${reviewLesson.title}\nКурс: ${reviewCourse?.title ?? ""}'
                                  : 'Система повторения предлагает уроки позже, а не сразу после прохождения.',
                              statusText: reviewStatusText,
                              buttonText: reviewLesson != null
                                  ? 'Повторить'
                                  : null,
                              onPressed: reviewLesson != null
                                  ? () => _openLesson(reviewLesson)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    _buildSectionTitle('Все курсы'),
                    SizedBox(height: 10),
                    if (coursesSnapshot.connectionState ==
                        ConnectionState.waiting)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (courses.isEmpty)
                      _buildEmptyCoursesCard()
                    else
                      ...courses.map((course) => _buildCourseCard(course)),
                    SizedBox(height: 12),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _loadingPlanCard(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 14),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildGreetingCard({
    required String name,
    required int currentStreak,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Привет, $name!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Сегодня твой план микрообучения уже готов.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Text(
                  'Текущий стрик: $currentStreak',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int points,
    required int level,
    required int completedCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            title: 'Баллы',
            value: points.toString(),
            icon: Icons.stars_rounded,
            color: Colors.orange,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildMiniStatCard(
            title: 'Уровень',
            value: level.toString(),
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildMiniStatCard(
            title: 'Уроки',
            value: completedCount.toString(),
            icon: Icons.check_circle,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
      child: Column(
        children: [
          Icon(icon, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDailyPlanCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String statusText,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: color),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Text(subtitle, style: TextStyle(color: Colors.black87, height: 1.4)),
          if (buttonText != null && onPressed != null) ...[
            SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.10),
          child: Icon(Icons.menu_book, color: Colors.deepPurple),
        ),
        title: Text(
          course.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(course.category),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => LessonListScreen(course: course)),
          );
          await _refreshData();
        },
      ),
    );
  }

  Widget _buildEmptyCoursesCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 42, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'Курсы пока не найдены',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Добавьте курсы в Firestore, чтобы они появились на главном экране.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
