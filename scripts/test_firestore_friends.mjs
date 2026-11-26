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
  deleteField,
  doc,
  documentId,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  setLogLevel,
  startAfter,
  updateDoc,
  where,
  writeBatch,
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

function messages(db) {
  return collection(invitation(db, alice, teacher), 'messages');
}

function history(db, pageSize = 50) {
  return query(
    messages(db),
    orderBy('createdAt', 'desc'),
    orderBy(documentId(), 'desc'),
    limit(pageSize),
  );
}

function textMessage(sender, text = 'Hello!') {
  return { senderId: sender.uid, text, createdAt: serverTimestamp() };
}

async function acceptInvitation(aliceDb, teacherDb) {
  await setDoc(invitation(aliceDb, alice, teacher), pending(alice, teacher));
  await updateDoc(
    invitation(teacherDb, alice, teacher),
    outcome('accepted', { recipientName: teacher.name }),
  );
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

const approvedSchool = {
  name: 'Example High School',
  emailDomain: 'examplehigh.edu',
  location: 'Example City',
  color: '#224477',
  status: 'approved',
};

test('public school discovery returns only administrator-approved schools', async () => {
  await environment.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    await setDoc(doc(db, 'schoolRegistry', 'example-high'), approvedSchool);
    await setDoc(doc(db, 'schoolRegistry', 'pending-high'), {
      ...approvedSchool,
      status: 'pending',
    });
  });
  const visitor = environment.unauthenticatedContext().firestore();
  const registry = collection(visitor, 'schoolRegistry');
  const snapshot = await assertSucceeds(getDocs(query(
    registry, where('status', '==', 'approved'),
  )));
  assert.deepEqual(snapshot.docs.map((entry) => entry.id), ['example-high']);
  await assertSucceeds(getDoc(doc(registry, 'example-high')));
  await assertFails(getDoc(doc(registry, 'pending-high')));
  await assertFails(getDocs(registry));
  await assertFails(setDoc(
    doc(as(alice), 'schoolRegistry', 'another-school'),
    approvedSchool,
  ));
});

