# Connected-mode backend

## Local setup

Python 3.11 or newer. No pip packages required.

```sh
cd server
cp .env.example .env
```

Edit `.env` with exact confirmed school domains, a random secret, SMTP settings
and a server-side AI key. Use shell-safe single-quoted values for secrets with
special characters. Then:

```sh
set -a
source .env
set +a
python3 server.py
```

The server binds to **127.0.0.1:8080 only**. On an iPhone simulator on that same
Mac, the app can connect to `http://localhost:8080`. Physical devices require an
HTTPS hostname reachable from the device. No arbitrary HTTP transport exception
is included in the app; the client only permits HTTP for localhost/127.0.0.1.

Use a maintained reverse proxy / hosting platform with TLS, body limits,
connection limits, request timeouts, and edge rate limits. Do not expose Python's
standard-library development HTTP server directly to the public internet.
The service serializes requests around SQLite and external API calls: suitable
for local integration and a small pilot, not a high-availability deployment.
Move the HTTP boundary to a production ASGI service and migrate to Postgres as
usage grows; the iOS API boundary is isolated for that transition.

The service deliberately ignores X-Forwarded-For. Behind a proxy its IP limit
may aggregate all users; apply per-client limits at the trusted edge instead of
blindly trusting a spoofable header. Account limits still run in the application.
In-memory rate counters reset on restart and are not shared across replicas.
Use a durable shared limiter before public deployment. Add provider budgets and
an operational circuit breaker to cap email/AI costs.

## Identity

- Exact email domain allowlist; no suffix matching and no client-chosen role.
- Six-digit secure random codes, ten-minute expiry, maximum five guesses.
- Code requests limited per IP and mailbox; codes stored as HMAC digests.
- 256-bit random bearer sessions, HMAC stored server-side, seven-day expiry.
- Raw session on device stored in Keychain; sign-out revokes server session.
- Users default to `Student` with `Not set` year. An operator assigns a verified
  Teacher or Mentor role after independent verification.
- No real school domain is bundled. The repository makes no assumption that
  a particular domain is exclusively used by active students or staff.
- Reverify school membership each term and add operator account suspension,
  offboarding, and session revocation before broad rollout.

## Moderation

Posts, replies, profiles and private messages are reviewed on the server using
`POST https://api.openai.com/v1/moderations` with `omni-moderation-latest`.
The app cannot select `published` status or pin its own content. Review failure
returns 503 and stores no published content. Flagged posts/replies are retained
as pending. Flagged profiles/messages are rejected with an edit-and-retry error.
A basic email/phone heuristic also routes posts to human review; it can have
false positives and is not a comprehensive privacy filter.

Document clearly in the live privacy notice that submitted text, including
private messages, is processed by the AI provider. This application does not
provide end-to-end encrypted messaging. Network transport must use HTTPS,
and hosting/storage encryption and access controls are deployment duties.
Never present this as a confidential counseling channel.

Operator commands (run from `server`, with access to the server DB):

```sh
python3 admin.py pending
python3 admin.py reports
python3 admin.py review post POST_ID published
python3 admin.py review reply REPLY_ID rejected
python3 admin.py group verified-student@confirmed-domain international add
python3 admin.py role verified-staff@confirmed-domain Teacher
python3 admin.py pin POST_ID 48
python3 admin.py resolve-report REPORT_ID
```

These are syntax examples; replace IDs and addresses with actual verified data.
Commands record mutation actions in an audit table. These local commands assume
OS-level operator authentication; a later moderation web app needs its own
role-based permissions, reason capture and auditable operator identity.

## Visibility and privacy

The server checks group membership on both reads and writes. Choosing a response
group alone does not restrict readership. School-visible questions may target
mentors without making the question private. Group-only publication requires
membership. Nonmembers receive 404 on reply/report attempts to hidden posts.
Anonymous post responses omit the author object and any author ID; the private
DB association is used for abuse response. Blocking suppresses posts in either
direction and prevents sending/starting chats in either direction.
No email address appears in public profile JSON. Authenticated bootstrap only
includes the caller's conversations, and send-message checks membership again.

## API contract

All bodies and responses use JSON. Authenticated requests use `Authorization:
Bearer <token>`; API errors are `{ "error": "human readable message" }`.

| Method/path | Body / purpose |
|---|---|
| POST /auth/request | `{email}`; sends OTP to an allowed mailbox |
| POST /auth/verify | `{email, code}`; returns `{token}` |
| POST /auth/logout | Revokes current bearer token |
| GET /bootstrap | `{me, groups, posts, conversations}` authorized snapshot |
| PATCH /profile | `{name, year, bio, instagram}`; role/id ignored |
| POST /posts | `{title, body, kind, anonymous, groupID, visibility}` |
| POST /posts/:id/replies | `{body}` |
| POST /conversations | `{peerID}`; returns conversation |
| POST /conversations/:id/messages | `{body}`; member-only write |
| POST /reports | `{postID, reason}` |
| POST /blocks | `{userID}`; blocks both directions of messaging |

SQLite uses parameterized values. HTTP bodies are limited to 20 KB and text
fields have individual caps. Handler logging intentionally omits user content,
email addresses and tokens. Add safe operational telemetry before deployment.

Use the SQLite backup API for consistent backups (especially in WAL mode),
restrict database access to the service/operator, encrypt backup storage and
test restore procedures. Keep the HMAC secret stable across restarts; rotating
it invalidates all codes and sessions. Never put `.env` or real SQLite files in
a code archive or public repository.
