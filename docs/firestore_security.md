# Firestore access controls

The client API keys remain public Firebase configuration. Access is enforced by
the deployed Firestore rules; profile roles supplied by the client are not used
as proof of manager authority. The canonical authority is each mess document's
managerId and memberIds.

## Private and shared profiles

- `users/{uid}`: only that user can read the full document, including email and
  manager PIN material. Collection queries are denied. Managers can modify only
  permitted membership/room fields for users belonging to their mess.
- `memberProfiles/{uid}`: contains only uid, name, uniqueId, messId, role, and
  roomId. The owner and actual co-members can fetch an individual profile;
  collection enumeration is denied.
- `inviteCodes/{eightCharacterCode}`: an authenticated user can look up a known
  invitation code to obtain only uid, name, and messId. Collection enumeration is
  denied. Emails and PINs are never included.

The app keeps shared copies synchronized with private profiles in batched writes.
Rules verify each shared document against the private document after the batch.
Chat mention suggestions use the invitation code instead of another user's email.

## Invitations and roles

Only a real mess manager can send an invitation. Reads are limited to its
recipient and that mess's manager. A recipient can decline it or atomically
accept it with a membership/private-profile update. Rules require the invitation
to be pending, addressed to that account, issued by the current manager, and for
that exact mess. Replays, cross-mess joins, simultaneous memberships, arbitrary
role changes, and standalone self-joins are denied. The membership update may
not modify any mess metadata. Managers can remove members but cannot bypass the
invitation flow to force-add accounts or transfer their manager identity.

Rooms, notices, deposits, summaries, and invitations enforce manager boundaries.
Existing member-level financial-entry and group-message deletion permissions are
preserved. Entry authors cannot be spoofed; message sender identities/names and
read receipts are checked. Sender edits retain the app's 30-minute limit.
The manager PIN remains an owner-private, client-side confirmation step; server
authorization depends on the actual manager UID, not the PIN or profile role.

## Local security tests

Install the Firebase CLI and Java 21+, then run from the repository root:

```sh
npm ci --prefix tools/firestore-security
firebase emulators:exec --only firestore --project demo-mess-security --config firebase.test.json "npm --prefix tools/firestore-security test"
```

On Windows, use `npm.cmd` for the inner npm command if needed. The tests use only
an isolated demo project. They never create production users or financial data.
The suite covers private reads, legitimate queries, creation, invitations,
membership removal, room assignment, deletion cleanup, and hostile requests.

## Rollout and existing installations

`tools/firestore-security/backfill-profiles.mjs` uses the current Firebase CLI
login and the official Firestore SDK. It validates existing invitation codes,
then adds sanitized `memberProfiles` and `inviteCodes` documents. It never changes
the existing private profiles, messes, messages, invitations, or financial data.

```sh
node tools/firestore-security/backfill-profiles.mjs --project fluid-cosmos-467914-b1
node tools/firestore-security/backfill-profiles.mjs --project fluid-cosmos-467914-b1 --apply
```

The first command is a read-only dry run. The additive migration is repeatable
and refuses conflicting code ownership. Backfill before releasing the new rules.
Stage the updated Web build, deploy only `firestore:rules`, then promote that Web
deployment. Existing Android installations must update to this source version;
older clients use queries and non-atomic invitation writes that are now denied.
No Firebase indexes, Authentication users, or existing data are removed.
