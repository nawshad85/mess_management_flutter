# App update setup

MessHub checks for an Android update once after every cold app launch. The
check runs after authentication routing finishes, so it does not disappear
with the splash screen.

There are two Android distribution flavors:

- `direct` is the default while the app is distributed outside Google Play. It
  detects the phone's preferred ABI, downloads the matching signed APK, and
  opens Android's installer. A universal-APK mode remains available as a
  fallback.
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
| `android_latest_build` | Number | `3` | Direct release's base build number: the number after `+` in `pubspec.yaml` |
| `android_play_latest_build` | Number | `0` | Optional Play `versionCode` fallback when Play Core cannot answer |
| `android_latest_version` | String | `1.0.2` | Version name shown in the prompt |
| `android_update_title` | String | `Update available` | Prompt title |
| `android_update_message` | String | `A faster version of MessHub is ready.` | Prompt body |
| `android_split_per_abi` | Boolean | `true` | Select an ABI-specific APK automatically |
| `android_apk_url_arm64_v8a` | String | `https://example.com/messhub-arm64-v8a.apk` | Stable public HTTPS URL for 64-bit ARM phones |
| `android_apk_sha256_arm64_v8a` | String | 64 lowercase hex characters | ARM64 APK integrity check |
| `android_apk_url_armeabi_v7a` | String | `https://example.com/messhub-armeabi-v7a.apk` | Stable public HTTPS URL for 32-bit ARM phones |
| `android_apk_sha256_armeabi_v7a` | String | 64 lowercase hex characters | ARM32 APK integrity check |
| `android_apk_url_x86_64` | String | `https://example.com/messhub-x86_64.apk` | Stable public HTTPS URL for x86-64 emulators/devices |
| `android_apk_sha256_x86_64` | String | 64 lowercase hex characters | x86-64 APK integrity check |
| `android_apk_url` | String | `https://example.com/messhub-universal.apk` | Universal APK URL, used only when `android_split_per_abi` is `false` |
| `android_apk_sha256` | String | 64 lowercase hex characters | Universal APK integrity check |
| `android_play_store_url` | String | `https://play.google.com/store/apps/details?id=com.nawshad.messhub` | Store-page fallback after publication |

Defaults are safe: updates are enabled, but `android_latest_build` is `0`, so
no direct-update prompt appears until a release is configured. If fetching
Remote Config fails, the last activated values are used and app startup
continues normally.

The three ABI URLs are deliberately separate. The app reads Android's ordered
`SUPPORTED_ABIS` list and selects the first compatible artifact. It never
falls back to an incompatible APK. A missing URL therefore skips the update on
that device instead of downloading the wrong binary.

## Releasing smaller direct APKs now

1. Choose the final Android application ID and keep the permanent release
   signing key safe before distributing to real users. Every future APK must
   use the same application ID and signing certificate or Android will reject
   it as an update. Release builds load the ignored `android/key.properties`
   file and fail instead of falling back to debug signing when it is missing.
2. Increase `version` in `pubspec.yaml`. For example, change `1.0.1+2` to
   `1.0.2+3`. The number after `+` is the base build number entered in
   `android_latest_build`.
3. Build the three signed direct APKs:

   ```powershell
   flutter build apk --flavor direct --release --split-per-abi
   ```

4. Upload all three files from `build/app/outputs/flutter-apk/` to stable,
   public HTTPS URLs (for example, a public Supabase Storage bucket):

   - `app-arm64-v8a-direct-release.apk`
   - `app-armeabi-v7a-direct-release.apk`
   - `app-x86_64-direct-release.apk`

5. Calculate every checksum:

   ```powershell
   Get-FileHash .\build\app\outputs\flutter-apk\app-*-direct-release.apk -Algorithm SHA256
   ```

6. In Remote Config, set `android_split_per_abi = true`, all three matching URL
   and SHA-256 pairs, `android_latest_version`, and
   `android_latest_build = 3`. Upload the APKs before publishing the Remote
   Config values so users never receive a dead URL.
7. Publish the Remote Config changes. Any install with a lower build number is
   prompted on its next cold launch.

Flutter gives split APKs architecture-specific Android version codes while
building. For base build `3`, the generated codes are `1003` (armeabi-v7a),
`2003` (arm64-v8a), and `4003` (x86_64). The updater performs this conversion
itself, so Remote Config still uses the simple base number `3`.

Keep direct split base build numbers below `1000`; Flutter reserves the
thousands digits for its ABI code.

If a universal APK is preferred for a release, build without
`--split-per-abi`, upload `app-direct-release.apk`, set
`android_split_per_abi = false`, and use the two unsuffixed URL/checksum keys.

On Android 8 and newer, the first direct update may ask the user to allow
"Install unknown apps" for MessHub. This is an Android security requirement.

### One-time migration for existing users

An older MessHub build only understands the universal `android_apk_url` key.
If that build is already installed by users, release this ABI-aware updater as
a universal bridge first:

1. Build version `1.0.2+3` without `--split-per-abi`.
2. Upload `app-direct-release.apk` and publish the unsuffixed URL/checksum with
   `android_split_per_abi = false` and `android_latest_build = 3`.
3. For the following release, increase to base build `4`, build with
   `--split-per-abi`, upload all three files, and switch
   `android_split_per_abi` to `true`.

The bridge does not receive a duplicate split update for base build `3`; the
updater normalizes Flutter's ABI-specific version codes before comparing base
builds.

## Moving to Google Play later

1. Keep the same application ID and signing identity. When enrolling in Play
   App Signing, import the existing MessHub signing key if direct installs must
   update in place; a different app-signing certificate creates an
   incompatible app.
2. Choose a Play build number higher than every direct split APK already
   installed. For example, after distributing base build `4`, use a Play build
   number greater than `4004` (such as `4005`). Then build the policy-compliant
   flavor:

   ```powershell
   flutter build appbundle --flavor play --release --build-number 4005
   ```

3. Upload `build/app/outputs/bundle/playRelease/app-play-release.aab` to a Play
   testing or production track.
4. Set `android_play_store_url` to the final listing URL and optionally set
   `android_play_latest_build = 4005`. The APK URLs may remain configured; the
   Play flavor never uses them.

For Play-installed builds, Google Play is authoritative about whether an
update is available. `android_play_latest_build` is only a store-page fallback
when Play Core cannot answer. Play in-app updates cannot be tested with an APK
installed by `flutter run`; install the Play flavor from an internal testing
track or Internal App Sharing. Google Play receives the single AAB and creates
the correct optimized APKs for each device automatically.

## Quick test before publishing

1. Install an older direct APK, such as base build `2`.
2. Build and host the same-ID, same-signature split APKs for base build `3`.
3. Publish Remote Config with `android_split_per_abi = true`,
   `android_latest_build = 3`, and all three hosted APK details.
4. Fully close and reopen the old app.
5. Verify No dismisses the prompt and that reopening shows it again.
6. Verify Yes downloads the APK, validates the checksum, and opens Android's
   installer.

## Platform references

- [Firebase Remote Config for Flutter](https://firebase.google.com/docs/remote-config/get-started?platform=flutter)
- [Android in-app updates](https://developer.android.com/guide/playcore/in-app-updates)
- [Google Play `REQUEST_INSTALL_PACKAGES` policy](https://support.google.com/googleplay/android-developer/answer/12085295)
