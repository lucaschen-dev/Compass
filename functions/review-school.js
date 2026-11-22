import { createHash } from 'node:crypto';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const [projectId, applicationId, action] = process.argv.slice(2);
if (!projectId || !/^[A-Za-z0-9_-]{1,128}$/.test(applicationId ?? '') ||
    !['approve', 'reject'].includes(action)) {
  process.stderr.write('Usage: node review-school.js PROJECT_ID APPLICATION_ID approve|reject\n');
  process.exit(2);
}

const app = initializeApp({ credential: applicationDefault(), projectId });
const database = getFirestore(app);
const application = database.collection('schoolApplications').doc(applicationId);
await database.runTransaction(async (transaction) => {
  const record = (await transaction.get(application)).data();
  if (!record || record.status !== 'pending') {
    throw new Error('Only a pending school application can be reviewed.');
  }
  const reviewedAt = FieldValue.serverTimestamp();
  if (action === 'reject') {
    transaction.update(application, { status: 'rejected', reviewedAt });
    return;
  }

  const domain = record.emailDomain;
  if (typeof domain !== 'string' || domain.length > 253 ||
      !/^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$/.test(domain) ||
      typeof record.contactEmail !== 'string' ||
      record.contactEmail.toLowerCase().split('@').at(-1) !== domain) {
    throw new Error('This application has invalid school contact details.');
  }
  const schoolId = `school-${createHash('sha256').update(domain).digest('hex').slice(0, 24)}`;
  const school = database.collection('schoolRegistry').doc(schoolId);
  if ((await transaction.get(school)).exists) {
    throw new Error('A school with that email domain is already registered.');
  }
  transaction.create(school, {
    status: 'approved',
    name: record.schoolName,
    location: record.location,
    color: record.color,
    emailDomain: domain,
  });
  transaction.update(application, {
    status: 'approved',
    schoolId,
    reviewedAt,
  });
});
process.stdout.write(`School application ${action === 'approve' ? 'approved' : 'rejected'}.\n`);
