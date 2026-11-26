# Compass moderation

Compass members can report posts and Campus Photos albums from **Post actions**,
individual comments from **Comment actions**, and incoming direct messages from
**Message actions**. When a member submits a report, Compass shares the reported
content and selected reason with moderators. Members can block a person from a
post or comment, an incoming friend request, or a conversation. **Blocked people**
in Chat and Settings lets members undo a block.

Firestore enforces blocks in both directions for new friend requests,
acceptances, and direct messages. Compass hides blocked people’s posts and comments
from the person who blocked them. Blocking leaves the existing content available
for a moderator to review and preserves the chat history.

## Reviewing the queue

Assign a moderator and a backup for each school and check for pending reports
throughout the day. A staff member with authorized Firebase access can open
`schools/{schoolId}/moderationReports` and review documents with
`status: pending`. The report queue is private to authorized staff. Grant access
only to staff who need to review reports.

A report includes the selected reason, report time, reporter and reported member
IDs, and the original title and text. `contentId` points to the post itself or to
the comment or message under `parentId`. A photo report includes the post link
and caption. The photos remain in the original post and can be reviewed there.

Remove violating content promptly and record the resolution by updating the
report status in the Firebase console. Delete replies when taking down an entire
post. If the submission identifies an imminent threat or student safety issue,
follow the school’s established escalation process. Use Compass’s published
support contact to respond when a member has asked for follow-up.

The text filter applies to new posts, photo captions, comments and direct
messages. It covers a small set of explicit threats and abusive phrases.
Moderators review reports on existing content.

## Reviewing photos before publication

New school photo albums remain private until approved. Members see the status
of their own recent uploads under **Your submissions** in Campus Photos.
Existing published albums remain available.

Open `schools/{schoolId}/photoSubmissions` in the Firebase console and find
documents with `status: pending`. Use the following commands from the Compass
repository with authorized Firebase Admin credentials. The first command writes
private copies of the PNGs and a description to a temporary folder. Open the
images and review the caption before choosing an outcome. Delete the temporary
folder after review.

```sh
node functions/review-photo-submission.js PROJECT_ID SCHOOL_ID POST_ID --inspect
node functions/review-photo-submission.js PROJECT_ID SCHOOL_ID POST_ID --approve
node functions/review-photo-submission.js PROJECT_ID SCHOOL_ID POST_ID --reject
```

Approval publishes the album and updates the submission together. Rejection
leaves the images unpublished. Both remove the image bytes from the private
queue. Check for pending albums when checking reports.
