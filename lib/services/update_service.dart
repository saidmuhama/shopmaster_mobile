import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static bool _checking = false;

  /// Call once from HomeScreen after user is loaded.
  /// Fire-and-forget — never throws, never blocks the UI.
  static Future<void> checkUpdate(BuildContext context) async {
    if (_checking) return;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      // Use flexible update — downloads silently in the background.
      // The user can keep using the app and is prompted to restart when ready.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success) return;

      // When download completes, show a snackbar asking the user to restart.
      // We check mounted via the context; if the widget is gone we skip it.
      if (!context.mounted) {
        // Install immediately without user prompt (app not in foreground)
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Update downloaded — restart to apply'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'RESTART',
            onPressed: () => InAppUpdate.completeFlexibleUpdate(),
          ),
        ),
      );
    } catch (_) {
      // Silently swallow all errors — update checks must never crash the app.
      // Common non-error causes: debug build, sideloaded APK, no internet.
    } finally {
      _checking = false;
    }
  }
}
