# Firestore schema

Compass uses Firebase project `compass-database-480ea`. Firebase Auth owns email and password. Firestore does not store password hashes, and personal calendar URLs or imports never leave the device.

Guide text, course catalogs, graduation requirements, club and event definitions, and classmates stay in the app. Firestore stores the school catalog stubs, user profiles, one private state document per user and school, and shared posts and chat.

## Collections

```text
schools/{schoolId}
users/{uid}
users/{uid}/schools/{schoolId}
schools/{schoolId}/posts/{postId}
schools/{schoolId}/posts/{postId}/replies/{replyId}
schools/{schoolId}/threads/{threadId}
schools/{schoolId}/threads/{threadId}/messages/{messageId}
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

**Post:** `id`, `authorId` (the Auth uid), `title`, `body`, `category`, `subtag`, `at`, `anonymous`, `priority`, `askedPerson`, `photos`, `likes`. Replies are not embedded. Inline `data:` photos stay on the device.

**Reply:** `id`, `author`, `authorId`, `body`, `at`.

**Thread:** `id`, `title`, `participantIds`, `group`, `unread`, `pinned`, `muted`, `archived`, `left`, `updatedAt`. Drafts stay on the device.

**Message:** `id`, `senderId`, `text`, `createdAt`, `replyTo`, `reaction`, `unsent`, `edited`. Delete-for-me is local and does not delete the shared message.

## Sync

The app hydrates once at sign-in into SharedPreferences and the in-memory controllers. Later edits write through after a short debounce. Home and Chat reload when their local cache is older than five minutes. An open conversation listens for new messages until that screen closes. If a write fails, the change remains on the device and the app says it could not sync.

## Rules

Signed-in users can read both demo school catalogs. Profile and private state are limited to `request.auth.uid`. Posts, replies, and messages in a school require the user's `schoolId` to match, and the author or sender field has to be that uid. Calendar and password fields are rejected. Rules are in `firestore.rules`. Email/password accounts must use the school domain. Google accounts may use the Google email.