test('school applications remain private, verified, and pending until reviewed', async () => {
  const applicantEmail = 'applicant@gmail.com';
  const applicant = environment.authenticatedContext('applicant', {
    email: applicantEmail,
    email_verified: true,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  const unverified = environment.authenticatedContext('unverified', {
    email: applicantEmail,
    email_verified: false,
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  const password = environment.authenticatedContext('password', {
    email: applicantEmail,
    email_verified: true,
    firebase: { sign_in_provider: 'password' },
  }).firestore();
  const schoolEmail = 'office@examplehigh.edu';
  const schoolPassword = environment.authenticatedContext('schoolpassword', {
    email: schoolEmail,
    email_verified: true,
    firebase: { sign_in_provider: 'password' },
  }).firestore();
  const unverifiedSchoolPassword = environment.authenticatedContext('unverifiedschoolpassword', {
    email: schoolEmail,
    email_verified: false,
    firebase: { sign_in_provider: 'password' },
  }).firestore();
  const application = {
    schoolName: approvedSchool.name,
    applicantName: 'Example Applicant',
    applicantRole: 'School administrator',
    applicantEmail,
    contactEmail: 'office@examplehigh.edu',
    emailDomain: approvedSchool.emailDomain,
    location: approvedSchool.location,
    color: approvedSchool.color,
    status: 'pending',
    submittedAt: serverTimestamp(),
  };
  const ref = doc(applicant, 'schoolApplications', 'applicant');
  await assertSucceeds(getDoc(ref));
  await assertFails(setDoc(doc(unverified, 'schoolApplications', 'unverified'), application));
  await assertFails(setDoc(doc(password, 'schoolApplications', 'password'), application));
  const passwordApplication = { ...application, applicantEmail: schoolEmail };
  const passwordRef = doc(schoolPassword, 'schoolApplications', 'schoolpassword');
  await assertFails(setDoc(passwordRef, { ...passwordApplication, contactEmail: 'different@examplehigh.edu' }));
  await assertFails(setDoc(doc(unverifiedSchoolPassword, 'schoolApplications', 'unverifiedschoolpassword'), passwordApplication));
  await assertSucceeds(setDoc(passwordRef, passwordApplication));
  await assertFails(setDoc(doc(applicant, 'schoolApplications', 'other'), application));
  await assertFails(setDoc(ref, { ...application, applicantEmail: 'someone@gmail.com' }));
  await assertFails(setDoc(ref, { ...application, contactEmail: 'office@examplehigh.edu.invalid' }));
  await assertFails(setDoc(ref, { ...application, status: 'approved' }));
  await assertFails(setDoc(ref, { ...application, reviewEmailSent: true }));
  await assertSucceeds(setDoc(ref, application));
  await assertFails(setDoc(ref, application));
  await assertFails(getDoc(doc(as(alice), 'schoolApplications', 'applicant')));
  await assertFails(getDocs(collection(applicant, 'schoolApplications')));
  await assertFails(updateDoc(ref, { status: 'approved' }));
  await environment.withSecurityRulesDisabled(async (admin) => {
    await updateDoc(doc(admin.firestore(), 'schoolApplications', 'applicant'), {
      status: 'approved',
    });
  });
  assert.equal((await assertSucceeds(getDoc(ref))).data().status, 'approved');
});

test('verified exact domains enroll in approved schools and legacy accounts remain usable', async () => {
  await environment.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    await setDoc(doc(db, 'schoolRegistry', 'example-high'), approvedSchool);
    await setDoc(doc(db, 'schoolRegistry', 'pending-high'), {
      ...approvedSchool,
      status: 'pending',
    });
    // Even erroneous registry data must not reopen a retired demo school.
    await setDoc(doc(db, 'schoolRegistry', school), {
      ...approvedSchool,
      emailDomain: `${school}.example`,
    });
  });
  function candidate(candidateId, address, verified, schoolId) {
    const db = environment.authenticatedContext(candidateId, {
      email: address,
      email_verified: verified,
      firebase: { sign_in_provider: 'google.com' },
    }).firestore();
    return setDoc(doc(db, 'users', candidateId), {
      name: 'Example Candidate',
      email: address,
      schoolId,
      grade: 11,
    });
  }
  await assertSucceeds(candidate('good', 'member@examplehigh.edu', true, 'example-high'));
  await assertFails(candidate('unverified', 'member@examplehigh.edu', false, 'example-high'));
  await assertFails(candidate('outsider-new', 'member@examplehigh.edu.invalid', true, 'example-high'));
  await assertFails(candidate('subdomain', 'member@staff.examplehigh.edu', true, 'example-high'));
  await assertFails(candidate('pending', 'member@examplehigh.edu', true, 'pending-high'));
  await assertFails(candidate('legacy-new', `member@${school}.example`, true, school));
  const legacy = doc(as(alice), 'users', alice.uid);
  await assertSucceeds(getDoc(legacy));
  await assertSucceeds(updateDoc(legacy, { name: 'Alice Updated' }));
  await assertFails(updateDoc(legacy, { schoolId: 'example-high' }));
});

test('posts keep validated school attribution and omit author names when anonymous', async () => {
  const path = ['schools', school, 'posts', 'author-attribution'];
  const post = doc(as(alice), ...path);
  const named = { authorId: alice.uid, title: 'School update', body: '', anonymous: false };
  await assertFails(setDoc(post, { ...named, authorName: teacher.name }));
  await assertFails(setDoc(post, { ...named, anonymous: true, authorName: alice.name }));
  await assertFails(setDoc(post, { ...named, anonymous: true, authorName: null }));
  await assertSucceeds(setDoc(post, named));
  await assertSucceeds(updateDoc(post, { authorName: alice.name }));

  const peerPost = doc(as(peer), ...path);
  assert.equal((await assertSucceeds(getDoc(peerPost))).data().authorName, alice.name);
  await assertFails(getDoc(doc(as(outsider), ...path)));
  await assertFails(getDoc(doc(as(peer), 'users', alice.uid)));
  await assertFails(updateDoc(peerPost, { authorName: peer.name }));
  await assertFails(updateDoc(post, { anonymous: true }));
  await assertSucceeds(updateDoc(post, { anonymous: true, authorName: deleteField() }));
  assert.equal((await assertSucceeds(getDoc(peerPost))).data().authorName, undefined);
  await assertSucceeds(updateDoc(post, { anonymous: false, authorName: alice.name }));
});

test('existing replies can gain the authenticated replier name without sharing profiles', async () => {
  const path = ['schools', school, 'posts', 'post-with-replies'];
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  await assertSucceeds(setDoc(doc(aliceDb, ...path), {
    authorId: alice.uid,
    title: 'A school post',
    body: 'Would anyone like to join us?',
    anonymous: true,
  }));

  const replyPath = [...path, 'replies', 'author-attribution'];
  const reply = doc(teacherDb, ...replyPath);
  const priorReply = { authorId: teacher.uid, author: 'me', body: 'Thanks!' };
  await assertFails(setDoc(reply, { ...priorReply, authorName: alice.name }));
  await assertSucceeds(setDoc(reply, priorReply));
  await assertFails(updateDoc(reply, { authorName: alice.name }));
  await assertSucceeds(updateDoc(reply, { authorName: teacher.name }));
  const aliceReply = doc(aliceDb, ...replyPath);
  assert.equal((await assertSucceeds(getDoc(aliceReply))).data().authorName, teacher.name);
  await assertFails(updateDoc(aliceReply, { authorName: alice.name }));
  await assertFails(getDoc(doc(as(outsider), ...replyPath)));
  await assertFails(getDoc(doc(aliceDb, 'users', teacher.uid)));
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

test('messages become readable and writable only when the recipient accepts', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const id = 'alice:aaaaaaaaaaaaaaaaaaaa';
  const aliceMessage = doc(messages(aliceDb), id);
  const teacherMessage = doc(messages(teacherDb), id);

  await assertFails(getDocs(history(aliceDb)));
  await assertFails(setDoc(aliceMessage, textMessage(alice)));
  await assertSucceeds(setDoc(invitation(aliceDb, alice, teacher), pending(alice, teacher)));
  await assertFails(getDoc(aliceMessage));
  await assertFails(getDocs(history(teacherDb)));
  await assertFails(setDoc(aliceMessage, textMessage(alice)));

  await assertSucceeds(updateDoc(
    invitation(teacherDb, alice, teacher),
    outcome('accepted', { recipientName: teacher.name }),
  ));
  const received = new Promise((resolve, reject) => {
    const stop = onSnapshot(history(teacherDb), (snapshot) => {
      if (snapshot.metadata.fromCache || snapshot.empty) return;
      stop();
      resolve(snapshot.docs[0].data().text);
    }, reject);
  });
  await assertSucceeds(setDoc(aliceMessage, textMessage(alice, 'First message')));
  assert.equal(await received, 'First message');
  assert.equal((await assertSucceeds(getDoc(teacherMessage))).data().senderId, alice.uid);

  await assertFails(getDocs(messages(aliceDb)));
  await assertFails(getDocs(history(aliceDb, 51)));
  for (const strangerDb of [
    as(peer),
    as(outsider),
    environment.unauthenticatedContext().firestore(),
  ]) {
    await assertFails(getDoc(doc(messages(strangerDb), id)));
    await assertFails(getDocs(history(strangerDb)));
  }
  await assertFails(setDoc(doc(messages(as(peer)), 'peer:aaaaaaaaaaaaaaaaaaaa'), textMessage(peer)));

  await environment.withSecurityRulesDisabled(async (admin) => {
    await updateDoc(doc(admin.firestore(), 'users', teacher.uid), { schoolId: otherSchool });
  });
  await assertFails(getDoc(aliceMessage));
  await assertFails(getDocs(history(teacherDb)));
});

test('accepted participants can send immutable text only as themselves', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  await acceptInvitation(aliceDb, teacherDb);
  const ref = doc(messages(aliceDb), 'alice:aaaaaaaaaaaaaaaaaaaa');

  await assertFails(setDoc(ref, textMessage(teacher)));
  await assertFails(setDoc(
    doc(messages(aliceDb), 'teacher:aaaaaaaaaaaaaaaaaaaa'),
    textMessage(alice),
  ));
  await assertFails(setDoc(doc(messages(aliceDb), 'alice:short'), textMessage(alice)));
  await assertFails(setDoc(ref, textMessage(alice, '\n \t')));
  await assertFails(setDoc(ref, textMessage(alice, 'a'.repeat(4001))));
  await assertFails(setDoc(ref, { ...textMessage(alice), createdAt: new Date(0) }));
  await assertFails(setDoc(ref, { ...textMessage(alice), imageUrl: 'example' }));
  await assertSucceeds(setDoc(ref, textMessage(alice, 'Hello\nSecond line')));
  await assertSucceeds(setDoc(
    doc(messages(teacherDb), 'teacher:aaaaaaaaaaaaaaaaaaaa'),
    textMessage(teacher),
  ));
  await assertFails(updateDoc(ref, { text: 'Different message' }));
  await assertFails(deleteDoc(ref));
  assert.equal((await getDocs(history(aliceDb))).size, 2);
});

test('transaction retries reuse one message and cursor paging preserves equal timestamps', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  await acceptInvitation(aliceDb, teacherDb);
  async function sendOnce(db) {
    const ref = doc(messages(db), 'alice:cccccccccccccccccccc');
    return runTransaction(db, async (transaction) => {
      if ((await transaction.get(ref)).exists()) return;
      transaction.set(ref, textMessage(alice, 'Only once'));
    });
  }
  await Promise.all([sendOnce(aliceDb), sendOnce(as(alice))]);
  assert.equal((await getDocs(history(teacherDb))).size, 1);

  await environment.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    const sharedTime = new Date(0);
    await setDoc(doc(messages(db), 'alice:aaaaaaaaaaaaaaaaaaaa'), {
      senderId: alice.uid, text: 'Earlier message', createdAt: sharedTime,
    });
    await setDoc(doc(messages(db), 'teacher:aaaaaaaaaaaaaaaaaaaa'), {
      senderId: teacher.uid, text: 'Later by ID', createdAt: sharedTime,
    });
  });
  const latest = await assertSucceeds(getDocs(history(teacherDb, 2)));
  assert.deepEqual(latest.docs.map((message) => message.data().text), ['Only once', 'Later by ID']);
  const before = latest.docs.at(-1);
  const previous = query(
    history(teacherDb),
    startAfter(before.data().createdAt, before.id),
  );
  assert.deepEqual(
    (await assertSucceeds(getDocs(previous))).docs.map((message) => message.data().text),
    ['Earlier message'],
  );
});

