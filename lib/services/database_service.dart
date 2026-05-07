import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../config/secrets.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String _masterKey = AppSecrets.jsonBinMasterKey;

  String? get _currentUserId => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<List<Course>> getCourses() {
    return _db
        .collection('courses')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Course.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<Course>> getCoursesOnce() async {
    final snap = await _db.collection('courses').get();
    return snap.docs
        .map((doc) => Course.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<List<Lesson>> getLessonsFromApi(String binUrl) async {
    try {
      final response = await http
          .get(
            Uri.parse(binUrl),
            headers: {'X-Master-Key': _masterKey, 'X-Bin-Meta': 'false'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is List) {
          return decoded
              .map((item) => Lesson.fromJson(item as Map<String, dynamic>))
              .toList();
        }

        print('JSONBin вернул не массив: $binUrl');
      } else {
        print('Ошибка JSONBin ${response.statusCode}: $binUrl');
      }
    } on TimeoutException {
      print('Таймаут JSONBin: $binUrl');
    } catch (e) {
      print('Ошибка getLessonsFromApi: $e');
    }

    return [];
  }

  Future<void> ensureUserDocument() async {
    final uid = _currentUserId;
    final user = _auth.currentUser;

    if (uid == null || user == null) return;

    try {
      final docRef = _userDoc(uid);
      final doc = await docRef.get();

      final defaultName = user.email?.split('@').first ?? 'Студент';

      if (!doc.exists) {
        await docRef.set({
          'email': user.email,
          'name': defaultName,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': user.emailVerified,
          'verifiedAt': user.emailVerified
              ? FieldValue.serverTimestamp()
              : null,
          'points': 0,
          'level': 1,
          'currentStreak': 0,
          'bestStreak': 0,
          'lastStudyDate': null,
          'completedLessons': [],
          'achievements': [],
          'lessonCompletionDates': {},
        });
        print('USER DOC CREATED: $uid');
      }
    } on FirebaseException catch (e) {
      print('ENSURE USER DOC ERROR: ${e.code} ${e.message}');
    } catch (e) {
      print('ENSURE USER DOC UNKNOWN ERROR: $e');
    }
  }

  Future<void> syncEmailVerification() async {
    final user = _auth.currentUser;
    final uid = _currentUserId;

    if (user == null || uid == null) return;

    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      final isVerified = refreshedUser?.emailVerified ?? false;

      await _userDoc(uid).set({
        'isVerified': isVerified,
        'verifiedAt': isVerified ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));
    } catch (e) {
      print('SYNC EMAIL ERROR: $e');
    }
  }

  Future<void> updateUserName(String newName) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _userDoc(uid).set({'name': newName.trim()}, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final uid = _currentUserId;
    final user = _auth.currentUser;

    if (uid == null || user == null) {
      return {
        'name': 'Гость',
        'points': 0,
        'completed': <String>[],
        'currentStreak': 0,
        'bestStreak': 0,
        'level': 1,
        'achievements': <String>[],
      };
    }

    try {
      final doc = await _userDoc(uid).get();
      final data = doc.data() ?? {};

      return {
        'name': data['name'] ?? (user.email?.split('@').first ?? 'Студент'),
        'points': data['points'] ?? 0,
        'completed': List<String>.from(data['completedLessons'] ?? []),
        'currentStreak': data['currentStreak'] ?? 0,
        'bestStreak': data['bestStreak'] ?? 0,
        'level': data['level'] ?? 1,
        'achievements': List<String>.from(data['achievements'] ?? []),
      };
    } catch (e) {
      print('Ошибка getUserStats: $e');
      return {
        'name': user.email?.split('@').first ?? 'Студент',
        'points': 0,
        'completed': <String>[],
        'currentStreak': 0,
        'bestStreak': 0,
        'level': 1,
        'achievements': <String>[],
      };
    }
  }

  Future<List<String>> getCompletedIds() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final doc = await _userDoc(uid).get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['completedLessons'] ?? []);
      }
    } catch (e) {
      print('Ошибка getCompletedIds: $e');
    }

    return [];
  }

  Future<Map<String, DateTime>> getLessonCompletionDates() async {
    final uid = _currentUserId;
    if (uid == null) return {};

    try {
      final doc = await _userDoc(uid).get();
      final data = doc.data() ?? {};
      final rawMap = data['lessonCompletionDates'];

      if (rawMap is! Map) return {};

      final Map<String, DateTime> result = {};

      rawMap.forEach((key, value) {
        if (value is Timestamp) {
          final date = value.toDate();
          result[key.toString()] = DateTime(date.year, date.month, date.day);
        }
      });

      return result;
    } catch (e) {
      print('Ошибка getLessonCompletionDates: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getDailyPlan() async {
    try {
      final courses = await getCoursesOnce();
      final completedIds = await getCompletedIds();
      final completionDates = await getLessonCompletionDates();

      Course? newCourse;
      Lesson? newLesson;
      Course? reviewCourse;
      Lesson? reviewLesson;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final limitedCourses = courses.take(4).toList();

      for (final course in limitedCourses) {
        final lessons = await getLessonsFromApi(course.contentUrl);
        if (lessons.isEmpty) continue;

        for (final lesson in lessons) {
          if (newLesson == null && !completedIds.contains(lesson.id)) {
            newLesson = lesson;
            newCourse = course;
          }

          if (reviewLesson == null && completedIds.contains(lesson.id)) {
            final completionDate = completionDates[lesson.id];
            if (completionDate != null &&
                today.difference(completionDate).inDays >= 1) {
              reviewLesson = lesson;
              reviewCourse = course;
            }
          }

          if (newLesson != null && reviewLesson != null) {
            break;
          }
        }

        if (newLesson != null && reviewLesson != null) {
          break;
        }
      }

      String reviewStatusText;
      if (reviewLesson != null) {
        reviewStatusText = 'Готово к повторению';
      } else if (completedIds.isNotEmpty) {
        reviewStatusText = 'Повторение станет доступно позже';
      } else {
        reviewStatusText = 'Сначала пройдите хотя бы один урок';
      }

      return {
        'newCourse': newCourse,
        'newLesson': newLesson,
        'reviewCourse': reviewCourse,
        'reviewLesson': reviewLesson,
        'reviewStatusText': reviewStatusText,
      };
    } catch (e) {
      print('Ошибка getDailyPlan: $e');
      return {
        'newCourse': null,
        'newLesson': null,
        'reviewCourse': null,
        'reviewLesson': null,
        'reviewStatusText': 'Не удалось сформировать план',
      };
    }
  }

  Future<void> saveProgress(String lessonId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final userRef = _userDoc(uid);
    final snapshot = await userRef.get();
    final data = snapshot.data() ?? {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? lastStudyDate;
    if (data['lastStudyDate'] != null && data['lastStudyDate'] is Timestamp) {
      final parsed = (data['lastStudyDate'] as Timestamp).toDate();
      lastStudyDate = DateTime(parsed.year, parsed.month, parsed.day);
    }

    int currentStreak = data['currentStreak'] ?? 0;
    int bestStreak = data['bestStreak'] ?? 0;
    int points = data['points'] ?? 0;
    int level = data['level'] ?? 1;

    List<String> completedLessons = List<String>.from(
      data['completedLessons'] ?? [],
    );
    List<String> achievements = List<String>.from(data['achievements'] ?? []);

    final alreadyCompleted = completedLessons.contains(lessonId);

    if (!alreadyCompleted) {
      completedLessons.add(lessonId);
      points += 10;
      level = (points ~/ 100) + 1;
    }

    if (lastStudyDate == null) {
      currentStreak = 1;
    } else {
      final diff = today.difference(lastStudyDate).inDays;
      if (diff == 1) {
        currentStreak += 1;
      } else if (diff > 1) {
        currentStreak = 1;
      }
    }

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    if (completedLessons.length >= 1 &&
        !achievements.contains('first_lesson')) {
      achievements.add('first_lesson');
    }
    if (completedLessons.length >= 5 &&
        !achievements.contains('five_lessons')) {
      achievements.add('five_lessons');
    }
    if (currentStreak >= 3 && !achievements.contains('streak_3')) {
      achievements.add('streak_3');
    }
    if (points >= 100 && !achievements.contains('points_100')) {
      achievements.add('points_100');
    }

    await userRef.set({
      'completedLessons': completedLessons,
      'points': points,
      'level': level,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastStudyDate': Timestamp.fromDate(today),
      'achievements': achievements,
      'lessonCompletionDates.$lessonId': Timestamp.fromDate(today),
    }, SetOptions(merge: true));
  }
}
