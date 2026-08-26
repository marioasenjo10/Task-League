import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../l10n/app_localizations.dart';

/// Global navigator key so app-wide dialogs (e.g. the quota alert) can be shown
/// from anywhere — including from `catch` blocks that have no reliable
/// `BuildContext`. Wired into [GoRouter] via `navigatorKey`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Detects Firebase/Firestore errors that are caused by the **Spark (free)**
/// plan hitting its daily quota or a resource/rate limit. On the free plan a
/// project can be temporarily disabled once its quota is exhausted, and reads,
/// writes and auth calls then fail with `resource-exhausted` / `unavailable`.
bool isQuotaError(Object error) {
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'resource-exhausted' ||
        code == 'quota-exceeded' ||
        code == 'unavailable') {
      return true;
    }
    final msg = (error.message ?? '').toLowerCase();
    if (msg.contains('quota') ||
        msg.contains('resource_exhausted') ||
        msg.contains('resource exhausted')) {
      return true;
    }
  }

  final text = error.toString().toLowerCase();
  return text.contains('resource_exhausted') ||
      text.contains('resource-exhausted') ||
      text.contains('quota exceeded') ||
      text.contains('quota_exceeded');
}

bool _dialogVisible = false;

/// If [error] is a quota / resource-exhausted error, shows a single blocking
/// "contact your administrator" dialog and returns `true`. Otherwise returns
/// `false`, leaving the caller to handle the error normally.
///
/// Pass a [context] when you have one; otherwise the global [rootNavigatorKey]
/// is used so the alert also works from repositories and services.
bool handleQuotaError(Object error, {BuildContext? context}) {
  if (!isQuotaError(error)) return false;
  _showQuotaAlert(context);
  return true;
}

void _showQuotaAlert(BuildContext? context) {
  if (_dialogVisible) return;
  final ctx = context ?? rootNavigatorKey.currentContext;
  if (ctx == null) return;

  _dialogVisible = true;
  showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.cloud_off_rounded,
          color: Color(0xFFFFB74D), size: 40),
      title: Text(
        dialogCtx.tr('quotaAlertTitle'),
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Text(
        dialogCtx.tr('quotaAlertMessage'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(dialogCtx.tr('quotaAlertButton'),
                style: const TextStyle(
                    color: Color(0xFFFFB74D), fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  ).whenComplete(() => _dialogVisible = false);
}
