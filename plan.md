# Compass development plan

Build on the existing Flutter project and review each iteration in the [browser](README.md#run-in-a-browser). The app uses fictional school data and stores demo state locally.

## Current app

- Choose Alderline or Cedarbrook through **Find your school** and switch schools from the top bar. Each school has its own announcements, course catalog, graduation requirements, campus guide, sample conversations, and student profile.
- Search courses by title or subject and view credits and prerequisites. The browser remembers the selected school and saves guide reading progress and added classmates separately for each school.
- The homepage has a school wordmark, **Important** and **Latest posts**, a floating mobile tab bar, and neutral light and dark modes.
- **For you** lets students save interests and a preferred meetup time separately for each school. Shared interests recommend sample classmates, clubs, and events; meetup time filters clubs and events. Preferences survive refreshes and can be edited or reset.
- **Courses** has a school calendar above Graduation Requirements. Read-only ICS imports stay local and separate by school; sample calendars remain available. The searchable course catalog is at the bottom of **Guide**.

## Iterations

1. Add a local academic planner that tracks completed credits against each school's requirements and checks prerequisites for planned courses.
2. **Completed:** Let students enter preferences and use them to recommend sample peers, clubs, and events. Includes school-scoped local storage, match reasons, editable preferences, and empty states when nothing matches.
3. Add local community interactions such as creating, replying to, and saving posts and sending demo messages.

Review each iteration in both themes at phone and desktop widths. Check that switching schools keeps data separate and refreshing restores saved changes.

## Later

- Calendar events should eventually update completed courses that fulfill items in `requirementsChecklist`. The current calendar does not change requirement progress automatically.
