# Compass development plan

Build on the existing Flutter project and review each iteration in the [browser](README.md#run-in-a-browser). The app uses fictional school data and stores demo state locally.

## Current app

- Choose Alderline or Cedarbrook through **Find your school** and switch schools from the top bar. Each school has its own announcements, course catalog, graduation requirements, campus guide, sample conversations, and student profile.
- Search courses by title or subject and view credits and prerequisites. The browser remembers the selected school and saves guide reading progress and added classmates separately for each school.
- The homepage has a school wordmark, **Important** and **Latest posts**, a floating mobile tab bar, and neutral light and dark modes.

## Next iterations

1. Add a local academic planner that tracks completed credits against each school's requirements and checks prerequisites for planned courses.
2. Let students enter preferences and use them to recommend sample peers, clubs, and events.
3. Add local community interactions such as creating, replying to, and saving posts and sending demo messages.

Review each iteration in both themes at phone and desktop widths. Check that switching schools keeps data separate and refreshing restores saved changes.
