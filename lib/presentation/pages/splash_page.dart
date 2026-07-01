import 'dart:math';
import 'package:flutter/material.dart';
import 'main_bottom_nav_shell.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeSubtitle;
  late final Animation<double> _scaleLogo;
  late final Animation<double> _rotateLogo;

  @override
  void initState() {
    super.initState();

    final isInTest = const bool.fromEnvironment('FLUTTER_TEST');
    if (isInTest) return;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Animasi Scale masuk untuk Text Logo Box
    _scaleLogo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack),
    );

    // Animasi Rotasi halus (hanya berputar sedikit/sedang, tidak full 360 derajat agar text tetap terbaca)
    _rotateLogo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.80, curve: Curves.easeOut),
    );

    // Animasi Fade-In untuk teks deskripsi di bawahnya
    _fadeSubtitle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainBottomNavShell()),
        );
      });
    });
  }

  @override
  void dispose() {
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6D5EF6);
    const bgGradientEnd = Color(0xFF1FB6FF);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F8FC), bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ===== TEXT LOGO UTAMA DENGAN ANIMASI =====
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleLogo.value,
                      child: Transform.rotate(
                        // Berputar sejauh 0.15 putaran (~54 derajat) lalu kembali tegak lurus sesuai kurva animasi
                        angle: (1 - _rotateLogo.value) * 0.15 * pi,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 12),
                          color: primaryColor.withOpacity(0.15),
                        ),
                      ],
                    ),
                    child: const Text(
                      'KOSKITA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // ===== SUBTITLE DENGAN ANIMASI FADE =====
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeSubtitle.value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - _fadeSubtitle.value) * 8),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Manajemen Kos',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.55),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Indikator loading dots di bagian bawah
                const _ProgressDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== WIDGET DOTS LOADING PROGRESS (TETAP DIBAWAKAN DARI KODE LAMA) =====
class _ProgressDots extends StatefulWidget {
  const _ProgressDots();

  @override
  State<_ProgressDots> createState() => _ProgressDotsState();
}

class _ProgressDotsState extends State<_ProgressDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.black.withOpacity(0.12);
    const active = Color(0xFF6D5EF6);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final a0 = (1 - (t - 0.0).abs()).clamp(0.0, 1.0);
        final a1 = (1 - (t - 0.5).abs()).clamp(0.0, 1.0);
        final a2 = (1 - (t - 1.0).abs()).clamp(0.0, 1.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Dot(progress: a0, active: active, base: base),
            const SizedBox(width: 10),
            _Dot(progress: a1, active: active, base: base),
            const SizedBox(width: 10),
            _Dot(progress: a2, active: active, base: base),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final double progress;
  final Color active;
  final Color base;

  const _Dot({required this.progress, required this.active, required this.base});

  @override
  Widget build(BuildContext context) {
    final opacity = 0.2 + 0.8 * progress;
    final scale = 0.7 + 0.6 * progress;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: active.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}