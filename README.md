# Compass

Compass is a Flutter school community demo for Alderline and Cedarbrook. The hosted preview is available at [Compass](https://compass-lucas.lucasinus.chatgpt.site). The Site is private to its owner and uses ChatGPT sign-in at the hosting boundary.

## Experience

- A minimal Compass welcome screen, a centered **Find Your School** button, and a searchable alphabetical school list.
- School-specific demo login with a fixed email suffix. **First login** offers local demo account creation, password setup, and full-name/grade onboarding. Passwords are stored as salted PBKDF2-SHA256 hashes, never plaintext. Sessions survive refresh.
- A school arrival animation fades in Compass and the school mark, then moves both into the Home header. Reduced-motion preferences are respected.
- Four destinations: **Home**, **Guide**, **Chat**, and **Courses**. The personal center is at the upper left. Appearance settings live inside the personal center.
- Home carries Latest and For you feeds, six post categories, category/subtag filters, keyword search, topic recommendations, comments, likes, saved posts, anonymous posts, targeted questions, priorities, gallery posts, and composer drafts. For example, follow **Clubs → Badminton** to recommend badminton posts. Existing interest/time preferences still recommend sample peers, clubs, and events.
- A centered editable profile photo, full name, grade, bio, Posts/Saved/About sections, and settings.
- Guide separates **Dress code**, **Grade**, **Faculty & classrooms**, **Campus life**, and **Course catalog**. Guide reading progress and course search remain available.
- Chat includes direct/group conversations, search, unread/group/archive filters, drafts, quoted replies, editing, reactions, photo attachments, copy, delete-for-me, two-minute unsend, mute, pin, archive, and leaving/blocking a conversation. Messages and photos are local demo data; they are not delivered to other people. No calls, push delivery, or shared realtime messaging service is configured.
- Courses provides **Month**, **Week**, and **Day** views, day agendas, calendar details, local ICS import, and folded **Graduation Requirements**. The existing manual requirement calculations are preserved.

## Email service status

No email/identity delivery provider has been configured. **Send setup email** and **Send reset email** explicitly report that no email was sent. The local demo account option is labeled as such and does not verify school membership. The two fictional schools use reserved `alderline.example` and `cedarbrook.example` suffixes; users cannot edit them.

Real school access requires an identity provider, verified school-domain configuration, actual setup/recovery email delivery, and server-enforced membership. The local demo login must not be treated as production authentication.

## Calendar subscriptions

On the first visit to Courses, Compass asks for the student's own private WebCal/HTTPS link. Connecting succeeds only after a valid feed is fetched and saved. It refreshes when Courses opens or resumes and every 15 minutes while that page remains open; it does not run a background service after the app closes. Manual refresh is also available. If an update fails, the last successful snapshot remains visible. A file import is a snapshot until a subscription is connected.

The hosted app fetches calendars through a same-origin Cloudflare Worker, avoiding browser CORS restrictions. The gateway requires the hosting platform's authenticated identity, permits only known hosted calendar providers, rejects redirects and non-HTTPS destinations, limits request/feed sizes, applies a timeout, forwards no visitor credentials, and returns `private, no-store`. Native builds can fetch the same allowed HTTPS providers directly. Supported providers are MySchoolApp, Google Calendar, Outlook, and public iCloud calendar hosts. Other providers can use file import until explicitly supported.

Imports are limited to 512 KB and 2,000 expanded events. The parser handles all-day exclusive end dates, timed events, IANA timezones, cancellations, revised entries, folded text, and escaped HTML entities. Recurring event rules/overrides must currently be exported as individual occurrences. Timezone transition rules are not calendar events.

Private subscription URLs and ICS snapshots stay in the browser's school- and account-scoped local storage and are never bundled into source or published assets. Calendar content is fetched on demand and is not retained by the gateway. Keep subscription URLs private. Disconnecting retains a snapshot; **Use sample calendar** removes the current account's import.

Calendar events do not automatically change requirement completion. Event-to-course matching for `requirementsChecklist` remains future work.

## Data separation

Storage follows `compass.preview.<school-id>...`. Existing school guide, friend, requirement, preference, and calendar keys are preserved. New profile/post/chat/topic/calendar data is additionally scoped to each demo account. A pre-login calendar is migrated to the first local account only; resetting it does not restore legacy data. Appearance is an app preference. Local storage belongs to the browser and origin; it does not transfer automatically between localhost, the hosted Site, browsers, or devices.

## Develop

```sh
flutter pub get
flutter analyze
flutter test
npm --prefix server ci
npm --prefix server test
```

For browser development with the calendar gateway:

```sh
flutter build web --no-web-resources-cdn
npm --prefix server run dev
```

The dev server listens on `127.0.0.1:8767`. Its demo identity exemption applies only to localhost development and is absent from production builds. Use the printed preview address in a browser. Inter is bundled under the SIL Open Font License; the design uses Light body text, restrained headings, and a code-native outline compass mark.

## Publish

`.openai/hosting.json` retains the existing Site identity. Run `npm run build` to build Flutter, package separate static assets with the Cloudflare Vite plugin, and emit the Worker at `dist/server/index.js`. Publish through the Sites source/version workflow; keep the Site's current audience. Source changes are maintained on [GitHub](https://github.com/lucaschen-dev/Compass).
