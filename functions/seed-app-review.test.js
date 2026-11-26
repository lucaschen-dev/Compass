import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const run = promisify(execFile);
const script = fileURLToPath(new URL('./seed-app-review.js', import.meta.url));
const emulator = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST,
);

test('review setup creates isolated accounts, resumes safely, and preserves existing users',
  { skip: !emulator },
  async () => {
    const projectId = process.env.GCLOUD_PROJECT ?? 'demo-compass-app-review';
    assert.ok(projectId.startsWith('demo-'));
    const app = initializeApp({ projectId });
    const auth = getAuth(app);
    const database = getFirestore(app);
    const directory = await mkdtemp(join(tmpdir(), 'compass-app-review-'));
    try {
      const address = (name) => `${name}-${Date.now()}@review.example`;
      const existing = await auth.createUser({ email: address('existing') });
      const rejected = join(directory, 'rejected.json');
      await assert.rejects(
        run(process.execPath, [script, projectId, address('other'), existing.email, rejected]),
        { stderr: /already in use/ },
      );
      await assert.rejects(stat(rejected), { code: 'ENOENT' });
      assert.equal((await auth.getUser(existing.uid)).emailVerified, false);

      const first = address('one');
      const second = address('two');
      const output = join(directory, 'review.json');
      const result = await run(process.execPath, [script, projectId, first, second, output]);
      assert.ok(!result.stdout.includes(first) && !result.stdout.includes(second));
      assert.equal((await stat(output)).mode & 0o777, 0o600);
      const saved = await readFile(output, 'utf8');
      const seed = JSON.parse(saved);
      assert.equal(result.stdout.includes(seed.accounts[0].password), false);
      const registry = database.doc(`schoolRegistry/${seed.schoolId}`);
      assert.equal((await registry.get()).get('status'), 'review');
      assert.equal((await database.doc(`schools/${seed.schoolId}`).get()).exists, false);
      const registryUrl = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${projectId}/databases/(default)/documents/${registry.path}`;
      assert.equal((await fetch(registryUrl)).status, 403);

      for (const { uid, email, password } of seed.accounts) {
        const response = await fetch(
          `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password, returnSecureToken: true }),
          },
        );
        assert.equal(response.ok, true);
        const result = await response.json();
        assert.equal(result.localId, uid);
        assert.equal((await fetch(registryUrl, {
          headers: { Authorization: `Bearer ${result.idToken}` },
        })).status, 200);
        assert.equal((await auth.getUser(uid)).emailVerified, true);
        assert.equal((await database.doc(`users/${uid}`).get()).get('schoolId'), seed.schoolId);
        assert.ok((await database.doc(`schools/${seed.schoolId}/directory/${uid}`).get()).exists);
      }

      const school = database.doc(`schools/${seed.schoolId}`);
      assert.ok((await school.collection('friendRequests').get()).empty);
      const gallery = school.collection('posts').doc('review-sample-gallery');
      const [photo] = (await gallery.get()).get('photos');
      assert.ok(photo.startsWith('iVBORw0KGgo') && photo.length < 160000);
      await gallery.update({ body: 'Reviewer edited this caption.' });

      await run(process.execPath, [script, projectId, '--resume', output]);
      assert.equal(await readFile(output, 'utf8'), saved);
      assert.equal((await gallery.get()).get('body'), 'Reviewer edited this caption.');
    } finally {
      await rm(directory, { recursive: true, force: true });
      await deleteApp(app);
    }
  },
);
