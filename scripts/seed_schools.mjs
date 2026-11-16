import { readFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const projectId = 'compass-database-480ea';
const schools = [
  {
    id: 'alderline',
    name: 'Alderline High School',
    location: 'North Wren Valley',
    initials: 'AH',
    emailDomain: 'alderline.example',
  },
  {
    id: 'cedarbrook',
    name: 'Cedarbrook High School',
    location: 'Foxwillow Bay',
    initials: 'CH',
    emailDomain: 'cedarbrook.example',
  },
];

async function accessToken() {
  const configPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  const refreshToken = config?.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('Firebase CLI is not logged in. Run firebase login first.');
  }
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
  });
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!response.ok) {
    throw new Error(`Could not refresh Firebase credentials (${response.status}).`);
  }
  const json = await response.json();
  if (!json.access_token) throw new Error('Firebase credentials did not include an access token.');
  return json.access_token;
}

function stringField(value) {
  return { stringValue: value };
}

async function enableEmailPassword(token) {
  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
  const url =
    `https://identitytoolkit.googleapis.com/v2/projects/${projectId}/config` +
    '?updateMask=signIn.email.enabled,signIn.email.passwordRequired';
  const response = await fetch(url, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({
      signIn: { email: { enabled: true, passwordRequired: true } },
    }),
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `Could not enable email/password sign-in (${response.status}): ${detail}`,
    );
  }
  console.log('Email/password sign-in is enabled.');
}

async function upsertSchool(token, school) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/schools/${school.id}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        id: stringField(school.id),
        name: stringField(school.name),
        location: stringField(school.location),
        initials: stringField(school.initials),
        emailDomain: stringField(school.emailDomain),
      },
    }),
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Could not upsert schools/${school.id} (${response.status}): ${detail}`);
  }
  console.log(`Upserted schools/${school.id}.`);
}

const token = await accessToken();
for (const school of schools) {
  await upsertSchool(token, school);
}
try {
  await enableEmailPassword(token);
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  console.error(
    'School documents were saved. Turn on Authentication > Email/Password in the Firebase console if it is still off.',
  );
  process.exitCode = 1;
}
