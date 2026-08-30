import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:in_app_update/in_app_update.dart' as play;
import 'package:mess_manager/models/available_app_update.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AppUpdateProgressCallback = void Function(AppUpdateProgress progress);

class AppUpdateService {
  AppUpdateService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  static const _defaultTitle = 'Update available';
  static const _defaultMessage =
      'A newer version of MessHub is available. Would you like to update now?';

  static const Map<String, Object> _remoteDefaults = {
    'android_update_enabled': true,
    'android_latest_build': 0,
    'android_latest_version': '',
    'android_update_title': _defaultTitle,
    'android_update_message': _defaultMessage,
    'android_apk_url': '',
    'android_apk_sha256': '',
    'android_play_store_url': '',
  };

  final FirebaseRemoteConfig _remoteConfig;
  play.AppUpdateInfo? _playUpdateInfo;

  Future<AvailableAppUpdate?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final settings = await _loadRemoteSettings();
    if (!settings.enabled) return null;

    final installedFromPlay =
        packageInfo.installerStore == 'com.android.vending';
    final useGooglePlay = appFlavor == 'play' || installedFromPlay;

    if (useGooglePlay) {
      return _checkGooglePlay(
        packageInfo: packageInfo,
        installedBuild: installedBuild,
        settings: settings,
      );
    }

    if (settings.latestBuild <= installedBuild) return null;

    final apkUri = _validHttpsUri(settings.apkUrl);
    if (apkUri == null) {
      debugPrint(
        'App update is available, but android_apk_url is missing or is not HTTPS.',
      );
      return null;
    }

    final checksum = settings.apkSha256.toLowerCase();
    if (checksum.isNotEmpty && !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      debugPrint(
        'App update is available, but android_apk_sha256 is not a valid SHA-256 value.',
      );
      return null;
    }

