import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const [projectId, schoolId, postId, action = '--inspect', ...extra] = process.argv.slice(2);
if (!projectId || !/^[a-z0-9][a-z0-9-]{0,79}$/.test(schoolId ?? '') ||
    !/^[A-Za-z0-9_:-]{1,257}$/.test(postId ?? '') ||
    !['--inspect', '--approve', '--reject'].includes(action) || extra.length) {
  console.error('Usage: node functions/review-photo-submission.js PROJECT_ID SCHOOL_ID POST_ID [--inspect|--approve|--reject]');
  process.exit(1);
}

const app = initializeApp({ credential: applicationDefault(), projectId });
const database = getFirestore(app);
const school = database.collection('schools').doc(schoolId);
const submission = school.collection('photoSubmissions').doc(postId);
const post = school.collection('posts').doc(postId);
const pngSignature = '89504e470d0a1a0a';

function reviewedPhotos(photos) {
  if (!Array.isArray(photos) || photos.length < 1 || photos.length > 4) {
    throw new Error('Submission does not have a supported photo count.');
  }
  return photos.map((photo) => {
    if (typeof photo !== 'string' || photo.length > 160000 ||
        !/^iVBORw0KGgo[A-Za-z0-9+/]+={0,2}$/.test(photo)) {
      throw new Error('Submission has an invalid photo.');
    }
    const data = Buffer.from(photo, 'base64');
    if (data.length < 33 || data.toString('base64') !== photo ||
        data.subarray(0, 8).toString('hex') !== pngSignature ||
        data.readUInt32BE(8) !== 13 || data.toString('ascii', 12, 16) !== 'IHDR' ||
        !data.readUInt32BE(16) || data.readUInt32BE(16) > 720 ||
        !data.readUInt32BE(20) || data.readUInt32BE(20) > 720) {
      throw new Error('Submission has an invalid PNG header or dimensions.');
    }
    return data;
  });
}

function pendingSubmission(snapshot) {
  const data = snapshot.data();
  if (!data || data.status !== 'pending' || data.id !== postId ||
      data.category !== 'gallery' || typeof data.authorId !== 'string') {
    throw new Error('No pending photo submission matches this school and post.');
  }
  return data;
}

if (action === '--inspect') {
  const album = pendingSubmission(await submission.get());
  const photos = reviewedPhotos(album.photos);
  const folder = await mkdtemp(join(tmpdir(), 'compass-photo-review-'));
  await Promise.all([
    writeFile(join(folder, 'album.json'), JSON.stringify({
      title: album.title,
      caption: album.body,
      submitter: album.authorId,
    }, null, 2), { mode: 0o600 }),
    ...photos.map((photo, index) => writeFile(
      join(folder, `photo-${index + 1}.png`), photo, { mode: 0o600 },
    )),
  ]);
  console.log(`Private review copies saved to ${folder}`);
} else {
  await database.runTransaction(async (transaction) => {
    const album = pendingSubmission(await transaction.get(submission));
    if (action === '--approve') {
      reviewedPhotos(album.photos);
      const marker = database.collection('accountDeletionRequests').doc(album.authorId);
      const owner = database.collection('users').doc(album.authorId);
      const [deletion, profile] = await transaction.getAll(marker, owner);
      if (deletion.exists || profile.get('schoolId') !== schoolId) {
        throw new Error('The submitter no longer has an active account at this school.');
      }
      const { status, submittedAt, ...published } = album;
      transaction.create(post, { ...published, at: new Date().toISOString() });
    }
    transaction.update(submission, {
      status: action === '--approve' ? 'approved' : 'rejected',
      photos: FieldValue.delete(),
    });
  });
  console.log(action === '--approve' ? 'Photo album published.' : 'Photo submission rejected.');
}
