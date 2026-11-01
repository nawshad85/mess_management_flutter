# Flutter Web deployment

Push to `main` in `nawshad85/mess_management_flutter`. Vercel's native GitHub
integration builds and publishes the Web application automatically.
GitHub Actions is not used and its billing status does not affect this pipeline.

The build command is `bash scripts/vercel-build.sh`, with output in `build/web`
and Build Output API artifacts in `.vercel/output`. Only `main` is enabled for
Git deployments in vercel.json.

Vercel project: `mess-manager` in `abrarsami2021-7062s-projects`.
Production website: https://mess-manager-khaki.vercel.app.
The Vercel GitHub App must be installed for `nawshad85` with access to
`mess_management_flutter`, and the existing Vercel project must be connected to
that repository with production branch `main`.

## Build and credentials

The build script downloads Flutter 3.41.6 from the official Flutter repository
and checks its exact commit. It resolves the committed pubspec.lock, analyzes
the application (existing informational lints remain visible), runs the existing
update-model tests, builds Web, and prepares the static hosting artifacts.
Build errors are visible in Vercel deployment logs. Failed builds retain the
previous successful production deployment.

No `VERCEL_TOKEN`, `VERCEL_ORG_ID`, or `VERCEL_PROJECT_ID` GitHub Actions secrets
are needed. Any secrets left from the previous Actions setup are unused by this
pipeline. No second deployment workflow should be enabled for this repository.

## Native configuration

The ignored `lib/utils/secrets.dart` contains Android OneSignal configuration.
On Vercel, the script copies the tracked example into its disposable checkout;
OneSignal methods are guarded on Web and never use these example values.
No Android notification credentials are required by CI or deployed to Vercel.
Android development continues to use the developer's original local secrets.

Firebase options are generated public client identifiers, not administrative
credentials. Both platforms use the existing `fluid-cosmos-467914-b1` project.
The production hostname is already authorized for Firebase Authentication.
No Firestore rules, indexes, users, or data are deployed by this pipeline.
When adding a production domain, add its hostname to Firebase Authentication's
authorized domains without removing existing entries.

## Routing and verification

`scripts/prepare-vercel-output.mjs` preserves all build assets, serves existing
files first, and falls back to index.html for application routes. Missing static
assets return 404. Unversioned Flutter artifacts revalidate between deployments.
The current Flutter app uses hash routes, such as `/#/login`; the server also
serves the app for direct paths such as `/login`.

After deployment, inspect its status and build logs in the Vercel dashboard.
To check production HTML, JavaScript, fonts, CanvasKit Wasm, icons, direct-route
fallback, and missing-asset handling locally, run:

```sh
node scripts/verify-web-deployment.mjs https://mess-manager-khaki.vercel.app
```

This check does not sign in, send emails, or modify production data.