function post(db, postId = 'moderation-post') {
  return doc(db, 'schools', school, 'posts', postId);
}

function blockRecord(db, owner, target, schoolId = school) {
  return doc(db, 'users', owner.uid, 'schools', schoolId, 'blocked', target.uid);
}

function blockData(target) {
  return { targetUid: target.uid, displayName: target.name, createdAt: serverTimestamp() };
}

function reportRecord(db, reportId) {
  return doc(db, 'schools', school, 'moderationReports', reportId);
}

function reportData(overrides = {}) {
  return {
    kind: 'post',
    parentId: '',
    contentId: 'moderation-post',
    reason: 'harassment',
    reporterId: teacher.uid,
    targetUid: alice.uid,
    title: 'Campus photos',
    body: 'After school',
    createdAt: serverTimestamp(),
    status: 'pending',
    ...overrides,
  };
}

test('objectionable text is rejected for a post, photo caption, comment and DM', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const ref = post(aliceDb);
  const allowed = { authorId: alice.uid, title: 'Campus photos', body: 'After school' };
  const gallery = { ...allowed, category: 'gallery' };
  await assertFails(setDoc(ref, { ...allowed, title: 'I WILL kill you!' }));
  await assertFails(setDoc(ref, { ...gallery, body: 'A photo\nKill\tyourself' }));
  await assertSucceeds(setDoc(ref, gallery));
  await assertFails(updateDoc(ref, { body: 'fuck  you' }));
  const comment = doc(post(teacherDb), 'replies', 'teacher-comment');
  const commentData = { authorId: teacher.uid, body: 'Thanks for sharing!' };
  await assertFails(setDoc(comment, { ...commentData, body: 'KILL YOURSELF' }));
  await assertSucceeds(setDoc(comment, commentData));
  await assertFails(updateDoc(comment, { body: 'I will kill you' }));

  await acceptInvitation(aliceDb, teacherDb);
  const message = doc(messages(aliceDb), 'alice:aaaaaaaaaaaaaaaaaaaa');
  await assertFails(setDoc(message, textMessage(alice, 'Message:\nFUCK YOU.')));
  await assertSucceeds(setDoc(message, textMessage(alice, 'Can you kill the background process?')));
});

