// Instructor login screen — branded entry point for flight instructors.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/auth/services/auth_service.dart';

/// Branded login screen for flight instructors with email/password and Google
/// Sign-In. After successful authentication the user's Firestore role is set
/// to 'instructor'.
class InstructorLoginScreen extends ConsumerStatefulWidget {
  const InstructorLoginScreen({super.key});

  @override
  ConsumerState<InstructorLoginScreen> createState() =>
      _InstructorLoginScreenState();
}

class _InstructorLoginScreenState extends ConsumerState<InstructorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// After a successful sign-in, ensure the Firestore user document has
  /// `user_role` set to 'instructor'. For brand-new users (Google sign-in
  /// creates the doc automatically) the router will send them to
  /// profile-setup where the instructor toggle will be pre-set.
  Future<void> _ensureInstructorRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      // Existing user — flip role to instructor if not already.
      if (doc.data()?['user_role'] != 'instructor') {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'user_role': 'instructor',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
    // If the doc doesn't exist yet the user will land on profile-setup.
    // We pass extra={'instructor': true} via the router so the toggle is
    // pre-set (handled below in navigation).
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // Flag for profile-setup to pre-toggle instructor switch (new users).
    ref.read(pendingInstructorSignupProvider.notifier).state = true;
    try {
      await ref.read(authServiceProvider).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      await _ensureInstructorRole();
      FirebaseAnalytics.instance.logEvent(name: 'login_instructor');
      // Router handles navigation automatically
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    // Flag for profile-setup to pre-toggle instructor switch (new users).
    ref.read(pendingInstructorSignupProvider.notifier).state = true;
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      await _ensureInstructorRole();
      FirebaseAnalytics.instance.logEvent(name: 'login_instructor_google');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } catch (e) {
      final msg = e.toString();
      final isCancelled = msg.contains('sign_in_canceled') ||
          (msg.contains('sign_in_failed') && msg.contains('12501'));
      if (mounted && !isCancelled) {
        _showError('Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                _InstructorLogo(),
                const SizedBox(height: 40),
                Text(
                  'Welcome, Instructor',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your students and track their progress through the PPL syllabus.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    return emailRegex.hasMatch(v.trim())
                        ? null
                        : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/password-reset'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 24),
                _OrDivider(),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: const _GoogleIcon(),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push('/signup', extra: {'instructor': true}),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    "I'm a student",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private widgets (match login_screen.dart patterns) ──────────────────────

class _InstructorLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: AppColors.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Flight Path',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'for Instructors',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: Theme.of(context).textTheme.bodyMedium),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }
}

/// Paints the official Google multicolour "G" logo.
class _GoogleGPainter extends CustomPainter {
  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);
  static const Color _white = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final ri = r * 0.42;
    final strokeW = r - ri;

    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2);

    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    const d = 3.14159265358979 / 180.0;

    canvas.drawArc(rect, -150 * d, 210 * d, false, arc(_blue));
    canvas.drawArc(rect, -210 * d, 60 * d, false, arc(_red));
    canvas.drawArc(rect, 150 * d, 60 * d, false, arc(_yellow));
    canvas.drawArc(rect, 60 * d, 90 * d, false, arc(_green));

    final barTop = cy - strokeW * 0.55;
    final barBottom = cy + strokeW * 0.55;
    final barLeft = cx - strokeW * 0.05;
    final barRight = size.width;

    canvas.drawRect(
      Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
      Paint()..color = _white,
    );

    canvas.drawCircle(Offset(cx, cy), ri, Paint()..color = _white);

    final tongueRect =
        Rect.fromLTRB(cx, barTop, cx + ri + strokeW * 0.45, barBottom);
    canvas.drawRect(tongueRect, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}
