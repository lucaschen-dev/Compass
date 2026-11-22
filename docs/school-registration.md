# School registration and review

The welcome page offers **Find Your School**, **Register**, and **Sign in**. Applicants enter the school name, email domain, their name and role, and a school contact email. Location and school color are optional. A verified Google sign-in identifies the applicant. The school contact email must have the requested school domain. The reviewer confirms that the contact and applicant are authorized to register the school.

## Review a request

Open `schoolApplications` in the Firebase Console with a project administrator account. The application document ID identifies the applicant, and the record shows the verified applicant email and the school contact you should verify.

With existing Google Cloud application-default credentials authorized for the project, run the review tool from the repository root.

```sh
npm --prefix functions ci
node functions/review-school.js compass-database-480ea APPLICATION_ID approve
```

Use `reject` for an application that fails review. Approval writes the registry entry and changes the application status in one transaction. It keeps contact details in the private application record. An approved school appears in **Find Your School** on its next load. New members complete Google sign-in using their verified email on that exact school domain.

## Turn on reviewer email

Set up a Resend sender with a verified domain. Use the **COMPASS_SCHOOL_FROM_EMAIL** and **COMPASS_SCHOOL_REVIEW_EMAIL** parameters for that sender and the reviewer’s existing mailbox. Store the provider key only as a Firebase secret. An administrator enables the function on a Firebase plan that supports Cloud Functions.

```sh
firebase functions:secrets:set COMPASS_SCHOOL_RESEND_KEY --project compass-database-480ea
firebase deploy --only functions:school-review --project compass-database-480ea
```

The function listens for new applications, sends the school name and a link to the authenticated review console, and records the delivery state in Firebase. Retries reuse the same email idempotency key. Applications received before the function is enabled remain available for manual review.
