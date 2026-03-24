// Link instructor screen — allows a student to enter an instructor's invite
// code to establish a link.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import '../providers/instructor_provider.dart';

/// Allows a student to enter an instructor's invite code to establish a link.
class LinkInstructorScreen extends ConsumerStatefulWidget {
  const LinkInstructorScreen({super.key});

  @override
  ConsumerState<LinkInstructorScreen> createState() =>
      _LinkInstructorScreenState();
}

class _LinkInstructorScreenState extends ConsumerState<LinkInstructorScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  /// Client-side rate limit to prevent invite code brute-forcing.
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    // Rate limit: block attempts during lockout period.
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inMinutes + 1;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Please wait $remaining minute${remaining == 1 ? '' : 's'} and try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-character invite code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _loading = true);

    final error = await linkStudentToInstructor(code, uid);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      // Track failed attempts for rate limiting.
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
        _failedAttempts = 0;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      _failedAttempts = 0; // Reset on success.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully linked to your instructor!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkAsync = ref.watch(studentInstructorLinkProvider);

    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Link Instructor'),
        
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Show current link status
              linkAsync.when(
                data: (link) {
                  if (link != null) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Currently linked',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Linked since ${_formatDate(link.linkedAt)}',
                                  style:  TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _confirmUnlink(link.studentId),
                            child: const Text(
                              'Unlink',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
               Text(
                'Enter your instructor\'s invite code',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
               Text(
                'Ask your flight instructor for their 6-character invite code. '
                'This lets them view your progress and leave notes on exercises.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration:  InputDecoration(
                  hintText: 'INVITE CODE',
                  hintStyle: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 18,
                    letterSpacing: 4,
                  ),
                ),
                onFieldSubmitted: (_) => _link(),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _link,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Link Instructor'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUnlink(String studentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:  Text(
          'Unlink Instructor',
          style: TextStyle(color: AppColors.onSurface),
        ),
        content:  Text(
          'Your instructor will no longer be able to view your progress. '
          'You can link again later with a new code.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:  Text(
              'Cancel',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await unlinkStudent(studentId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Instructor unlinked.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text(
              'Unlink',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
