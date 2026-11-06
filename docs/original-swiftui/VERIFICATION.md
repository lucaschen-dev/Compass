# Community v1.0 verification — 2026-09-28 (Los Angeles)

- 80 isolated Python backend tests passed (53 existing + 14 account/chat/retention/push/migration tests + 13 administrator tests).
- 11 loopback HTTP integration checks passed, 84 actual HTTP requests, including 20-photo gallery, direct/group messaging, persistence, access checks and concurrent requests.
- New coverage: OTP-to-password onboarding gates; salted password storage; password login/reset and session revocation; anonymous ownership controls; pending own posts; own-comment deletion; reply references; server-side 120-second retraction boundary; photo/video message access; removed group-member rejection; retention of approved Important/Urgent posts; deletion of ordinary posts and related data; APNs queue, private payload, retry and blocked-recipient behavior; additive database migration.
- A real one-second MP4 fixture passed ffprobe/ffmpeg processing; AI review was simulated.
- Swift source syntax parsing passed for all 14 existing source files. No new Swift target membership required.
- Project updater exercised against an original-project copy: pbxproj/signing unchanged, .env/database unchanged, new scripts/tests copied, Community display name installed.
- Administrator coverage: strict server-side role checks, profile-role forgery rejection, anonymous identity isolation, private/pending/blocked posts, authenticated gallery access, approve/reject, deletion, report persistence and resolution, report notifications, revoked roles, pagination/search, 30-day report retention, idempotent first-account bootstrap.
- App icon validated as opaque RGB, 1024×1024.
- Python and shell syntax checks passed.

Not performed here: Xcode type checking/build, simulator rendering, physical iPhone keyboard/navigation/media export tests, actual APNs delivery, live-server deployment or production load test. Test email and AI calls are simulated. See COMMUNITY-UPDATE.md for device acceptance checks and APNs setup.
