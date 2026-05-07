import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<String?> signUp(String email, String password) async {
    try {
      final cleanedEmail = email.trim();
      final cleanedPassword = password.trim();

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: cleanedPassword,
      );

      final user = result.user;
      if (user == null) {
        return 'Не удалось создать пользователя';
      }

      final defaultName = cleanedEmail.split('@').first;

      await user.sendEmailVerification();

      await user.getIdToken(true);

      try {
        await _db.collection('users').doc(user.uid).set({
          'email': cleanedEmail,
          'name': defaultName,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
          'verifiedAt': null,
          'points': 0,
          'level': 1,
          'currentStreak': 0,
          'bestStreak': 0,
          'lastStudyDate': null,
          'completedLessons': [],
          'achievements': [],
        }, SetOptions(merge: true));

        print('USER DOC CREATED: ${user.uid}');
      } on FirebaseException catch (e) {
        print('FIRESTORE CREATE USER ERROR: ${e.code} ${e.message}');
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('SIGN UP AUTH ERROR: ${e.code} ${e.message}');
      return e.message ?? 'Ошибка регистрации';
    } catch (e) {
      print('SIGN UP UNKNOWN ERROR: $e');
      return e.toString();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final cleanedEmail = email.trim();
      final cleanedPassword = password.trim();

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: cleanedEmail,
        password: cleanedPassword,
      );

      await result.user?.reload();
      return null;
    } on FirebaseAuthException catch (e) {
      print('SIGN IN AUTH ERROR: ${e.code} ${e.message}');
      return e.message ?? 'Ошибка входа';
    } catch (e) {
      print('SIGN IN UNKNOWN ERROR: $e');
      return e.toString();
    }
  }

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    await _auth.currentUser?.reload();
    final refreshedUser = _auth.currentUser;
    return refreshedUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
