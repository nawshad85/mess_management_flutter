import 'package:flutter_test/flutter_test.dart';
import 'package:mess_manager/models/android_apk_target.dart';

void main() {
  group('selectPreferredAndroidApkAbi', () {
    test('uses Android supported ABI order', () {
      expect(
        selectPreferredAndroidApkAbi(['arm64-v8a', 'armeabi-v7a']),
        AndroidApkAbi.arm64V8a,
      );
      expect(
        selectPreferredAndroidApkAbi(['armeabi-v7a', 'arm64-v8a']),
        AndroidApkAbi.armeabiV7a,
      );
    });

    test('skips unsupported ABIs and finds a supported split', () {
      expect(
        selectPreferredAndroidApkAbi(['x86', 'x86_64']),
        AndroidApkAbi.x86_64,
      );
    });

    test('returns null when no distributed ABI is compatible', () {
      expect(selectPreferredAndroidApkAbi(['x86']), isNull);
    });
  });

  group('AndroidApkAbi', () {
    test('matches Flutter split-per-abi version-code offsets', () {
      expect(AndroidApkAbi.armeabiV7a.versionCodeForBaseBuild(2), 1002);
      expect(AndroidApkAbi.arm64V8a.versionCodeForBaseBuild(2), 2002);
      expect(AndroidApkAbi.x86_64.versionCodeForBaseBuild(2), 4002);
    });

    test('builds the matching Remote Config keys', () {
      expect(AndroidApkAbi.arm64V8a.remoteUrlKey, 'android_apk_url_arm64_v8a');
      expect(
        AndroidApkAbi.armeabiV7a.remoteSha256Key,
        'android_apk_sha256_armeabi_v7a',
      );
    });
  });

  group('baseBuildFromFlutterSplitVersionCode', () {
    test('recovers the pubspec build number from each split code', () {
      expect(baseBuildFromFlutterSplitVersionCode(1003), 3);
      expect(baseBuildFromFlutterSplitVersionCode(2003), 3);
      expect(baseBuildFromFlutterSplitVersionCode(4003), 3);
    });

    test('keeps a normal universal build code unchanged', () {
      expect(baseBuildFromFlutterSplitVersionCode(3), 3);
    });
  });
}
