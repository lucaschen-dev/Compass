"""Disposable loopback fixture. No real email, moderation, or production data."""
import sys
from pathlib import Path
from http.server import ThreadingHTTPServer
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend'))
from server import Service, Handler
mail = {}
service = Service(':memory:', ['students.example.edu'], 'local-test-secret-' * 4,
    mailer=lambda email, code: mail.update({email: code}), reviewer=lambda text: 'published',
    priority_reviewer=lambda text: 'normal', photo_reviewer=lambda text, images: 'published')
for name in ['alice', 'bob', 'cara']:
    email = name + '@students.example.edu'
    service.handle('POST', '/auth/request', {'email': email})
    token = service.handle('POST', '/auth/verify', {'email': email, 'code': mail[email]})['token']
    service.handle('POST', '/auth/password', {'password': 'fixture-password-123'}, token)
    service.handle('PATCH', '/profile', {'name': name, 'year': 'Grade 11', 'bio': '', 'instagram': ''}, token)
    if name == 'alice':
        uid = service.handle('GET', '/bootstrap', token=token)['me']['id']
        service.db.execute("UPDATE users SET role='Administrator' WHERE id=?", (uid,))
server = ThreadingHTTPServer(('127.0.0.1', 18764), Handler)
server.service = service
print('Disposable contract fixture listening on loopback port 18764.', flush=True)
server.serve_forever()
