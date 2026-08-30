# App update setup

MessHub checks for an Android update once after every cold app launch. The
check runs after authentication routing finishes, so it does not disappear
with the splash screen.

There are two Android distribution flavors:

- `direct` is the default while the app is distributed from Supabase as one
  universal APK. It downloads the configured signed APK and opens Android's
  installer.
- `play` uses Google Play Core in-app updates. Its merged manifest removes the
  APK installation permissions that Google Play does not allow for
  self-update.

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
| `android_latest_build` | Number | `3` | Latest Android build/version code; controls direct APK prompts |
| `android_latest_version` | String | `1.0.2` | Version name shown in the prompt |
| `android_update_title` | String | `Update available` | Prompt title |
| `android_update_message` | String | `A faster version of MessHub is ready.` | Prompt body |
| `android_apk_url` | String | `https://example.supabase.co/storage/v1/object/public/releases/messhub.apk` | Stable public HTTPS URL for the universal APK |
| `android_apk_sha256` | String | 64 hexadecimal characters | Optional but recommended integrity check |
| `android_play_store_url` | String | `https://play.google.com/store/apps/details?id=com.nawshad.messhub` | Store-page fallback after publication |

Defaults are safe: updates are enabled, but `android_latest_build` is `0`, so
no direct-update prompt appears until a release is configured. If fetching
Remote Config fails, the last activated values are used and app startup
continues normally.

## Releasing the universal APK to Supabase

1. Keep the permanent release signing key safe. Every future APK must use the
   same application ID and signing certificate or Android will reject it as an
   update. Release builds load the ignored `android/key.properties` file and
   fail instead of falling back to debug signing when it is missing.
2. Increase `version` in `pubspec.yaml` for each release. The current release
   is `1.0.2+3`; a following release could be `1.0.3+4`. The number after `+`
   is entered in `android_latest_build`.
3. Build one signed universal APK:

   ```powershell
   flutter build apk --flavor direct --release
   ```

4. Upload
   `build/app/outputs/flutter-apk/app-direct-release.apk` to a stable public
   Supabase Storage URL. Replacing the object at the same URL is acceptable,
   although versioned filenames make rollbacks easier.
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
4. Set `android_play_store_url` to the final listing URL. The Supabase APK may
   remain configured; the Play flavor never downloads it.

For Play-installed builds, Google Play is authoritative about whether an
update is available. `android_latest_build` is used only as a store-page
fallback when Play Core cannot answer. Play in-app updates cannot be tested
with an APK installed by `flutter run`; install the Play flavor from an
internal testing track or Internal App Sharing.

## Quick test before publishing

1. Install an older universal direct APK, such as build `2`.
2. Host a same-ID, same-signature universal APK with build `3`.
3. Publish Remote Config with `android_latest_build = 3` and the hosted APK
   details.
4. Fully close and reopen the old app.
5. Verify No dismisses the prompt and that reopening shows it again.
6. Verify Yes downloads the APK, validates the checksum, and opens Android's
   installer.

## Platform references

- [Firebase Remote Config for Flutter](https://firebase.google.com/docs/remote-config/get-started?platform=flutter)
- [Android in-app updates](https://developer.android.com/guide/playcore/in-app-updates)
- [Google Play `REQUEST_INSTALL_PACKAGES` policy](https://support.google.com/googleplay/android-developer/answer/12085295)
