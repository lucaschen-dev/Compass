import { randomBytes } from 'node:crypto';
import { constants } from 'node:fs';
import { lstat, open, readFile, realpath } from 'node:fs/promises';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { applicationDefault, deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const repository = fileURLToPath(new URL('../', import.meta.url));
const galleryImage = new URL('../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', import.meta.url);
const projectPattern = /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/;
const mailboxPattern = /^[a-z0-9][a-z0-9._+\-]{0,63}@([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;
const schoolIdPattern = /^review-[a-f0-9]{24}$/;
const names = ['Compass Review One', 'Compass Review Two'];

class SeedError extends Error {}

function reviewerEmails(input) {
  const emails = input.map((value) => value.trim().toLowerCase());
  if (emails.length !== 2 || emails[0] === emails[1] ||
      emails.some((email) => email.length > 254 || !mailboxPattern.test(email)) ||
      emails[0].split('@')[1] !== emails[1].split('@')[1]) {
    throw new SeedError('Supply two distinct test mailboxes on the same email domain.');
  }
  return emails;
}

function newSeed(projectId, input) {
  const emails = reviewerEmails(input);
  const schoolId = `review-${randomBytes(12).toString('hex')}`;
  return {
    projectId,
    schoolId,
    accounts: emails.map((email, index) => ({
      uid: `${schoolId}-${index + 1}`,
      email,
      password: `C9!${randomBytes(24).toString('base64url')}`,
    })),
  };
}

async function credentialPath(input) {
  if (!isAbsolute(input)) throw new SeedError('Use an absolute path for the private credentials file.');
  const parent = await realpath(dirname(input));
  const path = resolve(parent, basename(input));
  const repoRelative = relative(await realpath(repository), path);
  if (repoRelative === '' || (repoRelative !== '..' && !repoRelative.startsWith(`..${sep}`))) {
    throw new SeedError('Store the private credentials outside the Compass repository.');
  }
  // A different checkout of Compass can share Git history with this one.
  for (let directory = parent; ; directory = dirname(directory)) {
    try {
      await lstat(join(directory, '.git'));
      throw new SeedError('Store the private credentials outside Git working trees.');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    if (directory === dirname(directory)) break;
  }
  return path;
}

async function readSeed(path, projectId) {
  const file = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const stat = await file.stat();
    if (!stat.isFile() || (stat.mode & 0o777) !== 0o600 || stat.uid !== process.getuid()) {
      throw new SeedError('The credentials file must be owned by you with permissions set to 600.');
    }
    const seed = JSON.parse(await file.readFile('utf8'));
    if (seed?.projectId !== projectId || !schoolIdPattern.test(seed.schoolId) ||
        !Array.isArray(seed.accounts) || seed.accounts.some((account, index) =>
          !account || typeof account.email !== 'string' ||
          account.uid !== `${seed.schoolId}-${index + 1}` ||
          !/^C9![A-Za-z0-9_-]{32}$/.test(account.password))) {
      throw new SeedError('The credentials file does not match the selected Firebase project.');
    }
    const emails = reviewerEmails(seed.accounts.map(({ email }) => email));
    if (emails.some((email, index) => email !== seed.accounts[index].email)) {
      throw new SeedError('The credentials file could not be validated.');
    }
    return seed;
  } finally {
    await file.close();
  }
}

async function writeSeed(path, seed) {
  let file;
  try {
    file = await open(path, 'wx', 0o600);
  } catch (error) {
    if (error.code === 'EEXIST') {
      throw new SeedError('The credentials file already exists. Use --resume or choose a different file.');
    }
    throw error;
  }
  try {
    await file.chmod(0o600);
    await file.writeFile(`${JSON.stringify(seed, null, 2)}\n`, 'utf8');
    await file.sync();
  } finally {
    await file.close();
  }
}

async function findAuthUser(request) {
  try {
    return await request();
  } catch (error) {
    if (error.code === 'auth/user-not-found') return null;
    throw error;
  }
}

async function checkAuthAccounts(auth, seed, { resume, complete }) {
  return Promise.all(seed.accounts.map(async (account) => {
    const [byEmail, byUid] = await Promise.all([
      findAuthUser(() => auth.getUserByEmail(account.email)),
      findAuthUser(() => auth.getUser(account.uid)),
    ]);
    if (!byEmail && !byUid && !complete) return false;
    if (!resume || byEmail?.uid !== account.uid || byUid?.email !== account.email ||
        !byUid.emailVerified || byUid.disabled ||
        !byUid.providerData.some((provider) => provider.providerId === 'password')) {
      throw new SeedError('A test mailbox or reviewer ID is already in use, or the saved reviewer was changed. Existing accounts were preserved.');
    }
    return true;
  }));
}

function references(database, seed) {
  return {
    school: database.doc(`schools/${seed.schoolId}`),
    registry: database.doc(`schoolRegistry/${seed.schoolId}`),
    marker: database.doc(`appReviewSeeds/${seed.schoolId}`),
    profiles: seed.accounts.map(({ uid }) => database.doc(`users/${uid}`)),
  };
}

async function checkFirestoreSeed(reader, refs, seed, resume) {
  const [marker, registry, school, ...profiles] = await reader.getAll(
    refs.marker, refs.registry, refs.school, ...refs.profiles,
  );
  if (!marker.exists && !registry.exists && !school.exists && profiles.every((entry) => !entry.exists)) {
    return false;
  }
  if (resume && marker.exists && registry.get('status') === 'review' && !school.exists &&
      seed.accounts.every(({ uid, email }, index) =>
        marker.get('reviewerUids')?.[index] === uid &&
        profiles[index].get('schoolId') === seed.schoolId &&
        profiles[index].get('email') === email)) {
    return true;
  }
  throw new SeedError('A school or profile already uses a generated ID, or the saved review school was changed. Existing data was preserved.');
}

async function seedFirestore(database, refs, seed, resume) {
  const photo = (await readFile(galleryImage)).toString('base64');
  const updatedAt = FieldValue.serverTimestamp();
  const at = new Date().toISOString();
  await database.runTransaction(async (transaction) => {
    if (await checkFirestoreSeed(transaction, refs, seed, resume)) return;
    transaction.create(refs.registry, {
      status: 'review',
      name: 'Compass Review School',
      location: '',
      color: '#244A73',
      emailDomain: seed.accounts[0].email.split('@')[1],
    });
    transaction.create(refs.marker, {
      reviewerUids: seed.accounts.map(({ uid }) => uid),
      createdAt: updatedAt,
    });
    seed.accounts.forEach(({ uid, email }, index) => {
      transaction.create(refs.profiles[index], {
        email, name: names[index], grade: 11, schoolId: seed.schoolId, updatedAt,
      });
      transaction.create(refs.school.collection('directory').doc(uid), { name: names[index] });
    });

    const posts = refs.school.collection('posts');
    const orientation = posts.doc('review-campus-orientation');
    const sample = {
      at, anonymous: false, priority: false, askedPerson: '', likes: 0,
    };
    transaction.create(orientation, {
      ...sample,
      id: orientation.id,
      authorId: seed.accounts[1].uid,
      authorName: names[1],
      title: 'Campus orientation',
      body: 'A sample welcome event for reviewing the Compass community feed.',
      category: 'event',
      subtag: 'Campus',
      photos: [],
    });
    transaction.create(orientation.collection('replies').doc('review-campus-reply'), {
      id: 'review-campus-reply',
      authorId: seed.accounts[0].uid,
      authorName: names[0],
      author: names[0],
      body: 'Thanks for the welcome!',
      at,
    });
    const album = posts.doc('review-sample-gallery');
    transaction.create(album, {
      ...sample,
      id: album.id,
      authorId: seed.accounts[1].uid,
      authorName: names[1],
      title: 'Compass photo album',
      body: 'Sample artwork for reviewing photo uploads and albums.',
      category: 'gallery',
      subtag: 'Arts',
      photos: [photo],
    });
  });
}

async function run(args) {
  const [projectId, first, second, output] = args;
  const resume = first === '--resume';
  if (!projectPattern.test(projectId ?? '') || args.length !== (resume ? 3 : 4)) {
    throw new SeedError('Usage: node seed-app-review.js PROJECT_ID EMAIL_ONE EMAIL_TWO /absolute/credentials.json\n       node seed-app-review.js PROJECT_ID --resume /absolute/credentials.json');
  }
  const authEmulator = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  const firestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (authEmulator !== firestoreEmulator || authEmulator !== projectId.startsWith('demo-')) {
    throw new SeedError('Emulator runs require both emulators and a demo project ID.');
  }
  const path = await credentialPath(resume ? second : output);
  const seed = resume ? await readSeed(path, projectId) : newSeed(projectId, [first, second]);
  const app = initializeApp({ credential: applicationDefault(), projectId });
  try {
    const database = getFirestore(app);
    const auth = getAuth(app);
    const refs = references(database, seed);
    const complete = await checkFirestoreSeed(database, refs, seed, resume);
    const existing = await checkAuthAccounts(auth, seed, { resume, complete });
    if (complete) {
      process.stdout.write('Review school already exists. Saved credentials and school data were preserved.\n');
      return;
    }
    if (!resume) await writeSeed(path, seed);
    for (const [index, account] of seed.accounts.entries()) {
      if (!existing[index]) {
        await auth.createUser({ ...account, emailVerified: true, displayName: names[index] });
      }
    }
    await seedFirestore(database, refs, seed, resume);
    process.stdout.write('Private Compass review school created. Credentials are in the supplied file.\n');
  } finally {
    await deleteApp(app);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await run(process.argv.slice(2));
  } catch (error) {
    // SDK exceptions may contain an email address or request metadata.
    process.stderr.write(error instanceof SeedError
      ? `${error.message}\n`
      : 'Review setup stopped. If the credentials file was created, retry with --resume using that file.\n');
    process.exitCode = 1;
  }
}
