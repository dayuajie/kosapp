import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
// Color tokens
// ─────────────────────────────────────────────
const _bg        = Color(0xFF0D0F1A);
const _primary   = Color(0xFF7C5CFC);
const _accent    = Color(0xFFB8ADFF);
const _surface   = Color(0xFF181B2E);
const _textPrimary   = Color(0xFFF5F4FF);
const _textSecondary = Color(0xFF8A8FBE);
const _errorColor    = Color(0xFFFF6B6B);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();

  bool _isSignUp = false;

  bool _obscurePassword = true;
  bool _submitting      = false;
  String? _error;


  // Animation controllers
  late final AnimationController _orb1Ctrl;
  late final AnimationController _orb2Ctrl;
  late final AnimationController _orb3Ctrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _orb1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _orb2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);

    _orb3Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _orb3Ctrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Email wajib diisi.');
      setState(() => _submitting = false);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Password wajib diisi.');
      setState(() => _submitting = false);
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Phone wajib diisi.');
      setState(() => _submitting = false);
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Nama wajib diisi.');
      setState(() => _submitting = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
        },
      );

      if (response.user == null) {
    setState(() => _error = 'Sign up gagal: user tidak ditemukan.');
    return;
  }

      // Setelah sign up berhasil, AuthGate akan mengarah sesuai status auth.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signIn() async {

    setState(() { _submitting = true; _error = null; });

    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (response.user == null) {
        setState(() => _error = 'Login gagal: akun tidak ditemukan.');
        return;
      }
      // AuthGate handles redirect
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Animated background orbs ──
          _AnimatedOrb(
            controller: _orb1Ctrl,
            color: _primary.withOpacity(0.35),
            size: 320,
            startOffset: const Offset(-80, -60),
            endOffset: const Offset(40, 80),
          ),
          _AnimatedOrb(
            controller: _orb2Ctrl,
            color: const Color(0xFF1FB6FF).withOpacity(0.20),
            size: 280,
            startOffset: const Offset(200, 500),
            endOffset: const Offset(280, 380),
          ),
          _AnimatedOrb(
            controller: _orb3Ctrl,
            color: _accent.withOpacity(0.18),
            size: 200,
            startOffset: const Offset(280, 80),
            endOffset: const Offset(200, 200),
          ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── Logo / Icon mark ──
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_primary, Color(0xFF1FB6FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(0.5),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Headline ──
                        Text(
                          _isSignUp ? 'Buat akun baru\nkembali' : 'Selamat datang\nkembali',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Masuk untuk melanjutkan sesi Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ── Glass card ──
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                              // Name (Sign up only)
                              if (_isSignUp) ...[
                                _FieldLabel(label: 'Name'),
                                const SizedBox(height: 8),
                                _StyledField(
                                  controller: _nameController,
                                  hint: 'Nama lengkap',
                                  keyboardType: TextInputType.name,
                                  prefixIcon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 20),
                              
                              _FieldLabel(label: 'Phone'),
                              const SizedBox(height: 8),
                              _StyledField(
                                controller: _phoneController,
                                hint: '08xxxxxxxxxx',
                                keyboardType: TextInputType.phone,
                                prefixIcon: Icons.phone_outlined,
                              ),
                              ],
                              const SizedBox(height: 20),

                              // Email
                              _FieldLabel(label: 'Email'),
                              const SizedBox(height: 8),
                              _StyledField(
                                controller: _emailController,
                                hint: 'nama@email.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline_rounded,
                              ),
                              const SizedBox(height: 20),

                              // Password
                              _FieldLabel(label: 'Password'),
                              const SizedBox(height: 8),
                              _StyledField(
                                controller: _passwordController,
                                hint: '••••••••',
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Lupa password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Error message
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                child: _error != null
                                    ? Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _errorColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                              color: _errorColor.withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                color: _errorColor, size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _error!,
                                                style: const TextStyle(
                                                  color: _errorColor,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                        // Sign-in button
                              _GradientButton(
                                label: _isSignUp ? 'Daftar' : 'Masuk',
                                loading: _submitting,
                                onPressed: _submitting
                                    ? null
                                    : _isSignUp
                                        ? _signUp
                                        : _signIn,
                              ),
                              const SizedBox(height: 16),
                              Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignUp ? 'Sudah punya akun?' : 'Belum punya akun?',
                                style: const TextStyle(color: _textSecondary, fontSize: 12),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null; // Bersihkan error saat pindah mode
                                  });
                                },
                                child: Text(
                                  _isSignUp ? 'Masuk di sini' : 'Daftar sekarang',
                                  style: const TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Footer hint
                        const Text(
                          'Pastikan Email/Password auth di Supabase sudah diaktifkan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

/// Floating color orb that drifts between two offsets.
class _AnimatedOrb extends StatelessWidget {
  const _AnimatedOrb({
    required this.controller,
    required this.color,
    required this.size,
    required this.startOffset,
    required this.endOffset,
  });

  final AnimationController controller;
  final Color color;
  final double size;
  final Offset startOffset;
  final Offset endOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(controller.value);
        final dx = lerpDouble(startOffset.dx, endOffset.dx, t)!;
        final dy = lerpDouble(startOffset.dy, endOffset.dy, t)!;
        return Positioned(
          left: dx,
          top: dy,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Glassmorphism-style card.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: _primary.withOpacity(0.10),
            blurRadius: 60,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small label above each field.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Styled text field with dark theme.
class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      cursorColor: _primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: _textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.10), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Gradient button with loading state.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFF1FB6FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: onPressed == null ? _textSecondary.withOpacity(0.3) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: _primary.withOpacity(0.40),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}