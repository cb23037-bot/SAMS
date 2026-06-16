import 'package:flutter/material.dart';

import '../app/app_controller.dart';

// Calls getRestrictionStatus() to check whether the current student has an
// active financial restriction. If restricted, shows a blocking AlertDialog
// with a "Pay Now" button (calls [onPayNow] if provided) and returns true so
// the caller knows to abort the attempted action (e.g. course registration).
// Returns false if the student is not restricted, or if the API call fails
// (fail-open: do not block the student due to a network error).
Future<bool> checkAndShowRestriction({
  required BuildContext context,
  required AppController controller,
  // Optional: navigate to fees on "Pay Now"
  VoidCallback? onPayNow,
}) async {
  try {
    final status = await controller.apiService.getRestrictionStatus(
      token: controller.token!,
    );
    if (status['restricted'] != true) return false;
    if (!context.mounted) return true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_outline, color: Color(0xFFD32F2F), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Access Restricted',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Your academic access has been restricted due to unpaid tuition fees. '
          'Please make payment to restore access.',
          style: TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E5BFF)),
            onPressed: () {
              Navigator.of(context).pop();
              onPayNow?.call();
            },
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
