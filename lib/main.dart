import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MicroMentorApp());
}

class MicroMentorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) {
          return AuthScreen();
        }

        return EmailVerificationGate();
      },
    );
  }
}

class EmailVerificationGate extends StatefulWidget {
  @override
  State<EmailVerificationGate> createState() => _EmailVerificationGateState();
}

class _EmailVerificationGateState extends State<EmailVerificationGate>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  bool isLoading = true;
  bool isVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVerification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerification();
    }
  }

  Future<void> _checkVerification() async {
    try {
      final verified = await _authService.reloadAndCheckEmailVerified();

      if (verified) {
        await _db.ensureUserDocument();
        await _db.syncEmailVerification();
      }

      if (!mounted) return;

      setState(() {
        isVerified = verified;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isVerified = false;
        isLoading = false;
      });
    }
  }

  Future<void> _resendEmail() async {
    try {
      await _authService.sendVerificationEmail();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Письмо отправлено повторно')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось отправить письмо')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isVerified) {
      return MainNavigation();
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Подтверждение email'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 84,
                  color: Colors.deepPurple,
                ),
                SizedBox(height: 20),
                Text(
                  'Подтвердите почту',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Мы отправили письмо на:\n$email\n\nПерейдите по ссылке в письме, затем вернитесь в приложение и нажмите кнопку ниже.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black87),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checkVerification,
                    icon: Icon(Icons.verified),
                    label: Text('Я подтвердил почту'),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resendEmail,
                    icon: Icon(Icons.send),
                    label: Text('Отправить письмо повторно'),
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () => _authService.signOut(),
                  child: Text('Выйти из аккаунта'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [HomeScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Обучение"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Профиль"),
        ],
      ),
    );
  }
}
