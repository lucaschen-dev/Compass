export function reviewNotice({ projectId, applicationId, schoolName, from, to }) {
  const consoleUrl = new URL(
    `https://console.firebase.google.com/project/${encodeURIComponent(projectId)}/firestore/databases/-default-/data`,
  );
  const name = schoolName.replace(/\s+/g, ' ').trim();
  return {
    from,
    to: [to],
    subject: `Compass school application: ${name}`,
    text: [
      `${name} submitted a school registration in Compass.`,
      '',
      `Review schoolApplications/${applicationId} in the Compass Firebase console:`,
      consoleUrl.href,
    ].join('\n'),
  };
}

export async function sendReviewNotice(notice, { apiKey, applicationId, fetchImpl = fetch }) {
  const response = await fetchImpl('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Idempotency-Key': `compass-school-review/${applicationId}`,
    },
    body: JSON.stringify(notice),
    signal: AbortSignal.timeout(12000),
  });
  if (response.ok) return 'sent';
  if ([408, 409, 429].includes(response.status) || response.status >= 500) {
    throw new Error(`Review email temporarily unavailable (${response.status})`);
  }
  return 'failed';
}
