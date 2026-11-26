# School registration and review

The welcome page offers **Find Your School**, **Register**, and **Sign in**. Applicants enter the school name, email domain, their name and role, and a school contact email. Location and school color are optional. On iPhone and Mac, the applicant signs in to Compass with the verified school contact email. On the web, an applicant can use a verified Google account. The school contact email must have the requested school domain. The reviewer confirms that the contact and applicant are authorized to register the school.

Enable **Email/Password** under Authentication → Sign-in method in the Firebase console before distributing the iPhone or Mac build. Compass uses Firebase Authentication's built-in verification and password-reset emails for sign-in. Check that both reach a test school mailbox before submitting a build. An existing Google user can enter the original account email under **Sign in** and choose **Set or reset Compass password** to set a password on the existing account. Verify this migration with a test account on the deployed Firebase project before release.

## Review a request

Open `schoolApplications` in the Firebase Console with a project administrator account. The application document ID identifies the applicant, and the record shows the verified applicant email and the school contact you should verify.

With existing Google Cloud application-default credentials authorized for the project, run the review tool from the repository root.

```sh
npm --prefix functions ci
node functions/review-school.js compass-database-480ea APPLICATION_ID approve
```

Use `reject` for an application that fails review. Approval writes the registry entry and changes the application status in one transaction. It keeps contact details in the private application record. An approved school appears in **Find Your School** on its next load. New members verify an email on that exact school domain before creating a school profile.

## Turn on reviewer email

Set up a Resend sender with a verified domain. Use the **COMPASS_SCHOOL_FROM_EMAIL** and **COMPASS_SCHOOL_REVIEW_EMAIL** parameters for that sender and the reviewer’s existing mailbox. Store the provider key only as a Firebase secret. An administrator enables the function on a Firebase plan that supports Cloud Functions.

```sh
firebase functions:secrets:set COMPASS_SCHOOL_RESEND_KEY --project compass-database-480ea
firebase deploy --only functions:school-review --project compass-database-480ea
```

The function listens for new applications, sends the school name and a link to the authenticated review console, and records the delivery state in Firebase. Retries reuse the same email idempotency key. Applications received before the function is enabled remain available for manual review.
