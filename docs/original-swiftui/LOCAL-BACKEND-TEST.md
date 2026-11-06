# Local backend test result

Date: 2026-09-27. Runtime: assistant execution environment, not the user's Mac or iPhone.

- Existing backend regression tests: **53 passed**.
- Loopback HTTP integration checks: **11 passed**, using **80 HTTP requests** against the production Handler and Service.
- Four simulated school-account logins and profile updates.
- Q&A publication, urgent pin, personal mention and replies.
- Held posts remain invisible to other users.
- Direct and group chat delivery; non-members cannot access chat history.
- Twenty JPEG uploads larger than the normal JSON request limit, gallery publication, ordered photo references and authenticated download.
- Sixteen concurrent feed requests completed without server errors. This is a small concurrency check, not a production capacity benchmark.
- SQLite-backed accounts/sessions, posts, chats and images survived an actual server shutdown/restart.
- Leaving a group and signing out revoked access.

All email, text/image moderation and priority decisions were simulated in test fixtures. No external email or AI service was called. There was no native iPhone UI, keyboard/animation, push notification or real Blackbaud sync test. These checks do not establish production readiness.

The test listener bound only to 127.0.0.1 on an automatically assigned port. The runner stopped it and removed the temporary database/users after testing. No existing .env, app configuration or database was modified.

## Run on your own Mac

Double-click **Test-Backend.command** inside this project folder. It requires Python 3.11 or newer. On first run it creates an isolated `.local-test/venv` and installs the photo dependency if absent. It runs the 53 regression tests, starts a temporary backend for the HTTP checks, then shuts it down automatically.

This command tests the backend automatically; it does not keep a server running for the iPhone. Direct app-to-local-backend testing requires configuring an API endpoint reachable by the device and configuring real or explicitly simulated email/AI providers.

To run manually with dependencies already installed:

```sh
python3 -m unittest discover -s server -q
python3 script/test_local_backend.py
```
