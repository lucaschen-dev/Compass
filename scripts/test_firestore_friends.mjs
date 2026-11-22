import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { after, before, beforeEach, test } from 'node:test';

const runtime = process.env.COMPASS_FIREBASE_TEST_RUNTIME;
const require = createRequire(runtime ? join(runtime, 'package.json') : import.meta.url);
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
} = require('firebase/firestore');

setLogLevel('silent');

const school = 'alderline';
const otherSchool = 'cedarbrook';
const alice = { uid: 'alice', name: 'Alice Student', schoolId: school };
const teacher = { uid: 'teacher', name: 'Taylor Teacher', schoolId: school };
const peer = { uid: 'peer', name: 'Avery Student', schoolId: school };
const outsider = { uid: 'outsider', name: 'Jamie Student', schoolId: otherSchool };
let environment;

function email(person) {
  return `${person.uid}@${person.schoolId}.example`;
}

function as(person) {
  return environment.authenticatedContext(person.uid, { email: email(person) }).firestore();
}

function directory(db, schoolId = school) {
  return collection(db, 'schools', schoolId, 'directory');
}

function requests(db, schoolId = school) {
  return collection(db, 'schools', schoolId, 'friendRequests');
}

function pair(sender, recipient) {
  return [sender.uid, recipient.uid].sort().join(':');
}

function invitation(db, sender, recipient, schoolId = school) {
  return doc(requests(db, schoolId), pair(sender, recipient));
}

function pending(sender, recipient) {
  return {
    participants: [sender.uid, recipient.uid].sort(),
    senderId: sender.uid,
    recipientId: recipient.uid,
    senderName: sender.name,
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function outcome(status, fields = {}) {
  return { status, updatedAt: serverTimestamp(), ...fields };
}

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-compass-friends',
    firestore: {
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    for (const person of [alice, teacher, peer, outsider]) {
      await setDoc(doc(db, 'users', person.uid), {
        name: person.name,
        email: email(person),
        grade: 11,
        schoolId: person.schoolId,
        updatedAt: serverTimestamp(),
      });
    }
  });
});

after(async () => {
  await environment?.cleanup();
});

test('directory publication is opt-in, names-only, and scoped to the school', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const own = doc(directory(aliceDb), alice.uid);
  const other = doc(directory(teacherDb), teacher.uid);
  assert.equal((await getDocs(directory(aliceDb))).size, 0);
  await assertFails(setDoc(own, { name: teacher.name }));
  await assertFails(setDoc(own, { name: alice.name, email: email(alice) }));
  await assertFails(setDoc(doc(directory(aliceDb), teacher.uid), { name: teacher.name }));
  await assertFails(setDoc(doc(directory(aliceDb, otherSchool), alice.uid), { name: alice.name }));
  await assertSucceeds(setDoc(own, { name: alice.name }));
  await assertSucceeds(setDoc(other, { name: teacher.name }));

  const visible = await assertSucceeds(getDocs(query(directory(aliceDb), orderBy('name'))));
  assert.deepEqual(visible.docs.map((member) => member.data()), [
    { name: alice.name },
    { name: teacher.name },
  ]);
  await assertFails(getDocs(directory(as(outsider))));
  await assertFails(getDoc(doc(directory(environment.unauthenticatedContext().firestore()), alice.uid)));
  await assertFails(getDoc(doc(aliceDb, 'users', teacher.uid)));

  await assertFails(deleteDoc(doc(directory(aliceDb), teacher.uid)));
  await assertSucceeds(deleteDoc(other));
  assert.deepEqual((await getDocs(directory(aliceDb))).docs.map((member) => member.id), [alice.uid]);
});

