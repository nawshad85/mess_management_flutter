# App update setup

MessHub checks for an Android update once after every cold app launch. The
check runs after authentication routing finishes, so it does not disappear
with the splash screen.

There are two Android distribution flavors:

- `direct` is the default while the app is distributed as an APK. It downloads
  the configured signed APK and opens Android's installer.
- `play` uses Google Play Core in-app updates. Its merged manifest removes the
  APK installation permissions that Google Play does not allow for self-update.

The user always gets **No** and **Yes, update** choices. Choosing No dismisses
the prompt for the current process; it is shown again on the next cold launch
while the installed build is still old. Android does not allow a normal app to
install silently, so a direct APK update still requires the final system
installation confirmation.

## Firebase Remote Config parameters

Create and publish these parameters in the same Firebase project used by the
app:

| Parameter | Type | Example | Purpose |
| --- | --- | --- | --- |
| `android_update_enabled` | Boolean | `true` | Master switch for update checks |
| `android_latest_build` | Number | `2` | Latest Android `versionCode`; this controls direct APK prompts |
| `android_latest_version` | String | `1.0.1` | Version name shown in the prompt |
| `android_update_title` | String | `Update available` | Prompt title |
| `android_update_message` | String | `A faster version of MessHub is ready.` | Prompt body |
| `android_apk_url` | String | `https://example.com/messhub.apk` | Public HTTPS URL for the direct APK |
| `android_apk_sha256` | String | 64 lowercase hex characters | Optional but recommended integrity check |
| `android_play_store_url` | String | `https://play.google.com/store/apps/details?id=com.nawshad.messhub` | Store-page fallback after publication |

Defaults are safe: updates are enabled, but `android_latest_build` is `0`, so
no direct-update prompt appears until a release is configured. If fetching
Remote Config fails, the last activated values are used and app startup
continues normally.

## Releasing a direct APK now

1. Choose the final Android application ID and keep the permanent release
   signing key safe before distributing to real users. Every future APK must
   use the same application ID and signing certificate or Android will reject
   it as an update. Release builds load the ignored `android/key.properties`
   file and fail instead of falling back to debug signing when it is missing.
2. Increase both parts of `version` in `pubspec.yaml`. For example, change
   `1.0.0+1` to `1.0.1+2`. The number after `+` is the Android build/version
   code used for comparison.
3. Build the direct release (it is also the default flavor):

   ```powershell
   flutter build apk --flavor direct --release
   ```

4. Upload `build/app/outputs/flutter-apk/app-direct-release.apk` to a stable,
   public HTTPS URL.
5. Calculate its checksum:

   ```powershell
   Get-FileHash .\build\app\outputs\flutter-apk\app-direct-release.apk -Algorithm SHA256
   ```

6. In Remote Config, set `android_apk_url`, `android_apk_sha256`,
   `android_latest_version`, and `android_latest_build`. Upload the APK before
   publishing the new Remote Config values so users never receive a dead URL.
7. Publish the Remote Config changes. Any install with a lower build number is
   prompted on its next cold launch.

On Android 8 and newer, the first direct update may ask the user to allow
"Install unknown apps" for MessHub. This is an Android security requirement.

## Moving to Google Play later

1. Keep the same application ID and signing identity. Configure Play App
   Signing carefully if existing direct installs must be upgradeable through
   Google Play.
2. Increase the version/build number and build the policy-compliant flavor:

   ```powershell
   flutter build appbundle --flavor play --release
   ```

3. Upload `build/app/outputs/bundle/playRelease/app-play-release.aab` to a Play
   testing or production track.
4. Set `android_play_store_url` to the final listing URL. The APK URL may remain
   configured; the Play flavor never uses it.

For Play-installed builds, Google Play is authoritative about whether an
update is available. `android_latest_build` is used only as a store-page
fallback when Play Core cannot answer. Play in-app updates cannot be tested
with an APK installed by `flutter run`; install the Play flavor from an
internal testing track or Internal App Sharing.

## Quick test before publishing

1. Install an older direct APK, such as build `1`.
2. Host a same-ID, same-signature APK with build `2`.
3. Publish Remote Config with `android_latest_build = 2` and the hosted APK
   details.
4. Fully close and reopen the old app.
5. Verify No dismisses the prompt and that reopening shows it again.
6. Verify Yes downloads the APK, validates the checksum, and opens Android's
   installer.

## Platform references

- [Firebase Remote Config for Flutter](https://firebase.google.com/docs/remote-config/get-started?platform=flutter)
- [Android in-app updates](https://developer.android.com/guide/playcore/in-app-updates)
- [Google Play `REQUEST_INSTALL_PACKAGES` policy](https://support.google.com/googleplay/android-developer/answer/12085295)
