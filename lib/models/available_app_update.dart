import 'package:mess_manager/models/android_apk_target.dart';

enum UpdateDistribution { direct, play }

class AvailableAppUpdate {
  const AvailableAppUpdate({
    required this.distribution,
    required this.installedVersion,
    required this.installedBuild,
    required this.availableVersion,
    required this.availableBuild,
    required this.title,
    required this.message,
    required this.storeUri,
    this.apkUri,
    this.apkSha256,
    this.apkAbi,
  });

  final UpdateDistribution distribution;
  final String installedVersion;
  final int installedBuild;
  final String availableVersion;
  final int availableBuild;
  final String title;
  final String message;
  final Uri storeUri;
  final Uri? apkUri;
  final String? apkSha256;
  final AndroidApkAbi? apkAbi;

  bool get usesGooglePlay => distribution == UpdateDistribution.play;
}

class AppUpdateProgress {
  const AppUpdateProgress({required this.message, this.fraction});

  final String message;
  final double? fraction;
}

enum AppUpdateOutcome { started, completed, cancelled }

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
