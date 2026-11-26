import assert from 'node:assert/strict';
import { test } from 'node:test';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { eraseCompassAccount } from './account-deletion.js';

const emulator = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST,
);

test('account deletion clears fixtures, preserves other users and confirms completion',
  { skip: !emulator },
  async () => {
    const app = initializeApp({ projectId: 'demo-compass-deletion' });
    try {
      const database = getFirestore(app);
      const auth = getAuth(app);
      const email = 'leaving@review.example';
      const leaving = await auth.createUser({ email, emailVerified: true });
      const staying = await auth.createUser({ email: 'staying@review.example' });
      const uid = leaving.uid;
      const other = staying.uid;
      const receipt = '0'.repeat(48);
      const jobPath = `accountDeletionRequests/${uid}`;
      const receiptPath = `accountDeletionReceipts/${receipt}`;
      const schoolPath = 'schools/review-fixture';
      const myPost = `${schoolPath}/posts/my-post`;
      const otherPost = `${schoolPath}/posts/other-post`;
      const chat = `${schoolPath}/friendRequests/review-pair`;
      const erase = {
        [jobPath]: { status: 'pending', receipt },
        [receiptPath]: { status: 'pending' },
        [`users/${uid}`]: { schoolId: 'review-fixture', email },
        [`users/${uid}/schools/review-fixture/blocked/${other}`]: { displayName: 'Peer', targetUid: other },
        [`users/${other}/schools/review-fixture/blocked/${uid}`]: { displayName: 'Student', targetUid: uid },
        [`users/${uid}/schools/review-fixture/threads/thread/messages/message`]: { text: 'Old chat' },
        [`schoolApplications/${uid}`]: { applicantEmail: email },
        [`${schoolPath}/directory/${uid}`]: { name: 'Student' },
        [`${schoolPath}/photoSubmissions/pending-album`]: { authorId: uid, status: 'pending' },
        [`${schoolPath}/moderationReports/about`]: { targetUid: uid, reporterId: other },
        [`${schoolPath}/moderationReports/by`]: { targetUid: other, reporterId: uid },
        [myPost]: { authorId: uid },
        [`${myPost}/replies/comment`]: { authorId: other },
        [`${otherPost}/replies/comment`]: { authorId: uid },
        [chat]: { participants: [uid, other] },
        [`${chat}/messages/message`]: { senderId: uid, text: 'A direct message' },
      };
      const keep = {
        [`users/${other}`]: { schoolId: 'review-fixture' },
        [otherPost]: { authorId: other },
        [`${otherPost}/replies/other-comment`]: { authorId: other },
      };
      const batch = database.batch();
      for (const [path, data] of Object.entries({ ...erase, ...keep })) {
        batch.set(database.doc(path), data);
      }
      await batch.commit();

      await assert.rejects(
        () => eraseCompassAccount(database, {
          deleteUser: async () => { throw new Error('temporary failure'); },
        }, uid), /temporary failure/,
      );
      assert.equal((await database.doc(jobPath).get()).get('status'), 'pending');
      assert.equal((await database.doc(receiptPath).get()).get('status'), 'pending');
      assert.equal(await eraseCompassAccount(database, auth, uid), true);
      assert.equal(await eraseCompassAccount(database, auth, uid), false);
      assert.equal((await database.doc(jobPath).get()).get('status'), 'completed');
      assert.equal((await database.doc(receiptPath).get()).get('status'), 'completed');
      for (const path of Object.keys(erase).filter((path) =>
        path !== jobPath && path !== receiptPath)) {
        assert.equal((await database.doc(path).get()).exists, false, path);
      }
      for (const path of Object.keys(keep)) {
        assert.equal((await database.doc(path).get()).exists, true, path);
      }
      await assert.rejects(() => auth.getUser(uid), { code: 'auth/user-not-found' });
      assert.equal((await auth.getUser(other)).uid, other);
    } finally {
      await deleteApp(app);
    }
  },
);
