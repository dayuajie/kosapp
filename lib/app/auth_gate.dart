import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../presentation/pages/login_page.dart';
import '../presentation/pages/main_bottom_nav_shell.dart';
import '../presentation/pages/registration/registration_form_page.dart';


class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _user;
  bool _loading = true;

  StreamSubscription<AuthState>? _sub;



  @override
  void initState() {
    super.initState();

    // In widget tests, Supabase may not be initialized in main().
    // Supabase.instance will throw if not initialized, so we catch it.
    try {
      final client = Supabase.instance.client;
      _user = client.auth.currentUser;
      _sub = client.auth.onAuthStateChange.listen((event) {
        setState(() {
          _user = event.session?.user;
        });
      });
    } catch (_) {
      _user = null;
    } finally {
      _loading = false;
    }

  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return const LoginPage();
    }
    final kosId = _user?.userMetadata?['kos_id']?.toString();
    if (kosId == null || kosId.isEmpty) {
      return const RegistrationPage();
    }

    return const MainBottomNavShell();

  }
}