    return AvailableAppUpdate(
      distribution: UpdateDistribution.direct,
      installedVersion: packageInfo.version,
      installedBuild: installedBuild,
      availableVersion: settings.latestVersion,
      availableBuild: settings.latestBuild,
      title: settings.title,
      message: settings.message,
      apkUri: apkUri,
      apkSha256: checksum.isEmpty ? null : checksum,
      storeUri: _playStoreUri(settings.playStoreUrl, packageInfo.packageName),
    );
  }

  Future<AppUpdateOutcome> installUpdate(
    AvailableAppUpdate update, {
    required AppUpdateProgressCallback onProgress,
  }) {
    if (update.usesGooglePlay) {
      return _installFromGooglePlay(update, onProgress);
    }
    return _installDirectApk(update, onProgress);
  }

  Future<_RemoteUpdateSettings> _loadRemoteSettings() async {
    await _remoteConfig.setDefaults(_remoteDefaults);
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // The controller calls this only once per process, so every cold app
        // launch gets a fresh update check while cached values remain a fallback.
        minimumFetchInterval: Duration.zero,
      ),
    );

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (error) {
      // Offline/throttled launches should keep using the last activated values.
      debugPrint(
        'Remote app-update configuration could not be refreshed: $error',
      );
    }

    final configuredTitle = _remoteConfig
        .getString('android_update_title')
        .trim();
    final configuredMessage = _remoteConfig
        .getString('android_update_message')
        .trim();

    return _RemoteUpdateSettings(
      enabled: _remoteConfig.getBool('android_update_enabled'),
      latestBuild: _remoteConfig.getInt('android_latest_build'),
      latestVersion: _remoteConfig.getString('android_latest_version').trim(),
      title: configuredTitle.isEmpty ? _defaultTitle : configuredTitle,
      message: configuredMessage.isEmpty ? _defaultMessage : configuredMessage,
      apkUrl: _remoteConfig.getString('android_apk_url').trim(),
      apkSha256: _remoteConfig.getString('android_apk_sha256').trim(),
      playStoreUrl: _remoteConfig.getString('android_play_store_url').trim(),
    );
  }

  Future<AvailableAppUpdate?> _checkGooglePlay({
    required PackageInfo packageInfo,
    required int installedBuild,
    required _RemoteUpdateSettings settings,
  }) async {
    try {
      final info = await play.InAppUpdate.checkForUpdate();
      final isAvailable =
          info.updateAvailability == play.UpdateAvailability.updateAvailable ||
          info.updateAvailability ==
              play.UpdateAvailability.developerTriggeredUpdateInProgress;
      if (!isAvailable) return null;

      _playUpdateInfo = info;
      return _buildPlayUpdate(
        packageInfo: packageInfo,
        installedBuild: installedBuild,
        availableBuild:
            info.availableVersionCode ??
            (settings.latestBuild > installedBuild
                ? settings.latestBuild
                : installedBuild + 1),
        settings: settings,
      );
    } catch (error) {
      debugPrint('Google Play update check was unavailable: $error');

      // This fallback makes a locally installed Play-flavor build testable and
      // still directs an outdated user to the store if Play Core cannot respond.
      if (settings.latestBuild > installedBuild) {
        return _buildPlayUpdate(
          packageInfo: packageInfo,
          installedBuild: installedBuild,
          availableBuild: settings.latestBuild,
          settings: settings,
        );
      }
      return null;
    }
  }

  AvailableAppUpdate _buildPlayUpdate({
    required PackageInfo packageInfo,
    required int installedBuild,
    required int availableBuild,
    required _RemoteUpdateSettings settings,
  }) {
    return AvailableAppUpdate(
      distribution: UpdateDistribution.play,
      installedVersion: packageInfo.version,
      installedBuild: installedBuild,
      availableVersion: settings.latestVersion,
      availableBuild: availableBuild,
      title: settings.title,
      message: settings.message,
      storeUri: _playStoreUri(settings.playStoreUrl, packageInfo.packageName),
    );
  }

  Future<AppUpdateOutcome> _installDirectApk(
    AvailableAppUpdate update,
    AppUpdateProgressCallback onProgress,
  ) async {
    final apkUri = update.apkUri;
    if (apkUri == null) {
      throw const AppUpdateException('The update download URL is missing.');
    }

    onProgress(
      const AppUpdateProgress(message: 'Preparing the update download…'),
    );

    final ota = OtaUpdate();
    final stream = ota.execute(
      apkUri.toString(),
      destinationFilename: 'messhub-${update.availableBuild}.apk',
      sha256checksum: update.apkSha256,
    );

    await for (final event in stream) {
      switch (event.status) {
        case OtaStatus.DOWNLOADING:
          final percent = double.tryParse(event.value ?? '');
          onProgress(
            AppUpdateProgress(
              message: percent == null
                  ? 'Downloading update…'
                  : 'Downloading update… ${percent.round()}%',
              fraction: percent == null
                  ? null
                  : (percent / 100).clamp(0, 1).toDouble(),
            ),
          );
          break;
        case OtaStatus.INSTALLING:
          onProgress(
            const AppUpdateProgress(
              message: 'Opening Android installer…',
              fraction: 1,
            ),
          );
          return AppUpdateOutcome.started;
        case OtaStatus.INSTALLATION_DONE:
          return AppUpdateOutcome.completed;
        case OtaStatus.CANCELED:
          return AppUpdateOutcome.cancelled;
        case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          throw const AppUpdateException(
            'Android blocked the installer. Allow “Install unknown apps” for MessHub, then try again.',
          );
        case OtaStatus.CHECKSUM_ERROR:
          throw const AppUpdateException(
            'The downloaded update failed its security check. Please try again later.',
          );
        case OtaStatus.DOWNLOAD_ERROR:
          throw AppUpdateException(
            event.value?.isNotEmpty == true
                ? 'The update could not be downloaded: ${event.value}'
                : 'The update could not be downloaded. Check your connection and try again.',
          );
        case OtaStatus.ALREADY_RUNNING_ERROR:
          throw const AppUpdateException(
            'Another update download is already running.',
          );
        case OtaStatus.INSTALLATION_ERROR:
          throw AppUpdateException(
            event.value?.isNotEmpty == true
                ? 'Android could not install the update: ${event.value}'
                : 'Android could not install the update.',
          );
        case OtaStatus.INTERNAL_ERROR:
          throw AppUpdateException(
            event.value?.isNotEmpty == true
                ? 'The update failed: ${event.value}'
                : 'The update failed unexpectedly.',
          );
      }
    }

    throw const AppUpdateException(
      'The update download ended before installation started.',
    );
  }

  Future<AppUpdateOutcome> _installFromGooglePlay(
    AvailableAppUpdate update,
    AppUpdateProgressCallback onProgress,
  ) async {
    try {
      final info = _playUpdateInfo ?? await play.InAppUpdate.checkForUpdate();

      if (info.immediateUpdateAllowed) {
        onProgress(
          const AppUpdateProgress(message: 'Opening the Google Play updater…'),
        );
        final result = await play.InAppUpdate.performImmediateUpdate();
        return _mapPlayResult(result);
      }

      if (info.flexibleUpdateAllowed) {
        onProgress(
          const AppUpdateProgress(
            message: 'Downloading the update from Google Play…',
          ),
        );
        final result = await play.InAppUpdate.startFlexibleUpdate();
        if (result != play.AppUpdateResult.success) {
          return _mapPlayResult(result);
        }

        onProgress(const AppUpdateProgress(message: 'Installing the update…'));
        await play.InAppUpdate.completeFlexibleUpdate();
        return AppUpdateOutcome.started;
      }
    } catch (error) {
      debugPrint(
        'Google Play in-app update failed; opening store page: $error',
      );
    }

    onProgress(
      const AppUpdateProgress(message: 'Opening the app in Google Play…'),
    );
    final launched = await launchUrl(
      update.storeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const AppUpdateException(
        'Google Play could not be opened on this device.',
      );
    }
    return AppUpdateOutcome.started;
  }

  AppUpdateOutcome _mapPlayResult(play.AppUpdateResult result) {
    switch (result) {
      case play.AppUpdateResult.success:
        return AppUpdateOutcome.started;
      case play.AppUpdateResult.userDeniedUpdate:
        return AppUpdateOutcome.cancelled;
      case play.AppUpdateResult.inAppUpdateFailed:
        throw const AppUpdateException(
          'Google Play could not complete the update.',
        );
    }
  }

  Uri _playStoreUri(String configuredUrl, String packageName) {
    return _validHttpsUri(configuredUrl) ??
        Uri.https('play.google.com', '/store/apps/details', {
          'id': packageName,
        });
  }

  Uri? _validHttpsUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }
}

class _RemoteUpdateSettings {
  const _RemoteUpdateSettings({
    required this.enabled,
    required this.latestBuild,
    required this.latestVersion,
    required this.title,
    required this.message,
    required this.apkUrl,
    required this.apkSha256,
    required this.playStoreUrl,
  });

  final bool enabled;
  final int latestBuild;
  final String latestVersion;
  final String title;
  final String message;
  final String apkUrl;
  final String apkSha256;
  final String playStoreUrl;
}
