# Android login persistence

Build 5 shipped Firebase Android Auth 23.2.1 via FlutterFire's Android BoM
33.16.0. On the affected Huawei DUB-LX1 running Android 8.1, its restored
authentication preferences could not be decrypted with the device's Keystore.
The same broken keyset also prevented saving a new login. The user could sign
in, but every process restart returned to the login screen.

The phone's build 5 logs confirmed both failures:

```text
KeysetManager failed to initialize - unable to decrypt data
KeysetManager failed to initialize - unable to encrypt data
```

Firebase documents this regression and recommends Auth 24.0.1 or later:
[Android Firebase release notes](https://firebase.google.com/support/release-notes/android#auth_v24-0-0).

Build 6 sets the native Android BoM to 34.1.0 through FlutterFire's supported
`FlutterFire.FirebaseSDKVersion` Gradle override. The APK contains Auth 24.0.1.
All Firebase Android plugins use that aligned BoM; Dart/Web dependencies retain
their existing versions. When upgrading FlutterFire, review this override and
remove it once the plugins themselves provide a fixed native SDK version.

Android backup rules exclude device-local shared preferences from cloud backup
and device transfer, including Firebase's encrypted session/keyset preferences.
Android Keystore keys cannot be transferred with those files. Other backup
domains retain Android's default behavior. Firebase Authentication continues to
own session persistence.

Validation on the affected phone on November 2, 2026:

- Installed the published build 5; the user signed in normally.
- Force-stopped and relaunched it: login screen appeared and storage crypto
  errors were recorded.
- Installed the signed build 6 over build 5 without clearing app data.
- The user signed in once. Force-stopped and relaunched the release APK:
  the signed-in home screen returned, with no storage or runtime errors.
- Verified the APK's native SDK version, ARM Flutter binaries, version code,
  and existing release signing certificate; all 16 selected Flutter tests pass.

Before distributing a new release, run `scripts/verify-android-release.ps1`.
It examines the actual APK, rejecting Auth SDK versions older than 24.0.1 and
missing ARM Flutter binaries. Upload the versioned APK and verify the public
download before publishing its Remote Config update announcement.
