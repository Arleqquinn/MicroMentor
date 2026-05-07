import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _nameController = TextEditingController();

  String name = "Студент";
  int points = 0;
  int completedCount = 0;
  int currentStreak = 0;
  int bestStreak = 0;
  int level = 1;
  List<String> achievements = [];
  bool isEmailVerified = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      await _db.ensureUserDocument();
      await _db.syncEmailVerification();

      final user = FirebaseAuth.instance.currentUser;
      final stats = await _db.getUserStats();

      if (!mounted) return;

      setState(() {
        name = stats['name'] ?? 'Студент';
        points = stats['points'] ?? 0;
        completedCount = (stats['completed'] as List?)?.length ?? 0;
        currentStreak = stats['currentStreak'] ?? 0;
        bestStreak = stats['bestStreak'] ?? 0;
        level = stats['level'] ?? 1;
        achievements = List<String>.from(stats['achievements'] ?? []);
        isEmailVerified = user?.emailVerified ?? false;
        _nameController.text = name;
        isLoading = false;
      });
    } catch (e) {
      print("Ошибка профиля: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkVerificationNow() async {
    try {
      await _db.syncEmailVerification();
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();

      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;

      if (!mounted) return;

      setState(() {
        isEmailVerified = verified;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Почта подтверждена'
                : 'Почта пока не подтверждена. Проверьте письмо и нажмите ещё раз.',
          ),
        ),
      );

      await _loadUserStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить статус подтверждения')),
      );
    }
  }

  Future<void> _resendVerification() async {
    try {
      await AuthService().sendVerificationEmail();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Письмо отправлено повторно')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить письмо повторно')),
      );
    }
  }

  void _showEditNameDialog() {
    _nameController.text = name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Изменить имя"),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: "Введите имя",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(context);
              await _db.updateUserName(newName);
              await _loadUserStats();
            },
            child: Text("Сохранить"),
          ),
        ],
      ),
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

  String _achievementSubtitle(String id) {
    switch (id) {
      case 'first_lesson':
        return 'Пройден первый урок';
      case 'five_lessons':
        return 'Вы завершили 5 уроков';
      case 'streak_3':
        return 'Серия занятий 3 дня подряд';
      case 'points_100':
        return 'Набрано 100 баллов';
      default:
        return 'Достижение открыто';
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

  Color _achievementColor(String id) {
    switch (id) {
      case 'first_lesson':
        return Colors.blue;
      case 'five_lessons':
        return Colors.deepPurple;
      case 'streak_3':
        return Colors.redAccent;
      case 'points_100':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Профиль"), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadUserStats,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              if (!isEmailVerified && !isLoading) _buildEmailAlert(),
              SizedBox(height: 24),
              _buildHeader(userEmail),
              SizedBox(height: 24),
              _buildStatsGrid(),
              SizedBox(height: 24),
              _buildAchievementsSection(),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.sync),
                title: Text("Синхронизировать данные"),
                onTap: _loadUserStats,
              ),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text("Выйти", style: TextStyle(color: Colors.red)),
                onTap: () => AuthService().signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailAlert() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Почта не подтверждена. Подтвердите email, чтобы использовать аккаунт без ограничений.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _resendVerification,
                child: Text("Отправить ссылку повторно"),
              ),
              TextButton(
                onPressed: _checkVerificationNow,
                child: Text("Я подтвердил почту"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String email) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showEditNameDialog,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.deepPurple.shade50,
                child: Icon(Icons.person, size: 50, color: Colors.deepPurple),
              ),
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.edit, size: 15, color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        Text(
          isLoading ? "Загрузка..." : name,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(email, style: TextStyle(color: Colors.grey)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEmailVerified
                  ? Icons.verified
                  : Icons.mark_email_unread_outlined,
              color: isEmailVerified ? Colors.green : Colors.orange,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              isEmailVerified ? "Почта подтверждена" : "Почта не подтверждена",
              style: TextStyle(
                color: isEmailVerified ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _statItem("Баллы", points.toString(), Colors.orange),
          _statItem("Уроки", completedCount.toString(), Colors.blue),
          _statItem("Стрик", currentStreak.toString(), Colors.redAccent),
          _statItem("Лучший стрик", bestStreak.toString(), Colors.purple),
          _statItem("Уровень", level.toString(), Colors.green),
          _statItem("Ачивки", achievements.length.toString(), Colors.teal),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Достижения',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 14),
            if (achievements.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'У вас пока нет достижений. Пройдите первый урок, чтобы открыть награду.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...achievements.map((achievementId) {
                final color = _achievementColor(achievementId);

                return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.16),
                        child: Icon(
                          _achievementIcon(achievementId),
                          color: color,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _achievementTitle(achievementId),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 3),
                            Text(
                              _achievementSubtitle(achievementId),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
