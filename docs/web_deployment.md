# Flutter Web deployment

Push to `main` in `nawshad85/mess_management_flutter` to run
`.github/workflows/deploy-vercel.yml`. Manual runs are available in GitHub Actions.
Other branches cannot run the production job.

The workflow pins Flutter 3.41.6, Node.js 24, Vercel CLI 65.9.0, and action
commit IDs. It resolves the committed pubspec.lock, analyzes the application,
runs the existing update-model tests, builds Web once, and uploads only
`.vercel/output` using `vercel deploy --prebuilt --prod`.

Vercel project: `mess-manager` in `abrarsami2021-7062s-projects`.
Production website: https://mess-manager-khaki.vercel.app.
Native Vercel Git deployments are disabled in vercel.json. Do not enable a
second deployment workflow for this repository.

## Repository secrets

In GitHub Settings > Secrets and variables > Actions, configure:

- `VERCEL_ORG_ID`: the team ID in the local ignored `.vercel/project.json`.
- `VERCEL_PROJECT_ID`: the project ID in that same file.
- `VERCEL_TOKEN`: a dedicated Vercel access token with access to this project.

Create the token at https://vercel.com/account/tokens and enter it directly into
GitHub. Do not commit it or reuse the expiring local CLI OAuth session token.
If the token has an expiration date, replace the GitHub secret before it expires.
The workflow logs a clear error if a required secret is missing.

## Native configuration

The ignored `lib/utils/secrets.dart` contains Android OneSignal configuration.
The Web job copies the tracked example file into its disposable checkout;
OneSignal methods are guarded on Web and never use these example values.
No Android notification credentials are required by CI or deployed to Vercel.
Android development continues to use the developer's original local secrets.

Firebase options are generated public client identifiers, not administrative
credentials. Both platforms use the existing `fluid-cosmos-467914-b1` project.
No Firestore rules, indexes, users, or data are deployed by this workflow.
When adding a production domain, add its hostname to Firebase Authentication's
authorized domains without removing existing entries.

## Routing and verification

`scripts/prepare-vercel-output.mjs` preserves all build assets, serves existing
files first, and falls back to index.html for application routes. Missing static
assets return 404. Unversioned Flutter artifacts revalidate between deployments.
The current Flutter app uses hash routes, such as `/#/login`; the server also
serves the app for direct paths such as `/login`.

The final workflow step checks the production HTML, JavaScript, fonts manifest,
CanvasKit Wasm, icons, direct-route fallback, and missing-asset response. It does
not sign in, create test users, send emails, or modify production data.
