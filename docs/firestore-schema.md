# Firestore schema

Compass uses Firebase project `compass-database-480ea`. Firebase Auth owns email and password. Firestore does not store password hashes, and personal calendar URLs or imports never leave the device.

Guide text, course catalogs, graduation requirements, club and event definitions, and sample classmates ship in the app. Firestore stores the school catalog stubs, private user profiles and state, opt-in directory entries, friend requests, shared posts and replies, and each account’s demo chat backup.

## Collections

```text
schools/{schoolId}
users/{uid}
users/{uid}/schools/{schoolId}
schools/{schoolId}/directory/{uid}
schools/{schoolId}/friendRequests/{pairId}
schools/{schoolId}/posts/{postId}
schools/{schoolId}/posts/{postId}/replies/{replyId}
users/{uid}/schools/{schoolId}/threads/{threadId}
users/{uid}/schools/{schoolId}/threads/{threadId}/messages/{messageId}
```

`schoolId` is `alderline` or `cedarbrook`. The private blob is the document `users/{uid}/schools/{schoolId}` (a Firestore path has to contain an even number of segments).

## Documents

**School catalog** (`schools/alderline`, `schools/cedarbrook`): `id`, `name`, `location`, `initials`, `emailDomain`.

**Profile** (`users/{uid}`): `email`, `name`, `grade`, `schoolId`, `updatedAt`. Email/password accounts use `@{schoolId}.example`. A Google account keeps the Google email and the demo school chosen on the sign-in screen. The account’s school is fixed after profile creation.

**Private state** (`users/{uid}/schools/{schoolId}`), one read and one write per sync:

| Field | Type |
|---|---|
| `prefs` | map `{ interests: string[], meetupTime: string }` |
| `friends` | string[] of legacy demo contact IDs |
| `clubApplies` | string[] |
| `requirementProgress` | map of requirement id to completed count |
| `guideProgress` | string[] |
| `savedPosts` | string[] |
| `likedPosts` | string[] |
| `followedTags` | string[] |
| `updatedAt` | timestamp |

**Directory** (`schools/{schoolId}/directory/{uid}`): `name` only. An account can show or hide its own name. Existing users can receive a request without listing their name by sharing their exact Compass code, which is their Firebase Auth UID. Directory entries are opt-in and private profile fields are not copied into them. When the private name changes, an account can hide and publish its name again. School membership here means membership in a Compass demo school.

**Friend request** (`schools/{schoolId}/friendRequests/{pairId}`): sorted `participants` (exactly two Firebase UIDs), `senderId`, `recipientId`, `senderName`, `status`, `createdAt`, `updatedAt`. The document ID is the two sorted UIDs joined with `:`. Status begins at `pending`. The recipient can change it to `accepted` or `declined`, and the sender can change it to `canceled`. On acceptance the recipient adds `recipientName` from their own profile. Only accepted requests count as friends, and both people can see the accepted relationship. One canonical document and transactional writes keep simultaneous sends and retries consistent. A canceled request can be sent again. Decline is terminal.

**Post:** `id`, `authorId` (the Auth uid), `title`, `body`, `category`, `subtag`, `at`, `anonymous`, `priority`, `askedPerson`, `photos`, `likes`. Replies are separate documents. Photo Gallery posts can embed up to four compressed base64 photos (160,000 characters each). Compass rebuilds shared photos from pixels, omitting original metadata. Photos attached to non-gallery posts and demo chats stay on the device.

**Reply:** `id`, `author`, `authorId`, `body`, `at`.

**Thread:** `id`, `title`, `participantIds`, `group`, `unread`, `pinned`, `muted`, `archived`, `left`, `updatedAt`. Drafts stay on the device. Demo contact IDs are display metadata. The UID in the path owns the backup and is the only account allowed to read it.

**Message:** `id`, `senderId`, `text`, `createdAt`, `replyTo`, `reaction`, `unsent`, `edited`. Delete-for-me hides the message on the current device.

## Sync

The app hydrates once at sign-in into SharedPreferences and the in-memory controllers. Later edits write through after a short debounce. Home and Chat reload when their local cache is older than five minutes. An open conversation listens for new messages until that screen closes. If a write fails, the change remains on the device and the app says it could not sync.

## Rules

Signed-in users can read both demo school catalogs. Profile and private state are limited to `request.auth.uid`. Directory reads require matching school membership. A directory owner can publish only their current profile name. Friend request queries must filter by the signed-in UID in `participants`. Rules also verify the request participants, their school, the sender name, and who can accept, decline, or cancel. Posts and replies require the user’s school to match. Authors may edit their own posts and replies. A post owner can remove replies when deleting their post. Chat requires both the matching school and the UID in the path. The former shared chat path is denied because its demo IDs do not establish historical participants. The app can carry forward its own locally cached outgoing messages and drafts. Calendar and password fields are rejected. Rules are in `firestore.rules`. Email/password accounts must use the school domain. Google accounts may use the Google email.


## Verify friend request rules locally

Run these commands from the repository root with Java installed. The test uses a Firebase demo project and synthetic accounts.

```sh
rules_runtime="$(mktemp -d)"
npm install --prefix "$rules_runtime" firebase-tools @firebase/rules-unit-testing firebase
COMPASS_FIREBASE_TEST_RUNTIME="$rules_runtime" \
  "$rules_runtime/node_modules/.bin/firebase" emulators:exec \
  --project demo-compass-friends --only firestore \
  'node --test scripts/test_firestore_friends.mjs'
```