test('school blocks are private, stop both directions of contact and support unblocking', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const block = blockRecord(aliceDb, alice, teacher);
  await assertFails(setDoc(blockRecord(aliceDb, alice, alice), blockData(alice)));
  await assertFails(setDoc(blockRecord(aliceDb, alice, outsider), blockData(outsider)));
  await assertFails(setDoc(blockRecord(aliceDb, alice, teacher, otherSchool), blockData(teacher)));
  await assertFails(setDoc(blockRecord(teacherDb, alice, teacher), blockData(teacher)));
  await assertFails(setDoc(block, { ...blockData(teacher), targetUid: peer.uid }));
  await assertSucceeds(setDoc(block, blockData(teacher)));
  await assertSucceeds(getDoc(block));
  await assertFails(getDoc(blockRecord(teacherDb, alice, teacher)));
  await assertFails(setDoc(invitation(aliceDb, alice, teacher), pending(alice, teacher)));
  await assertFails(setDoc(invitation(teacherDb, teacher, alice), pending(teacher, alice)));

  await assertSucceeds(deleteDoc(block));
  await assertSucceeds(setDoc(invitation(aliceDb, alice, teacher), pending(alice, teacher)));
  await assertSucceeds(setDoc(block, blockData(teacher)));
  await assertFails(updateDoc(
    invitation(teacherDb, alice, teacher),
    outcome('accepted', { recipientName: teacher.name }),
  ));
  await assertSucceeds(deleteDoc(block));
  await assertSucceeds(updateDoc(
    invitation(teacherDb, alice, teacher),
    outcome('accepted', { recipientName: teacher.name }),
  ));

  const fromAlice = doc(messages(aliceDb), 'alice:aaaaaaaaaaaaaaaaaaaa');
  const fromTeacher = doc(messages(teacherDb), 'teacher:aaaaaaaaaaaaaaaaaaaa');
  const batch = writeBatch(aliceDb);
  batch.set(block, blockData(teacher));
  batch.set(fromAlice, textMessage(alice));
  await assertFails(batch.commit());
  await assertSucceeds(setDoc(block, blockData(teacher)));
  await assertFails(setDoc(fromTeacher, textMessage(teacher)));
  await assertFails(setDoc(fromAlice, textMessage(alice)));
  await assertSucceeds(deleteDoc(block));
  await assertSucceeds(setDoc(fromTeacher, textMessage(teacher)));
});

