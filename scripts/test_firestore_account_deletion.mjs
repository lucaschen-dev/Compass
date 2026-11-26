import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { after, before, test } from 'node:test';

const runtime = process.env.COMPASS_FIREBASE_TEST_RUNTIME;
const require = createRequire(runtime ? join(runtime, 'package.json') : import.meta.url);
const { assertFails, assertSucceeds, initializeTestEnvironment } =
  require('@firebase/rules-unit-testing');
const {
  collection, doc, getDoc, getDocs, query, serverTimestamp, setDoc, setLogLevel,
  where, writeBatch,
} = require('firebase/firestore');
setLogLevel('silent');

let environment;
const projectId = 'demo-compass-deletion';
const now = () => Math.floor(Date.now() / 1000);
const receipt = 'd'.repeat(48);
const jobPath = 'accountDeletionRequests/fixture-alice';
const receiptPath = `accountDeletionReceipts/${receipt}`;
const schoolId = 'app-review-fixture';

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { rules: await readFile('firestore.rules', 'utf8') },
  });
});

after(async () => environment?.cleanup());

function requester(uid = 'fixture-alice', authTime = now()) {
  return environment.authenticatedContext(uid, {
    auth_time: authTime,
    email: `${uid}@fixture.example`,
    email_verified: true,
  }).firestore();
}

function submit(database) {
  const batch = writeBatch(database);
  batch.set(doc(database, jobPath), { status: 'pending', receipt, requestedAt: serverTimestamp() });
  batch.set(doc(database, receiptPath), { status: 'pending' });
  return batch.commit();
}

test('recently verified owner can queue deletion and view only the opaque status', async () => {
  const publicDb = environment.unauthenticatedContext().firestore();
  const owner = requester();
  const stranger = requester('fixture-other');
  const stale = requester('fixture-alice', now() - 601);
  await assertFails(submit(publicDb));
  await assertFails(submit(stranger));
  await assertFails(submit(stale));
  await assertFails(setDoc(doc(owner, receiptPath), { status: 'pending' }));
  await assertSucceeds(submit(owner));
  await assertFails(getDoc(doc(stranger, jobPath)));
  const { status } = (await assertSucceeds(getDoc(doc(publicDb, receiptPath)))).data();
  assert.equal(status, 'pending');
  await assertFails(getDocs(collection(publicDb, 'accountDeletionReceipts')));
  await assertFails(setDoc(doc(owner, receiptPath), { status: 'completed' }));
  await assertFails(setDoc(doc(owner, 'users/fixture-alice/schools/stale'), {
    updatedAt: serverTimestamp(),
  }));
});

test('the isolated review school is visible only to its seeded members', async () => {
  const documentPath = `schoolRegistry/${schoolId}`;
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, documentPath), { status: 'review', emailDomain: 'fixture.example' });
    await setDoc(doc(db, 'users/fixture-reviewer'), { schoolId });
  });
  const publicDb = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(publicDb, documentPath)));
  await assertFails(getDoc(doc(requester('fixture-other'), documentPath)));
  await assertSucceeds(getDoc(doc(requester('fixture-reviewer'), documentPath)));
  const catalog = await assertSucceeds(getDocs(query(
    collection(publicDb, 'schoolRegistry'), where('status', '==', 'approved'),
  )));
  assert(!catalog.docs.some((document) => document.id === schoolId));
  await assertFails(setDoc(doc(requester('fixture-unassigned'), 'users/fixture-unassigned'), {
    email: 'fixture-unassigned@fixture.example', grade: 10, name: 'Test Reviewer',
    schoolId, updatedAt: serverTimestamp(),
  }));
});
