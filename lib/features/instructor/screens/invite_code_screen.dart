// Invite code screen — shows the instructor's unique invite code for students
// to link their accounts.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

/// Displays the instructor's unique invite code for students to link accounts.
class InviteCodeScreen extends ConsumerStatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  ConsumerState<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends ConsumerState<InviteCodeScreen> {
  bool _ensured = false;

  /// Ensure the invite_codes lookup document exists so students can link.
  /// This self-repairs if the instructor was created before the lookup
  /// collection was introduced.
  Future<void> _ensureInviteCodeDoc(String uid, String code) async {
    if (_ensured || code.isEmpty || code == '------') return;
    _ensured = true;
    final docRef =
        FirebaseFirestore.instance.collection('invite_codes').doc(code);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({'instructor_id': uid});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final userAsync = ref.watch(appUserProvider);
    final user = userAsync.valueOrNull;
    final inviteCode = user?.inviteCode ?? '------';

    // Self-repair: ensure invite_codes collection has this code
    if (user != null && user.inviteCode != null && user.uid.isNotEmpty) {
      _ensureInviteCodeDoc(user.uid, user.inviteCode!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invite Code'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Share this code with your students',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Students can enter this code in their Settings to link their account to yours.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // ── Code display ──────────────────────────────────────────
              GestureDetector(
                onTap: () => _copyCode(context, inviteCode),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inviteCode,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.copy_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to copy',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              // ── Copy button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copyCode(context, inviteCode),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Invite Code'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code copied to clipboard!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
