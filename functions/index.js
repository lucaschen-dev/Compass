import { initializeApp } from 'firebase-admin/app';
import { FieldValue } from 'firebase-admin/firestore';
import { defineSecret, defineString, projectID } from 'firebase-functions/params';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { reviewNotice, sendReviewNotice } from './review-notice.js';

initializeApp();

const apiKey = defineSecret('COMPASS_SCHOOL_RESEND_KEY');
const reviewEmail = defineString('COMPASS_SCHOOL_REVIEW_EMAIL');
const senderEmail = defineString('COMPASS_SCHOOL_FROM_EMAIL');

export const notifySchoolReview = onDocumentCreated(
  {
    document: 'schoolApplications/{applicationId}',
    region: 'us-central1',
    retry: true,
    secrets: [apiKey],
  },
  async (event) => {
    if (!event.data) return;
    const ref = event.data.ref;
    const application = (await ref.get()).data();
    if (!application || application.status !== 'pending' ||
        application.reviewNotification?.status) {
      return;
    }

    // Resend deduplicates a key for 24 hours. End retries before that window
    // ends so a late delivery event cannot trigger a second reviewer email.
    const elapsed = Date.now() - new Date(event.time).getTime();
    const applicationId = event.params.applicationId;
    const status = elapsed < 23 * 60 * 60 * 1000
      ? await sendReviewNotice(
          reviewNotice({
            projectId: projectID.value(),
            applicationId,
            schoolName: application.schoolName,
            from: senderEmail.value(),
            to: reviewEmail.value(),
          }),
          { apiKey: apiKey.value(), applicationId },
        )
      : 'failed';

    await ref.update({
      reviewNotification: { status, updatedAt: FieldValue.serverTimestamp() },
    });
  },
);
