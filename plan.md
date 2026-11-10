# Compass plan

Continue the existing Flutter app and preserve school-scoped data.

## Current iteration

- Minimal outline Compass branding and restrained Inter Light typography. Compass is centered at the top of the welcome; Find Your School is centered on the page. No welcome artwork or promotional small text.
- Alphabetical searchable school picker for Alderline and Cedarbrook.
- School-domain-locked local demo login, password/full-name/grade onboarding, persisted sessions, and honest unconfigured setup/recovery email states.
- Continuous Compass/school arrival into the shared header, with stable color/type and reduced-motion support. Desktop navigation selects the full icon-and-label row.
- Four-page navigation; the personal center is upper left, and theme controls are inside its settings.
- Home includes Latest/For you, six Buckley-inspired post categories, new subtags, topic recommendations, saved/my posts, comments, anonymous posting, targeted questions, priorities, gallery images, and drafts. Existing peer/club/event preference recommendations remain available inside Home.
- A centered editable profile with Posts/Saved/About sections.
- Guide is divided into Dress code, Grade, Faculty & classrooms, Campus life, and Course catalog.
- Local direct/group chat supports replies, editing, unsend, reactions, photos, drafts, search, unread/archive/group filters, pin/mute/archive, copy, delete-for-me, and leave/block actions.
- Courses has live WebCal connection, local import, Month/Week/Day views, offline snapshots, and collapsed manual Graduation Requirements.
- Maintain and publish the existing fixed Site, then push the reviewed source changes to GitHub.

## Verification

Review entry/login, Home, profile/settings, Guide, Chat, and Courses at phone and desktop widths in light/dark themes. Check school/account isolation, saved state after restart, incorrect passwords/domains, failed writes, calendar retry/cache behavior, and existing requirement totals. Validate the hosted gateway and static assets after publication. Never commit personal calendar links, imports, or credentials.

## Later / needs external services

- Configure a real identity/email provider before enabling setup/recovery delivery or claiming verified school membership.
- Shared realtime posts/chats, media storage, moderation/report delivery, notifications, and calls require connected services. The current two-school experience remains a local demo.
- Calendar events should eventually update completed courses that fulfill `requirementsChecklist`; this iteration does not automate requirement progress.
