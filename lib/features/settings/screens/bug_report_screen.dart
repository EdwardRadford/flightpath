import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/log_buffer_service.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _controller = TextEditingController();
  bool _includeDeviceInfo = true;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final info = await PackageInfo.fromPlatform();

      final data = <String, dynamic>{
        'uid': uid,
        'description': InputSanitiser.sanitise(text, maxLength: 2000),
        'app_version': info.version,
        'created_at': FieldValue.serverTimestamp(),
      };

      if (_includeDeviceInfo) {
        data['platform'] = Platform.operatingSystem;
        data['recent_logs'] = LogBufferService.recentLogs.join('\n');
      }

      await FirebaseFirestore.instance.collection('bug_reports').add(data);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report a problem')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Thanks — your report has been sent. We\'ll usually reply within 48 hours.',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What went wrong?',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 2000,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Describe what happened...',
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outline),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _includeDeviceInfo,
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _includeDeviceInfo = v ?? true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Include device info',
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Send bug report',
              button: true,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