test('reports preserve verified evidence and cannot be read or forged by members', async () => {
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const peerDb = as(peer);
  const outsiderDb = as(outsider);
  const realPost = post(aliceDb);
  await setDoc(realPost, { authorId: alice.uid, title: 'Campus photos', body: 'After school' });
  const report = reportRecord(teacherDb, 'post-evidence');
  await assertFails(setDoc(report, reportData({ body: 'Invented text' })));
  await assertFails(setDoc(report, reportData({ targetUid: peer.uid })));
  await assertFails(setDoc(report, reportData({ reporterId: peer.uid })));
  await assertFails(setDoc(report, reportData({ contentId: 'nonexistent' })));
  await assertFails(setDoc(reportRecord(outsiderDb, 'outsider'), reportData({ reporterId: outsider.uid })));
  await assertSucceeds(setDoc(report, reportData()));
  await assertFails(getDoc(report));
  await assertFails(getDoc(reportRecord(aliceDb, 'post-evidence')));
  await assertFails(getDocs(collection(teacherDb, 'schools', school, 'moderationReports')));
  await assertFails(updateDoc(report, { status: 'resolved' }));

  await setDoc(doc(realPost, 'replies', 'alice-comment'), {
    authorId: alice.uid, body: 'A concerning comment',
  });
  await assertSucceeds(setDoc(reportRecord(teacherDb, 'comment-evidence'), reportData({
    kind: 'comment', parentId: 'moderation-post', contentId: 'alice-comment',
    title: '', body: 'A concerning comment',
  })));

  await acceptInvitation(aliceDb, teacherDb);
  const messageId = 'alice:aaaaaaaaaaaaaaaaaaaa';
  await setDoc(doc(messages(aliceDb), messageId), textMessage(alice, 'A private comment'));
  const privateEvidence = reportData({
    kind: 'message', parentId: pair(alice, teacher), contentId: messageId,
    title: '', body: 'A private comment',
  });
  await assertFails(setDoc(
    reportRecord(peerDb, 'message-peek'),
    { ...privateEvidence, reporterId: peer.uid },
  ));
  await assertSucceeds(setDoc(reportRecord(teacherDb, 'message-evidence'), privateEvidence));

  await environment.withSecurityRulesDisabled(async (admin) => {
    await setDoc(doc(admin.firestore(), 'accountDeletionRequests', alice.uid), {
      status: 'pending',
    });
  });
  await assertFails(setDoc(reportRecord(teacherDb, 'target-pending-deletion'), reportData()));
  await assertFails(setDoc(blockRecord(teacherDb, teacher, alice), blockData(alice)));
});

