# Compass development plan

Build on the existing Flutter project in VS Code and review each iteration in the browser. Start with the login screen and page navigation, then add fictional school data, then make the interactions work.

## Iteration 1 · Basic UI and navigation

1. Set up the welcome and login screens using the existing Compass layout.
2. Connect **Home**, **Chat**, and **Profile**. Use empty states so we can review the layout and navigation before adding content.
3. Set up light and dark themes and check the screens at phone and desktop widths.

**Ready to review when** you can open the browser preview, reach every page from the welcome screen, and switch between light and dark mode.

## Iteration 2 · Fictional school data

1. Create one fictional school with a sample student profile, school announcements, feed posts, and conversations.
2. Load that data through the existing **Explore the demo** entry so you can browse the app without signing in.
3. Check that the school name, student profiles, posts, and conversations are consistent across pages.

**Ready to review when** you can browse a populated feed, open a conversation, and view a sample profile.

## Iteration 3 · Working demo interactions

1. Wire up creating a post, replying, saving a post, and sending a demo message using the existing Flutter logic.
2. Save demo changes locally so they survive a browser refresh.
3. Add clear feedback for empty submissions, successful actions, and errors. Test the full path from opening the demo to returning to a conversation you edited.

**Ready to review when** you can post, reply, and send a demo message, then refresh and see your changes.

## Iteration 4 · Visual polish and browser testing

1. Refine typography, spacing, and page layouts using what we learn from the first three reviews.
2. Verify login navigation, demo interactions, and saved state in both themes at phone and desktop widths.
3. Run the existing Flutter checks and leave a working browser preview for the next review.
