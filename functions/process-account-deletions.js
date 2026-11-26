import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { eraseCompassAccount, purgeCompletedDeletionRequests } from './account-deletion.js';

const [projectId, mode, ...extra] = process.argv.slice(2);
if (!projectId || extra.length || (mode && mode !== '--apply')) {
  console.error('Usage: node functions/process-account-deletions.js PROJECT_ID [--apply]');
  process.exit(1);
}

const app = initializeApp({ credential: applicationDefault(), projectId });
const database = getFirestore(app);
const auth = getAuth(app);
const pending = await database.collection('accountDeletionRequests')
  .where('status', '==', 'pending').get();

if (!mode) {
  console.log(`There are ${pending.size} pending deletion request(s).`);
  process.exit(0);
}
let completed = 0;
let failed = 0;
for (const request of pending.docs) {
  try {
    if (await eraseCompassAccount(database, auth, request.id)) completed++;
  } catch (error) {
    failed++;
    console.error('Account deletion failed. Queue entry retained.', error.code);
  }
}
await purgeCompletedDeletionRequests(database);
console.log(`Completed ${completed} account deletion(s). ${failed} failed and can be retried.`);
if (failed) process.exitCode = 1;
