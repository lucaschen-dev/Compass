# Before inviting real students

This checklist describes unfinished release work, not a claim of approval.

- Build on Xcode 26+, test iPhone simulator and physical device.
- Inspect compact iPhone layout, Dark Mode, large text, VoiceOver, keyboard,
  reduced transparency/motion, slow network, airplane mode, and server errors.
- Verify real email delivery, blocked/non-school domains, and spam filtering.
- Establish school/community contact, verified role process and moderator team.
- Publish terms, community rules, age-appropriate privacy notice and support
  contact; disclose AI processing, local drafts, and moderator access.
- Complete privacy manifest collection declarations and App Store privacy
  answers for contact info, identifiers, profile content and user content.
- Add account deletion and retention workflow, chat/member reporting, unblock,
  suspension, verification expiry and appeals.
- Add safe image handling only when attachments are implemented.
- Replace serialized stdlib HTTP pilot server for internet production; configure
  HTTPS edge, durable limiter, provider quotas, abuse alerts, monitoring, backups.
- Complete pagination and delivery/idempotency semantics for reliable messaging.
- Replace polling with an authenticated realtime subscription transport.
- Add APNs device registration with account ownership, token revocation,
  notification preferences and privacy-preserving payloads (no anonymous author
  identity or private message body in notifications by default).
- Obtain the user's own Apple signing configuration and test a signed build.
- Run TestFlight with a small pilot; do not advertise this archive as installable.
- Build and verify Mac Catalyst separately; later adapt sidebar/keyboard flows.

Source references used for the implementation direction:
- https://developer.apple.com/documentation/swiftui/glasseffect(_:in:)
- https://developer.apple.com/documentation/swiftui/tabview
- https://developers.openai.com/api/docs/guides/moderation
- https://developer.apple.com/app-store/review/guidelines/