test('new photo bytes are private until review and approved photo bytes cannot be replaced', async () => {
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQioAAAAASUVORK5CYII=';
  const aliceDb = as(alice);
  const teacherDb = as(teacher);
  const album = {
    id: 'pending-album',
    authorId: alice.uid,
    authorName: alice.name,
    title: 'Campus photos',
    body: 'After school',
    category: 'gallery',
    subtag: 'Campus',
    at: new Date().toISOString(),
    anonymous: false,
    priority: 'Normal',
    askedPerson: null,
    photos: [png],
    likes: 0,
  };
  const path = ['schools', school, 'photoSubmissions', album.id];
  const pending = { ...album, status: 'pending', submittedAt: serverTimestamp() };
  const privateRef = doc(aliceDb, ...path);
  const publicRef = post(aliceDb, album.id);
  await assertFails(setDoc(publicRef, album));
  await assertFails(setDoc(publicRef, { ...album, category: 'question' }));
  await assertFails(setDoc(privateRef, { ...pending, status: 'approved' }));
  await assertFails(setDoc(privateRef, { ...pending, body: 'I WILL kill you' }));
  await assertFails(setDoc(privateRef, { ...pending, photos: ['bad-image'] }));
  await assertFails(setDoc(privateRef, { ...pending, authorName: teacher.name }));
  await assertFails(setDoc(doc(as(outsider), ...path), pending));
  assert.equal((await assertSucceeds(getDoc(privateRef))).exists(), false);
  await assertSucceeds(setDoc(privateRef, pending));
  await assertSucceeds(getDoc(privateRef));
  await assertFails(getDoc(doc(teacherDb, ...path)));
  await assertFails(getDoc(doc(as(outsider), ...path)));
  assert.equal((await getDoc(publicRef)).exists(), false);
  await assertFails(updateDoc(privateRef, { status: 'approved' }));
  await assertFails(updateDoc(privateRef, { title: 'Edited after submission' }));
  const collectionRef = collection(aliceDb, ...path.slice(0, -1));
  await assertFails(getDocs(query(collectionRef, limit(10))));
  const own = query(
    collectionRef,
    where('authorId', '==', alice.uid),
    orderBy(documentId(), 'desc'),
    limit(10),
  );
  assert.equal((await assertSucceeds(getDocs(own))).size, 1);

  await environment.withSecurityRulesDisabled(async (admin) => {
    const db = admin.firestore();
    await setDoc(post(db, album.id), album);
    await updateDoc(doc(db, ...path), { status: 'approved', photos: deleteField() });
  });
  assert.deepEqual((await assertSucceeds(getDoc(post(teacherDb, album.id)))).data().photos, [png]);
  await assertSucceeds(updateDoc(publicRef, { body: 'A new caption' }));
  await assertSucceeds(updateDoc(publicRef, { body: 'More caption', photos: [png] }));
  await assertFails(updateDoc(publicRef, { photos: [png, png] }));
  await assertFails(updateDoc(publicRef, { title: 'Fuck you' }));
  assert.equal((await assertSucceeds(getDoc(privateRef))).data().status, 'approved');
});
