import base64
import io
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from server import Service, APIError

class CommunityTests(unittest.TestCase):
    def setUp(self):
        self.mail = {}
        self.s = Service(':memory:', ['buckley.org'], 'test-secret'*4,
            mailer=lambda e,c: self.mail.update({e:c}), reviewer=lambda t:'published',
            photo_reviewer=lambda t,p:'published', priority_reviewer=lambda t:'urgent')
        self.a = self.register('alice'); self.b = self.register('bob'); self.c = self.register('cara')
    def tearDown(self): self.s.db.close()
    def call(self,method,path,body=None,token=''): return self.s.handle(method,path,body,token)
    def verify(self,name):
        email=name+'@buckley.org'
        self.call('POST','/auth/request',{'email':email})
        return self.call('POST','/auth/verify',{'email':email,'code':self.mail[email]})['token']
    def register(self,name):
        token=self.verify(name)
        self.call('POST','/auth/password',{'password':'a-long-password'},token)
        self.call('PATCH','/profile',{'name':name,'year':'Grade 11'},token)
        return token
    def uid(self,t): return self.call('GET','/bootstrap',token=t)['me']['id']
    def error(self,status,method,path,body=None,token=''):
        with self.assertRaises(APIError) as e:self.call(method,path,body,token)
        self.assertEqual(e.exception.status,status)
    def chat(self):return self.call('POST','/conversations',{'peerID':self.uid(self.b)},self.a)['id']
    def post(self,**kw):
        body=dict(title='A post',body='Details',kind='Question',groupID='all',visibility='school',anonymous=True)
        body.update(kw);self.call('POST','/posts',body,self.a)
        return self.call('GET','/posts/mine',token=self.a)[0]['id']
    def photo(self,chat):
        from PIL import Image
        out=io.BytesIO();Image.new('RGB',(20,20),'red').save(out,format='JPEG')
        return self.call('POST',f'/conversations/{chat}/media',{'kind':'photo','data':base64.b64encode(out.getvalue()).decode()},self.a)['id']
    def test_registration_gates_and_password_hash(self):
        t=self.verify('new')
        snap=self.call('GET','/bootstrap',token=t)
        self.assertTrue(snap['needsPassword']);self.assertTrue(snap['needsProfile'])
        self.error(403,'GET','/members',token=t)
        self.error(400,'POST','/auth/password',{'password':'short'},t)
        self.call('POST','/auth/password',{'password':'a-new-long-password'},t)
        self.error(403,'GET','/members',token=t)
        self.call('PATCH','/profile',{'name':'New student','year':'Grade 9'},t)
        self.assertFalse(self.call('GET','/bootstrap',token=t)['needsProfile'])
        row=self.s.db.execute('SELECT * FROM credentials WHERE user_id=?',(self.uid(t),)).fetchone()
        self.assertNotIn('a-new-long-password',str(tuple(row)))
    def test_password_login_and_reset_revokes_old_session(self):
        result=self.call('POST','/auth/login',{'email':'alice@buckley.org','password':'a-long-password'})
        self.assertEqual(self.uid(result['token']),self.uid(self.a))
        self.error(401,'POST','/auth/login',{'email':'alice@buckley.org','password':'wrong'})
        self.error(403,'POST','/auth/password',{'password':'another-long-password'},result['token'])
        fresh=self.verify('alice');self.call('POST','/auth/password',{'password':'another-long-password'},fresh)
        self.error(401,'GET','/bootstrap',token=self.a)
        self.error(403,'POST','/auth/password',{'password':'yet-another-password'},fresh)
    def test_anonymous_owner_management_authorization(self):
        pid=self.post()
        own=self.call('GET','/posts/mine',token=self.a)[0]
        other=self.call('GET','/bootstrap',token=self.b)['posts'][0]
        self.assertTrue(own['isMine']);self.assertFalse(other['isMine']);self.assertIsNone(other['author'])
        self.error(404,'PATCH','/posts/'+pid,{'anonymous':False},self.b)
        self.error(404,'DELETE','/posts/'+pid,token=self.b)
        self.call('PATCH','/posts/'+pid,{'anonymous':False},self.a)
        self.assertIsNotNone(self.call('GET','/bootstrap',token=self.b)['posts'][0]['author'])
        self.call('POST',f'/posts/{pid}/replies',{'body':'A reply'},self.b)
        self.call('DELETE','/posts/'+pid,token=self.a)
        self.assertEqual(self.s.db.execute('SELECT count(*) FROM replies').fetchone()[0],0)
    def test_own_pending_posts_and_comment_delete(self):
        pid=self.post()
        self.call('POST',f'/posts/{pid}/replies',{'body':'A reply'},self.b)
        rid=self.call('GET','/bootstrap',token=self.a)['posts'][0]['replies'][0]['id']
        self.error(404,'DELETE','/replies/'+rid,token=self.a)
        self.call('DELETE','/replies/'+rid,token=self.b)
        self.s.db.execute("UPDATE posts SET status='pending' WHERE id=?",(pid,))
        self.assertEqual(len(self.call('GET','/posts/mine',token=self.a)),1)
        self.assertEqual(len(self.call('GET','/posts/mine',token=self.b)),0)
    def test_reply_retract_and_authorization(self):
        cid=self.chat(); path=f'/conversations/{cid}/messages'
        m=self.call('POST',path,{'body':'Hello 👋'},self.a)['message']
        response=self.call('POST',path,{'body':'Hi','replyID':m['id']},self.b)['message']
        self.assertEqual(response['replyID'],m['id'])
        self.error(404,'DELETE',path+'/'+m['id'],token=self.b)
        self.error(404,'DELETE',path+'/'+m['id'],token=self.c)
        self.call('DELETE',path+'/'+m['id'],token=self.a)
        messages=self.call('GET',f'/conversations/{cid}',token=self.b)['messages']
        self.assertTrue(messages[0]['retracted']);self.assertEqual(messages[0]['body'],'')
        self.error(404,'POST',path,{'body':'Hi','replyID':m['id']},self.b)
        self.assertEqual(self.s.db.execute('SELECT count(*) FROM push_queue WHERE message_id=?',(m['id'],)).fetchone()[0],0)
    def test_two_minute_boundary_uses_server_time(self):
        cid=self.chat();path=f'/conversations/{cid}/messages'
        m=self.call('POST',path,{'body':'Hello'},self.a)['message']
        with patch('server.time.time',return_value=m['createdAt']+120):self.error(409,'DELETE',path+'/'+m['id'],token=self.a)
        with patch('server.time.time',return_value=m['createdAt']+119):self.call('DELETE',path+'/'+m['id'],token=self.a)
    def test_media_access_and_retraction(self):
        cid=self.chat();media=self.photo(cid)
        self.error(404,'GET','/chat-media/'+media,token=self.b)
        self.error(404,'GET','/chat-media/'+media,token=self.c)
        self.error(403,'POST',f'/conversations/{cid}/messages',{'mediaID':media},self.b)
        m=self.call('POST',f'/conversations/{cid}/messages',{'body':'','mediaID':media},self.a)['message']
        self.assertEqual(m['mediaKind'],'photo')
        self.assertEqual(self.call('GET','/chat-media/'+media,token=self.b)['kind'],'photo')
        self.error(403,'POST',f'/conversations/{cid}/messages',{'mediaID':media},self.a)
        self.call('DELETE',f'/conversations/{cid}/messages/'+m['id'],token=self.a)
        self.error(404,'GET','/chat-media/'+media,token=self.b)
    def test_group_reply_and_removed_member_media(self):
        cid=self.call('POST','/group-conversations',{'title':'Study','participantIDs':[self.uid(self.b),self.uid(self.c)]},self.a)['id']
        media=self.photo(cid)
        m=self.call('POST',f'/conversations/{cid}/messages',{'mediaID':media},self.a)['message']
        self.call('POST',f'/conversations/{cid}/messages',{'body':'Thanks','replyID':m['id']},self.b)
        self.call('POST',f'/conversations/{cid}/leave',token=self.b)
        self.error(404,'GET','/chat-media/'+media,token=self.b)
        self.call('DELETE',f'/conversations/{cid}/messages/'+m['id'],token=self.a)
    def test_retention_preserves_important_urgent_and_removes_dependents(self):
        normal=self.post();important=self.post(priority='important');urgent=self.post(priority='urgent')
        self.call('POST',f'/posts/{normal}/replies',{'body':'Reply'},self.b)
        cid=self.chat();media=self.photo(cid)
        m=self.call('POST',f'/conversations/{cid}/messages',{'mediaID':media},self.a)['message']
        old=time.time()-30*86400-1
        self.s.db.execute('UPDATE posts SET created=?,pin_until=0',(old,))
        self.s.db.execute('UPDATE messages SET created=?',(old,))
        self.s.cleanup(force=True)
        ids={r[0] for r in self.s.db.execute('SELECT id FROM posts')}
        self.assertEqual(ids,{important,urgent})
        for table in ('messages','chat_media','message_details','replies','push_queue'):
            self.assertEqual(self.s.db.execute(f'SELECT count(*) FROM {table}').fetchone()[0],0,table)
    def test_device_registration_logout_and_queue(self):
        device='ab'*32
        self.call('POST','/devices',{'token':device,'environment':'sandbox'},self.b)
        self.error(400,'POST','/devices',{'token':'oops','environment':'sandbox'},self.b)
        cid=self.chat();self.call('POST',f'/conversations/{cid}/messages',{'body':'Hi'},self.a)
        self.assertEqual(self.s.db.execute('SELECT user_id FROM push_queue').fetchone()[0],self.uid(self.b))
        self.call('POST','/auth/logout',{'deviceToken':device},self.b)
        self.assertEqual(self.s.db.execute('SELECT count(*) FROM devices').fetchone()[0],0)
    def test_video_validation_and_media_review_failure(self):
        cid=self.chat()
        self.error(400,'POST',f'/conversations/{cid}/media',{'kind':'video','data':'invalid'},self.a)
        self.error(413,'POST',f'/conversations/{cid}/media',{'kind':'video','data':base64.b64encode(b'a'*(15*1024*1024+1)).decode()},self.a)
        self.s.photo_reviewer=lambda t,p:'pending'
        with self.assertRaises(APIError):self.photo(cid)
        self.assertEqual(self.s.db.execute('SELECT count(*) FROM chat_media').fetchone()[0],0)
    def test_push_payload_retry_and_revocation(self):
        import os
        from unittest.mock import MagicMock
        device='ab'*32
        self.call('POST','/devices',{'token':device,'environment':'sandbox'},self.b)
        cid=self.chat();self.call('POST',f'/conversations/{cid}/messages',{'body':'private text'},self.a)
        response=MagicMock();response.status_code=200
        client=MagicMock();client.post.return_value=response
        environment={'APNS_KEY_PATH':__file__,'APNS_KEY_ID':'test','APNS_TEAM_ID':'test','APNS_TOPIC':'org.test.Community'}
        with patch.dict(os.environ,environment), patch('jwt.encode',return_value='fake'),patch('httpx.Client') as http:
            http.return_value.__enter__.return_value=client
            self.s.deliver_pushes()
            payload=client.post.call_args.kwargs['json']
            self.assertEqual(payload['chatID'],cid)
            self.assertNotIn('private text',str(payload))
            self.assertEqual(self.s.db.execute('SELECT count(*) FROM push_queue').fetchone()[0],0)
            self.call('POST',f'/conversations/{cid}/messages',{'body':'another'},self.a)
            response.status_code=503;self.s.deliver_pushes()
            self.assertEqual(self.s.db.execute('SELECT attempts FROM push_queue').fetchone()[0],1)
            self.call('POST','/blocks',{'userID':self.uid(self.a)},self.b)
            self.s.db.execute('UPDATE push_queue SET retry_at=0')
            client.post.reset_mock();self.s.deliver_pushes();client.post.assert_not_called()
    def test_additive_migration_preserves_existing_account_and_posts(self):
        with tempfile.TemporaryDirectory() as folder:
            db=Path(folder)/'old.sqlite'
            old=Service(str(db),['buckley.org'],'test-secret'*4,reviewer=lambda t:'published')
            old.db.execute("INSERT INTO users(id,email,name,year) VALUES('legacy','legacy@buckley.org','Existing','Grade 12')")
            old.db.execute("INSERT INTO posts VALUES('post','legacy','Old post','Body','Question',0,'all','school','published',?,0)",(time.time(),))
            for table in ('credentials','password_grants','message_details','chat_media','devices','push_queue'):old.db.execute(f'DROP TABLE {table}')
            old.db.close()
            updated=Service(str(db),['buckley.org'],'test-secret'*4,reviewer=lambda t:'published')
            self.assertEqual(updated.db.execute('SELECT id FROM users').fetchone()[0],'legacy')
            self.assertEqual(updated.db.execute('SELECT title FROM posts').fetchone()[0],'Old post')
            self.assertEqual(updated.db.execute('SELECT count(*) FROM credentials').fetchone()[0],0)
            updated.db.close()
    def test_video_short_mp4(self):
        import subprocess,shutil
        if not shutil.which('ffmpeg'):self.skipTest('ffmpeg not installed')
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'test.mp4'
            subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=c=red:s=64x64:d=1','-c:v','mpeg4',str(path)],check=True)
            cid=self.chat();data=base64.b64encode(path.read_bytes()).decode()
            media=self.call('POST',f'/conversations/{cid}/media',{'kind':'video','data':data},self.a)['id']
            self.assertEqual(self.call('GET','/chat-media/'+media,token=self.a)['kind'],'video')

if __name__=='__main__':unittest.main()
