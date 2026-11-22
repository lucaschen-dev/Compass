# Firestore schema

Compass uses Firebase project `compass-database-480ea`. Firebase Auth owns email and password. Firestore does not store password hashes, and personal calendar URLs or imports never leave the device.

Guide text, course catalogs, graduation requirements, club and event definitions, and classmates stay in the app. Firestore stores the school catalog stubs, user profiles, one private state document per user and school, shared posts and replies, and each account’s demo chat backup.

## Collections

```text
schools/{schoolId}
users/{uid}
users/{uid}/schools/{schoolId}
schools/{schoolId}/posts/{postId}
schools/{schoolId}/posts/{postId}/replies/{replyId}
users/{uid}/schools/{schoolId}/threads/{threadId}
users/{uid}/schools/{schoolId}/threads/{threadId}/messages/{messageId}
```

`schoolId` is `alderline` or `cedarbrook`. The private blob is the document `users/{uid}/schools/{schoolId}` (a Firestore path has to contain an even number of segments).

## Documents

**School catalog** (`schools/alderline`, `schools/cedarbrook`): `id`, `name`, `location`, `initials`, `emailDomain`.

**Profile** (`users/{uid}`): `email`, `name`, `grade`, `schoolId`, `updatedAt`. Email/password accounts use `@{schoolId}.example`. A Google account keeps the Google email and the school chosen on the sign-in screen.

**Private state** (`users/{uid}/schools/{schoolId}`), one read and one write per sync:

| Field | Type |
|---|---|
| `prefs` | map `{ interests: string[], meetupTime: string }` |
| `friends` | string[] |
| `clubApplies` | string[] |
| `requirementProgress` | map of requirement id to completed count |
| `guideProgress` | string[] |
| `savedPosts` | string[] |
| `likedPosts` | string[] |
| `followedTags` | string[] |
| `updatedAt` | timestamp |

**Post:** `id`, `authorId` (the Auth uid), `title`, `body`, `category`, `subtag`, `at`, `anonymous`, `priority`, `askedPerson`, `photos`, `likes`. Replies are separate documents. Photo Gallery posts can embed up to four compressed base64 photos (160,000 characters each). Compass rebuilds shared photos from pixels, omitting original metadata. Photos attached to non-gallery posts and demo chats stay on the device.

**Reply:** `id`, `author`, `authorId`, `body`, `at`.

**Thread:** `id`, `title`, `participantIds`, `group`, `unread`, `pinned`, `muted`, `archived`, `left`, `updatedAt`. Drafts stay on the device. Demo contact IDs are display metadata. The UID in the path owns the backup and is the only account allowed to read it.

**Message:** `id`, `senderId`, `text`, `createdAt`, `replyTo`, `reaction`, `unsent`, `edited`. Delete-for-me hides the message on the current device.

## Sync

The app hydrates once at sign-in into SharedPreferences and the in-memory controllers. Later edits write through after a short debounce. Home and Chat reload when their local cache is older than five minutes. An open conversation listens for new messages until that screen closes. If a write fails, the change remains on the device and the app says it could not sync.

## Rules

Signed-in users can read both demo school catalogs. Profile and private state are limited to `request.auth.uid`. Posts and replies require the user’s school to match. Authors may edit their own posts and replies. A post owner can remove replies when deleting their post. Chat requires both the matching school and the UID in the path. The former shared chat path is denied because its demo IDs do not establish historical participants. The app can carry forward its own locally cached outgoing messages and drafts. Calendar and password fields are rejected. Rules are in `firestore.rules`. Email/password accounts must use the school domain. Google accounts may use the Google email.
