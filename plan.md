# Compass plan

Continue the existing Flutter app and preserve school-scoped data.

## Current iteration

- Minimal outline Compass branding and restrained Inter Light typography. Compass is centered at the top of the welcome; Find Your School is centered on the page. No welcome artwork or promotional small text.
- Alphabetical searchable school picker for Alderline and Cedarbrook.
- Firebase sign-in for the two fictional schools, including Google sign-in and name/grade onboarding. Setup and recovery email delivery is pending.
- Continuous Compass/school arrival into the shared header, with stable color/type and reduced-motion support. Desktop navigation selects the full icon-and-label row.
- Four-page navigation; the personal center is upper left, and theme controls are inside its settings.
- Home includes Latest/For you, six Buckley-inspired post categories, new subtags, topic recommendations, saved/my posts, comments, anonymous posting, targeted questions, priorities, gallery images, and drafts. Existing peer/club/event preference recommendations remain available inside Home.
- First week on Home links to the calendar, advisers and classrooms, clubs, and the sample classmate directory.
- Campus photos collects dated Photo Gallery posts, with sample organization albums and compressed school-shared uploads.
- A centered editable profile with Posts/Saved/About sections and a Privacy screen for blocked demo chats.
- Guide is divided into Dress code, Grade, Faculty & classrooms, Campus life, and Course catalog.
- Demo direct and group conversations have a visible Add friend directory, swipe-to-reply, reactions, and account-scoped private backups.
- Courses has live WebCal connection, local import, Month/Week/Day views, offline snapshots, and collapsed manual Graduation Requirements.
- Maintain and publish the existing fixed Site, then push the reviewed source changes to GitHub.

## Verification

Review entry/login, Home, profile/settings, Guide, Chat, and Courses at phone and desktop widths in light/dark themes. Check school/account isolation, saved state after restart, incorrect passwords/domains, failed writes, calendar retry/cache behavior, and existing requirement totals. Validate the hosted gateway and static assets after publication. Never commit personal calendar links, imports, or credentials.

## Later / needs external services

- Configure email setup/recovery and verify real school memberships before using the app for a school rollout.
- Verified organization publishing, reporting and moderation, and live student messaging with reviewed encryption remain future work.
- Calendar events should eventually update completed courses that fulfill `requirementsChecklist`; this iteration does not automate requirement progress.
