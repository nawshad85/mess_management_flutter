import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mess_manager/app/theme/app_theme.dart';
import 'package:mess_manager/controllers/auth_controller.dart';
import 'package:mess_manager/models/available_app_update.dart';
import 'package:mess_manager/services/app_update_service.dart';

class AppUpdateController extends GetxController {
  AppUpdateController({AppUpdateService? service})
    : _service = service ?? AppUpdateService();

  final AppUpdateService _service;
  final RxDouble downloadProgress = (-1.0).obs;
  final RxString updateStatus = 'Preparing update…'.obs;

  Worker? _authReadyWorker;
  bool _checkScheduled = false;
  bool _checkedThisLaunch = false;

  @override
  void onInit() {
    super.onInit();
    final authController = Get.find<AuthController>();
    _authReadyWorker = ever<bool>(authController.hasResolvedInitialAuthState, (
      ready,
    ) {
      if (ready) _scheduleCheck();
    });

    if (authController.hasResolvedInitialAuthState.value) {
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAfterNavigationSettles());
    });
  }

  Future<void> _checkAfterNavigationSettles() async {
    // Authentication may replace the splash route in the same frame.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;

    try {
      final update = await _service.checkForUpdate();
      if (update != null) await _showUpdatePrompt(update);
    } catch (error) {
      // An unavailable update service must never block normal app startup.
      debugPrint('App update check was skipped: $error');
    }
  }

  Future<void> _showUpdatePrompt(AvailableAppUpdate update) async {
    final accepted = await Get.dialog<bool>(
      PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(
            Icons.system_update_rounded,
            color: AppTheme.primaryColor,
            size: 36,
          ),
          title: Text(update.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.message),
                const SizedBox(height: 14),
                Text(
                  _versionDescription(update),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  update.usesGooglePlay
                      ? 'Google Play will securely download and install the update.'
                      : 'The APK will download now. Android will then ask you to confirm installation.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Yes, update'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    if (accepted == true) await _startUpdate(update);
  }

  String _versionDescription(AvailableAppUpdate update) {
    final installed = '${update.installedVersion} (${update.installedBuild})';
    final available = update.availableVersion.isEmpty
        ? 'build ${update.availableBuild}'
        : '${update.availableVersion} (${update.availableBuild})';
    return 'Installed: $installed  •  Available: $available';
  }

  Future<void> _startUpdate(AvailableAppUpdate update) async {
    downloadProgress.value = -1;
    updateStatus.value = update.usesGooglePlay
        ? 'Connecting to Google Play…'
        : 'Preparing update download…';

    unawaited(
      Get.dialog<void>(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Updating MessHub'),
            content: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: downloadProgress.value < 0
                        ? null
                        : downloadProgress.value,
                  ),
                  const SizedBox(height: 16),
                  Text(updateStatus.value),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      ),
    );

    // Give the progress dialog a frame before a native installer takes focus.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final outcome = await _service.installUpdate(
        update,
        onProgress: (progress) {
          updateStatus.value = progress.message;
          downloadProgress.value = progress.fraction ?? -1;
        },
      );
      _closeProgressDialog();

      if (outcome == AppUpdateOutcome.cancelled) {
        _showMessage(
          'Update cancelled',
          'You can update the next time the app opens.',
        );
      } else if (outcome == AppUpdateOutcome.started && update.usesGooglePlay) {
        _showMessage('Update started', 'Google Play is handling the update.');
      }
    } on AppUpdateException catch (error) {
      _closeProgressDialog();
      _showMessage('Update failed', error.message, isError: true);
    } catch (error) {
      _closeProgressDialog();
      debugPrint('App update failed: $error');
      _showMessage(
        'Update failed',
        'The update could not be started. Please try again later.',
        isError: true,
      );
    }
  }

  void _closeProgressDialog() {
    if (Get.isDialogOpen ?? false) Get.back<void>();
  }

  void _showMessage(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      backgroundColor: (isError ? AppTheme.errorColor : AppTheme.successColor)
          .withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void onClose() {
    _authReadyWorker?.dispose();
    super.onClose();
  }
}
