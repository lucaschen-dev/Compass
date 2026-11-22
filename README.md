# Compass

Compass is a Flutter school community demo for Alderline and Cedarbrook. The hosted preview is available at [Compass](https://compass-lucas.lucasinus.chatgpt.site). The Site is private to its owner and uses ChatGPT sign-in at the hosting boundary.

## Experience

- A minimal Compass welcome screen, a centered **Find Your School** button, and a searchable alphabetical school list.
- Firebase Auth supports **Continue with Google** and school-specific email/password sign-in. New accounts choose a demo school and complete name and grade onboarding. Sessions survive refresh.
- A school arrival animation fades in Compass and the school mark, then moves both into the Home header. The same brand elements remain mounted in the header, with stable type and color throughout the movement. Reduced-motion preferences are respected.
- Four destinations: **Home**, **Guide**, **Chat**, and **Courses**. Desktop navigation highlights the entire icon-and-label row. The personal center is at the upper left. Appearance settings live inside the personal center.
- Home carries Latest and For you feeds, six post categories, category/subtag filters, keyword search, topic recommendations, comments, likes, saved posts, anonymous posts, targeted questions, priorities, gallery posts, and composer drafts. For example, follow **Clubs → Badminton** to recommend badminton posts. Existing interest/time preferences still recommend sample peers, clubs, and events.
- Home includes a **First week** launcher for the calendar, adviser and classroom directory, clubs, and school connections.
- **Campus photos** groups Photo Gallery posts by date. Example albums show how Student Council and Photography Club could use the gallery. Demo school accounts can share up to four compressed photos per post with their school. This feature uses the existing shared posts collection.
- A centered editable profile photo, full name, grade, bio, Posts/Saved/About sections, and settings.
- Guide separates **Dress code**, **Grade**, **Faculty & classrooms**, **Campus life**, and **Course catalog**. Guide reading progress and course search remain available.
- **Add friend** in Chat and **Friends and requests** in the personal center connect Firebase accounts in the same Compass school. Search for people who chose to show their name, or enter a Compass code. A request becomes a friendship only after the recipient accepts it. The Requests view supports accepting, declining and canceling pending requests. The local preview still uses sample classmates.
- Demo Chat supports direct and group conversations, swipe-to-reply, message actions, reactions, drafts, local photo attachments, and block controls. Profile → Settings → Privacy shows blocked demo chats and lets users unblock them. Messages in these conversations do not reach other people, and cloud backups do not use end-to-end encryption.
- Courses provides **Month**, **Week**, and **Day** views, day agendas, calendar details, local ICS import, and folded **Graduation Requirements**. The existing manual requirement calculations are preserved.

## Email service status

Firebase Auth manages sign-in. **Send setup email** and **Send reset email** report that email delivery is unavailable. The two fictional schools use fixed `alderline.example` and `cedarbrook.example` suffixes for email/password. Google accounts can choose a fictional school during onboarding.

A real school rollout requires verified membership, server-managed publisher roles, and a process for handling reported content and photos.

## Calendar subscriptions

On the first visit to Courses, Compass asks for the student's own private WebCal/HTTPS link. Connecting succeeds only after a valid feed is fetched and saved. It refreshes when Courses opens or resumes and every 15 minutes while that page remains open; it does not run a background service after the app closes. Manual refresh is also available. If an update fails, the last successful snapshot remains visible. A file import is a snapshot until a subscription is connected.

The hosted app fetches calendars through a same-origin Cloudflare Worker, avoiding browser CORS restrictions. The gateway requires the hosting platform's authenticated identity, permits only known hosted calendar providers, rejects redirects and non-HTTPS destinations, limits request/feed sizes, applies a timeout, forwards no visitor credentials, and returns `private, no-store`. Native builds can fetch the same allowed HTTPS providers directly. Supported providers are MySchoolApp, Google Calendar, Outlook, and public iCloud calendar hosts. Other providers can use file import until explicitly supported.

Imports are limited to 512 KB and 2,000 expanded events. The parser handles all-day exclusive end dates, timed events, IANA timezones, cancellations, revised entries, folded text, and escaped HTML entities. Recurring event rules/overrides must currently be exported as individual occurrences. Timezone transition rules are not calendar events.

Private subscription URLs and ICS snapshots stay in the browser's school- and account-scoped local storage and are never bundled into source or published assets. Calendar content is fetched on demand and is not retained by the gateway. Keep subscription URLs private. Disconnecting retains a snapshot; **Use sample calendar** removes the current account's import.

Calendar events do not automatically change requirement completion. Event-to-course matching for `requirementsChecklist` remains future work.

## Data separation

Storage follows `compass.preview.<school-id>...`. Guide, requirement and preference settings use school-scoped device keys. Sample contacts, private calendar subscriptions and chat caches use account-scoped keys. Real connections sync from Firestore and require an accepted request. Sample contacts never become real friendships. Private account profiles remain owner-readable. People can opt into the directory with their name and turn visibility off again. A pre-login calendar is migrated to the first local account only. Appearance is an app preference. Local storage belongs to the browser and origin.

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
