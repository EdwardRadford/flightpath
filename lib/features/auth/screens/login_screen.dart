// Login screen — email/password and Google Sign-In authentication.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

/// Email/password and Google Sign-In login form.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      FirebaseAnalytics.instance.logEvent(name: 'login');
      // Router handles navigation automatically
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      FirebaseAnalytics.instance.logEvent(name: 'login_google');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } catch (e) {
      // Surface unexpected errors (e.g. PlatformException from Google Sign-In plugin)
      // but silently ignore the user-cancelled case (no message from plugin).
      final msg = e.toString();
      final isCancelled = msg.contains('sign_in_canceled') ||
          msg.contains('sign_in_failed') && msg.contains('12501');
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
                _Logo(),
                const SizedBox(height: 40),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue your training',
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
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    return emailRegex.hasMatch(v.trim()) ? null : 'Enter a valid email';
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
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                    side: BorderSide(color: Theme.of(context).colorScheme.outline),
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
                      onPressed: () => context.push('/signup'),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Instructor Sign In'),
                          content: const Text(
                            'Flight instructors sign in using the same form above.\n\n'
                            'After signing in with your instructor account you\'ll be '
                            'automatically directed to your instructor dashboard.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.school_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    label: Text(
                      'Sign in as Instructor',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
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

class _Logo extends StatelessWidget {
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
            Icons.flight,
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

/// Paints the official Google multicolour "G" logo using the four brand
/// colours (blue #4285F4, red #EA4335, yellow #FBBC05, green #34A853).
///
/// The geometry follows Google's published brand guidelines:
///  - Full circle arc in blue (from ~12 o'clock, sweeping ~300°).
///  - Red arc (top-left, ~60°).
///  - Yellow arc (bottom-left, ~60°).
///  - Green arc (bottom, ~90°).
///  - A white horizontal bar cuts into the right side of the circle,
///    forming the characteristic open mouth of the "G".
class _GoogleGPainter extends CustomPainter {
  static const Color _blue   = Color(0xFF4285F4);
  static const Color _red    = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green  = Color(0xFF34A853);
  static const Color _white  = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;        // outer radius
    final ri = r * 0.42;              // inner (hole) radius
    final strokeW = r - ri;           // ring stroke width

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2);

    // Helper: arc paint
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Angles in radians.  Flutter's drawArc uses 0 = 3 o'clock, clockwise.
    // Google "G" colour segments (approximate, matching official guidelines):
    //   Blue:   from -210° to  60°  → start -210° sweep 270°
    //   Red:    from -210° to -150° → start -210° sweep  60°  (top-left)
    //   Yellow: from  150° to  210° → start  150° sweep  60°  (bottom-left)
    //   Green:  from   60° to  150° → start   60° sweep  90°  (bottom-right)
    //
    // Convert to radians (dart uses radians, 1° = π/180).
    const d = 3.14159265358979 / 180.0;

    // Draw blue arc (the dominant segment — top-right round to bottom-left).
    canvas.drawArc(rect, -150 * d, 210 * d, false, arc(_blue));

    // Draw red arc (upper-left).
    canvas.drawArc(rect, -210 * d, 60 * d, false, arc(_red));

    // Draw yellow arc (lower-left).
    canvas.drawArc(rect, 150 * d, 60 * d, false, arc(_yellow));

    // Draw green arc (bottom, connecting yellow to blue).
    canvas.drawArc(rect, 60 * d, 90 * d, false, arc(_green));

    // White horizontal bar — creates the open mouth of the "G".
    // Covers roughly the right half of the ring, from the 3 o'clock axis
    // upward by strokeW/2, extending from the centre to the outer edge.
    final barTop    = cy - strokeW * 0.55;
    final barBottom = cy + strokeW * 0.55;
    final barLeft   = cx - strokeW * 0.05;   // just left of centre
    final barRight  = size.width;             // to the right edge

    canvas.drawRect(
      Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
      Paint()..color = _white,
    );

    // Fill the inner circle white so the ring looks like a "G" on white bg.
    canvas.drawCircle(Offset(cx, cy), ri, Paint()..color = _white);

    // Blue fill on the right half of the inner arc — the horizontal tongue
    // of the "G".  This is the small filled bar inside the letter.
    final tongueRect = Rect.fromLTRB(cx, barTop, cx + ri + strokeW * 0.45, barBottom);
    canvas.drawRect(tongueRect, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GoogleGPainter oldDelegate) => false;
}
