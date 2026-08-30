enum AndroidApkAbi {
  armeabiV7a(
    androidName: 'armeabi-v7a',
    remoteKeySuffix: 'armeabi_v7a',
    versionCodeOffset: 1000,
  ),
  arm64V8a(
    androidName: 'arm64-v8a',
    remoteKeySuffix: 'arm64_v8a',
    versionCodeOffset: 2000,
  ),
  x86_64(
    androidName: 'x86_64',
    remoteKeySuffix: 'x86_64',
    versionCodeOffset: 4000,
  );

  const AndroidApkAbi({
    required this.androidName,
    required this.remoteKeySuffix,
    required this.versionCodeOffset,
  });

  final String androidName;
  final String remoteKeySuffix;
  final int versionCodeOffset;

  String get remoteUrlKey => 'android_apk_url_$remoteKeySuffix';

  String get remoteSha256Key => 'android_apk_sha256_$remoteKeySuffix';

  int versionCodeForBaseBuild(int baseBuild) => versionCodeOffset + baseBuild;
}

AndroidApkAbi? selectPreferredAndroidApkAbi(Iterable<String> supportedAbis) {
  for (final supportedAbi in supportedAbis) {
    for (final targetAbi in AndroidApkAbi.values) {
      if (targetAbi.androidName == supportedAbi) return targetAbi;
    }
  }
  return null;
}

int baseBuildFromFlutterSplitVersionCode(int versionCode) {
  for (final abi in AndroidApkAbi.values) {
    final offset = abi.versionCodeOffset;
    if (versionCode >= offset && versionCode < offset + 1000) {
      return versionCode - offset;
    }
  }
  return versionCode;
}
