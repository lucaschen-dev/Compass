import assert from 'node:assert/strict';
import test from 'node:test';
import { reviewNotice, sendReviewNotice } from './review-notice.js';

const configuration = {
  projectId: 'demo-compass',
  applicationId: 'application-1',
  schoolName: 'West Ridge\nAcademy',
  from: 'Compass <notices@school.example>',
  to: 'reviewer@school.example',
};

test('review emails use the fixed recipient and link to the authenticated review console', () => {
  const notice = reviewNotice(configuration);
  assert.deepEqual(notice.to, [configuration.to]);
  assert.equal(notice.subject, 'Compass school application: West Ridge Academy');
  assert.match(notice.text, /https:\/\/console\.firebase\.google\.com\/project\/demo-compass/);
  assert.match(notice.text, /schoolApplications\/application-1/);
});

test('retries preserve the email idempotency key', async () => {
  const keys = [];
  const notice = reviewNotice(configuration);
  const fetchImpl = async (_url, request) => {
    keys.push(request.headers['Idempotency-Key']);
    const status = keys.length === 1 ? 429 : 200;
    return new Response('{}', { status });
  };
  const delivery = { apiKey: 'test', applicationId: configuration.applicationId, fetchImpl };
  await assert.rejects(sendReviewNotice(notice, delivery), /429/);
  assert.equal(await sendReviewNotice(notice, delivery), 'sent');
  assert.deepEqual(keys, ['compass-school-review/application-1', 'compass-school-review/application-1']);
});

test('a permanent provider rejection remains a failed notification', async () => {
  const result = await sendReviewNotice(reviewNotice(configuration), {
    apiKey: 'test',
    applicationId: configuration.applicationId,
    fetchImpl: async () => new Response('{}', { status: 403 }),
  });
  assert.equal(result, 'failed');
});