test('an invitation by exact code remains private and needs recipient acceptance', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const ref = invitation(aliceDb, alice, teacher);
  const teacherRef = invitation(teacherDb, alice, teacher);
  assert.equal((await assertSucceeds(getDoc(ref))).exists(), false);
  await assertFails(setDoc(ref, { ...pending(alice, teacher), recipientName: teacher.name }));
  await assertFails(setDoc(ref, { ...pending(alice, teacher), status: 'accepted' }));
  await assertFails(setDoc(ref, { ...pending(alice, teacher), senderName: teacher.name }));
  await assertSucceeds(setDoc(ref, pending(alice, teacher)));
  assert.equal((await getDocs(directory(aliceDb))).size, 0);

  const ownRequests = query(requests(teacherDb), where('participants', 'array-contains', teacher.uid));
  const incoming = await assertSucceeds(getDocs(ownRequests));
  assert.equal(incoming.size, 1);
  assert.equal(incoming.docs[0].data().status, 'pending');
  assert.equal(incoming.docs[0].data().senderName, alice.name);
  assert.equal(incoming.docs[0].data().recipientName, undefined);

  const peerDb = as(peer);
  await assertFails(getDocs(requests(peerDb)));
  await assertFails(getDocs(query(requests(peerDb), where('participants', 'array-contains', teacher.uid))));
  await assertFails(getDoc(invitation(peerDb, alice, teacher)));
  await assertFails(getDoc(invitation(as(outsider), alice, teacher)));
  await assertFails(updateDoc(ref, outcome('accepted', { recipientName: teacher.name })));
  await assertFails(updateDoc(teacherRef, outcome('accepted', { recipientName: alice.name })));
  await assertFails(updateDoc(teacherRef, outcome('accepted', {
    recipientName: teacher.name,
    participants: [peer.uid, teacher.uid].sort(),
  })));

  await assertSucceeds(updateDoc(teacherRef, outcome('accepted', { recipientName: teacher.name })));
  const accepted = (await getDoc(ref)).data();
  assert.equal(accepted.status, 'accepted');
  assert.equal(accepted.recipientName, teacher.name);
  await assertFails(updateDoc(ref, outcome('canceled')));
  await assertFails(deleteDoc(teacherRef));
});

test('only the sender cancels, only the recipient declines, and the canonical pair is unique', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const ref = invitation(aliceDb, alice, teacher);
  const teacherRef = invitation(teacherDb, alice, teacher);
  const invalidPair = doc(requests(teacherDb), `${teacher.uid}:${alice.uid}`);
  await assertFails(setDoc(invalidPair, pending(teacher, alice)));
  await assertFails(setDoc(invitation(aliceDb, alice, outsider), pending(alice, outsider)));
  const unknown = { uid: 'unknown' };
  await assertFails(setDoc(invitation(aliceDb, alice, unknown), pending(alice, unknown)));
  await assertFails(setDoc(invitation(aliceDb, alice, alice), pending(alice, alice)));
  await assertFails(setDoc(ref, { ...pending(alice, teacher), participants: [alice.uid] }));
  await assertFails(setDoc(ref, { ...pending(alice, teacher), createdAt: new Date(0) }));
  await assertSucceeds(setDoc(ref, pending(alice, teacher)));

  await assertFails(setDoc(teacherRef, pending(teacher, alice)));
  await assertFails(updateDoc(teacherRef, outcome('canceled')));
  await assertFails(updateDoc(ref, outcome('declined')));
  await assertSucceeds(updateDoc(ref, outcome('canceled')));
  await assertSucceeds(setDoc(teacherRef, pending(teacher, alice)));
  await assertSucceeds(updateDoc(ref, outcome('declined')));
  await assertFails(setDoc(teacherRef, pending(teacher, alice)));
});

test('two opposite concurrent requests produce one pending invitation', async () => {
  async function trySend(sender, recipient) {
    const db = as(sender);
    const ref = invitation(db, sender, recipient);
    return runTransaction(db, async (transaction) => {
      if ((await transaction.get(ref)).exists()) return false;
      transaction.set(ref, pending(sender, recipient));
      return true;
    });
  }
  const sent = await Promise.all([trySend(alice, teacher), trySend(teacher, alice)]);
  assert.equal(sent.filter(Boolean).length, 1);
  const aliceDb = as(alice);
  const scoped = query(requests(aliceDb), where('participants', 'array-contains', alice.uid));
  const received = await new Promise((resolve, reject) => {
    const stop = onSnapshot(scoped, (snapshot) => {
      if (snapshot.metadata.fromCache) return;
      stop();
      resolve(snapshot);
    }, reject);
  });
  assert.equal(received.size, 1);
  assert.equal(received.docs[0].data().status, 'pending');
});

test('an existing Google account cannot switch its school through a profile update', async () => {
  const googleEmail = 'teacher@school.test';
  await environment.withSecurityRulesDisabled(async (admin) => {
    await updateDoc(doc(admin.firestore(), 'users', teacher.uid), { email: googleEmail });
  });
  const auth = environment.authenticatedContext(teacher.uid, {
    email: googleEmail,
    firebase: { sign_in_provider: 'google.com' },
  });
  const profile = doc(auth.firestore(), 'users', teacher.uid);
  await assertSucceeds(updateDoc(profile, { name: 'Taylor Updated', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(profile, { schoolId: otherSchool }));
});
