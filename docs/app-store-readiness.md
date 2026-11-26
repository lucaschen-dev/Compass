# Compass App Store release checks

## App Review access

Give App Review a working primary account and a second account for testing both sides of friend requests in an isolated review school. Use synthetic posts, photo albums and messages. The review school can use status `review` in `schoolRegistry`. An administrator seeds `users/{uid}` with that school ID. This lets assigned members open the school through **Sign in** while keeping it out of the public school picker. Use two new developer-controlled mailbox addresses on the same domain. The [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup) operator can bootstrap the school and two accounts with `node functions/seed-app-review.js PROJECT_ID REVIEWER_ONE_EMAIL REVIEWER_TWO_EMAIL /absolute/private/review-credentials.json`. The script writes passwords to a private file outside the repository and can resume from that file with `--resume`. Keep the file private. Verify them on the release builds and provide them privately in App Store Connect review notes. Include sample calendar import content and a disposable account for testing deletion.

In App Store Connect, add the [Privacy Policy](privacy.md) and [Support](support.md) URLs, current screenshots and review contact details. Complete App Privacy, age rating and export compliance for each distribution target. Verify the support inbox can receive messages and the team can respond.

## Moderation and account deletion

Review pending Firestore `schools/{schoolId}/moderationReports` entries daily. Only authorized Compass operators should have access. Review the referenced content. Remove abusive content promptly, restrict confirmed abusive accounts as appropriate and close the report with its outcome. Check the public support inbox for safety and account requests. Review the separate [photo submissions queue](moderation.md) before releasing new albums to the school. Keep identifying details out of public issue trackers.

Deploy Firestore rules and the `replies.authorId` and `blocked.targetUid` collection-group indexes. The deletion form and its status receipt work on Firebase Spark. A trusted operator runs the deletion queue at least daily, well within the seven-day period shown to users.

From the Compass repository, install the admin script dependencies with `npm --prefix functions ci`. Use an authorized [Firebase Admin SDK credential](https://firebase.google.com/docs/admin/setup) for the existing Firebase project. Keep credentials outside the repository. Run `node functions/process-account-deletions.js compass-database-480ea` to check the queue count, then add `--apply` to process pending requests. The script deletes each account and posts its completion receipt. A failed job stays pending and the next run retries it. Test the complete workflow with a disposable account before submission.

## iOS and Mac builds

Use the Apple Developer team that will publish Compass. The team must own the production bundle IDs. Match the native identifiers to their Firebase app configurations. Generate App Store distribution signing and provisioning, then archive each platform in Xcode and verify the export. For Mac, verify the sandbox and app-specific Keychain Sharing group in the signed archive. Development installs and local Mac builds are separate from this export.

Sources for these release checks are [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion), [App privacy details](https://developer.apple.com/app-store/app-privacy-details/) and [Upcoming Apple submission requirements](https://developer.apple.com/news/upcoming-requirements/).
