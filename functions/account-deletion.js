import { Timestamp } from 'firebase-admin/firestore';

const tombstoneHours = 24;

async function deleteMatches(query, remove) {
  for (;;) {
    const found = await query.limit(100).get();
    if (found.empty) return;
    for (const document of found.docs) await remove(document.ref);
  }
}

export async function eraseCompassAccount(database, auth, uid) {
  const jobs = database.collection('accountDeletionRequests');
  const job = jobs.doc(uid);
  const request = await job.get();
  if (!request.exists || request.get('status') !== 'pending') return false;

  const user = database.collection('users').doc(uid);
  const profile = await user.get();
  const schoolId = profile.get('schoolId');
  if (typeof schoolId === 'string') {
    const school = database.collection('schools').doc(schoolId);
    await deleteMatches(school.collection('posts').where('authorId', '==', uid),
      (ref) => database.recursiveDelete(ref));
    await deleteMatches(school.collection('friendRequests')
      .where('participants', 'array-contains', uid),
    (ref) => database.recursiveDelete(ref));

    await deleteMatches(school.collection('photoSubmissions')
      .where('authorId', '==', uid), (ref) => ref.delete());
    const reports = school.collection('moderationReports');
    await deleteMatches(reports.where('reporterId', '==', uid), (ref) => ref.delete());
    await deleteMatches(reports.where('targetUid', '==', uid), (ref) => ref.delete());
    await school.collection('directory').doc(uid).delete();
  }

  await deleteMatches(database.collectionGroup('replies').where('authorId', '==', uid),
    (ref) => ref.delete());
  await deleteMatches(database.collectionGroup('blocked').where('targetUid', '==', uid),
    (ref) => ref.delete());
  await database.collection('schoolApplications').doc(uid).delete();
  await database.recursiveDelete(user);

  // Leave the write lock behind until old Firebase ID tokens have expired.
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  const batch = database.batch();
  batch.set(job, {
    status: 'completed',
    expiresAt: Timestamp.fromMillis(Date.now() + tombstoneHours * 60 * 60 * 1000),
  });
  batch.set(database.collection('accountDeletionReceipts').doc(request.get('receipt')), {
    status: 'completed',
    expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
  });
  await batch.commit();
  return true;
}

export async function purgeCompletedDeletionRequests(database) {
  await deleteMatches(database.collection('accountDeletionRequests')
    .where('expiresAt', '<=', Timestamp.now()), (ref) => ref.delete());
  await deleteMatches(database.collection('accountDeletionReceipts')
    .where('expiresAt', '<=', Timestamp.now()), (ref) => ref.delete());
}
