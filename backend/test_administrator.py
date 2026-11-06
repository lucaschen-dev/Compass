import base64
import io
import json
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from server import Service, APIError

class AdministratorTests(unittest.TestCase):
    def setUp(self):
        self.mail={}
        self.s=Service(':memory:',['buckley.org'],'test-secret'*4,mailer=lambda e,c:self.mail.update({e:c}),reviewer=lambda t:'published')
        self.a=self.register('owner');self.b=self.register('student');self.c=self.register('reporter')
        self.aid=self.uid(self.a);self.bid=self.uid(self.b)
        self.s.db.execute("UPDATE users SET role='Administrator' WHERE id=?",(self.aid,))
    def tearDown(self):self.s.db.close()
    def call(self,method,path,body=None,token=''):return self.s.handle(method,path,body,token)
    def register(self,name):
        email=name+'@buckley.org';self.call('POST','/auth/request',{'email':email})
        token=self.call('POST','/auth/verify',{'email':email,'code':self.mail[email]})['token']
        self.call('POST','/auth/password',{'password':'a-long-password'},token)
        self.call('PATCH','/profile',{'name':name,'year':'Grade 11'},token)
        return token
    def uid(self,token):return self.call('GET','/bootstrap',token=token)['me']['id']
    def error(self,status,method,path,body=None,token=''):
        with self.assertRaises(APIError) as e:self.call(method,path,body,token)
        self.assertEqual(e.exception.status,status)
    def post(self):
        self.call('POST','/posts',dict(title='Anonymous post',body='Content',kind='Question',groupID='all',visibility='school',anonymous=True),self.b)
        return self.call('GET','/posts/mine',token=self.b)[0]['id']
    def report(self,pid,token=None):
        self.call('POST','/reports',{'postID':pid,'reason':'Please review'},token or self.c)
        return self.call('POST','/admin/reports/list',{'status':'open'},self.a)['items'][0]['id']
    def test_student_denied_admin_endpoints_and_cannot_change_role(self):
        pid=self.post();rid=self.report(pid)
        routes=[('POST','/admin/posts/list',{}),('POST','/admin/reports/list',{}),('GET','/admin/posts/'+pid,{}),('DELETE','/admin/posts/'+pid,{}),('PATCH','/admin/posts/'+pid,{'status':'rejected'}),('POST',f'/admin/reports/{rid}/resolve',{'decision':'deleted'})]
        for method,path,body in routes:self.error(403,method,path,body,self.b)
        self.call('PATCH','/profile',{'name':'Student','year':'Grade 11','role':'Administrator'},self.b)
        self.assertEqual(self.call('GET','/bootstrap',token=self.b)['me']['role'],'Student')
        self.assertIsNone(self.call('GET','/bootstrap',token=self.b)['openReports'])
    def test_anonymous_identity_only_in_admin_endpoint(self):
        pid=self.post()
        normal=self.call('GET','/bootstrap',token=self.a)['posts'][0]
        self.assertIsNone(normal['author']);self.assertNotIn(self.bid,json.dumps(normal))
        item=self.call('GET','/admin/posts/'+pid,token=self.a)
        self.assertEqual(item['author']['id'],self.bid)
        self.assertEqual(item['authorEmail'],'student@buckley.org')
        self.assertIsNone(item['post']['author'])
    def test_admin_sees_private_pending_and_blocked_posts(self):
        pid=self.post()
        self.s.db.execute("UPDATE posts SET status='pending',visibility='group',group_id='mentors' WHERE id=?",(pid,))
        self.call('POST','/blocks',{'userID':self.aid},self.b)
        self.assertEqual(self.call('GET','/bootstrap',token=self.a)['posts'],[])
        page=self.call('POST','/admin/posts/list',{'status':'pending'},self.a)
        self.assertEqual(page['items'][0]['id'] if 'id' in page['items'][0] else page['items'][0]['post']['id'],pid)
        self.assertEqual(self.call('GET','/admin/posts/'+pid,token=self.a)['post']['status'],'pending')
    def test_report_delete_resolves_all_cases_and_preserves_receipt(self):
        pid=self.post();rid=self.report(pid);self.report(pid,self.a)
        self.assertEqual(self.call('GET','/bootstrap',token=self.a)['openReports'],2)
        self.call('POST',f'/admin/reports/{rid}/resolve',{'decision':'deleted','note':'Removed'},self.a)
        page=self.call('POST','/admin/reports/list',{'status':'resolved'},self.a)
        self.assertEqual(len(page['items']),2);self.assertEqual(page['openReports'],0)
        self.assertTrue(all(r['decision']=='deleted' and not r['postExists'] for r in page['items']))
        self.error(404,'GET','/admin/posts/'+pid,token=self.a)
        self.error(409,'POST',f'/admin/reports/{rid}/resolve',{'decision':'dismissed'},self.a)
    def test_author_deleting_post_does_not_erase_open_report(self):
        pid=self.post();rid=self.report(pid)
        self.call('DELETE','/posts/'+pid,token=self.b)
        page=self.call('POST','/admin/reports/list',{'status':'open'},self.a)
        self.assertEqual(page['items'][0]['id'],rid);self.assertFalse(page['items'][0]['postExists'])
        self.call('POST',f'/admin/reports/{rid}/resolve',{'decision':'dismissed'},self.a)
        self.assertEqual(self.call('POST','/admin/reports/list',{'status':'open'},self.a)['items'],[])
    def test_dismiss_keeps_post_and_records_actor(self):
        pid=self.post();rid=self.report(pid)
        self.call('POST',f'/admin/reports/{rid}/resolve',{'decision':'dismissed','note':'No issue'},self.a)
        row=self.call('POST','/admin/reports/list',{'status':'resolved'},self.a)['items'][0]
        self.assertEqual(row['resolvedBy']['id'],self.aid);self.assertTrue(row['postExists'])
        self.assertIn(self.aid,self.s.db.execute("SELECT action FROM audit WHERE object_id=? ORDER BY id DESC",(rid,)).fetchone()[0])
    def test_pending_approval_rejection_and_comment_deletion(self):
        pid=self.post();self.call('POST',f'/posts/{pid}/replies',{'body':'Comment'},self.c)
        comment=self.call('GET','/admin/posts/'+pid,token=self.a)['post']['replies'][0]['id']
        self.error(403,'DELETE','/admin/replies/'+comment,token=self.b)
        self.call('DELETE','/admin/replies/'+comment,token=self.a)
        self.s.db.execute("UPDATE posts SET status='pending' WHERE id=?",(pid,))
        self.call('PATCH','/admin/posts/'+pid,{'status':'published'},self.a)
        self.assertEqual(len(self.call('GET','/bootstrap',token=self.c)['posts']),1)
        self.call('PATCH','/admin/posts/'+pid,{'status':'rejected'},self.a)
        self.assertEqual(self.call('GET','/bootstrap',token=self.c)['posts'],[])
    def test_admin_photo_access_for_pending_private_post(self):
        from PIL import Image
        out=io.BytesIO();Image.new('RGB',(20,20),'red').save(out,format='JPEG')
        photo=self.call('POST','/photos',{'jpeg':base64.b64encode(out.getvalue()).decode()},self.b)['id']
        pid=self.post();self.s.db.execute('INSERT INTO post_photos VALUES(?,?,0)',(pid,photo))
        self.s.db.execute("UPDATE posts SET status='pending',visibility='group',group_id='mentors' WHERE id=?",(pid,))
        self.assertIn('jpeg',self.call('GET','/photos/'+photo,token=self.a))
        self.error(404,'GET','/photos/'+photo,token=self.c)
        unused=self.call('POST','/photos',{'jpeg':base64.b64encode(out.getvalue()).decode()},self.b)['id']
        self.error(404,'GET','/photos/'+unused,token=self.a)
    def test_role_revocation_is_immediate(self):
        pid=self.post();self.s.db.execute("UPDATE users SET role='Student' WHERE id=?",(self.aid,))
        self.error(403,'GET','/admin/posts/'+pid,token=self.a)
    def test_admin_pagination_search_and_filter_validation(self):
        now=time.time()
        for index in range(28):self.s.db.execute("INSERT INTO posts VALUES(?,?,?,?,?,?,?,?,'published',?,0)",(f'p{index}',self.bid,f'Title {index}','Body','Question',1,'all','school',now+index))
        page=self.call('POST','/admin/posts/list',{'status':'all'},self.a)
        self.assertEqual(len(page['items']),25);self.assertEqual(page['nextOffset'],25)
        more=self.call('POST','/admin/posts/list',{'offset':25},self.a)
        self.assertEqual(len(more['items']),3);self.assertIsNone(more['nextOffset'])
        self.assertEqual(len(self.call('POST','/admin/posts/list',{'query':'Title 27'},self.a)['items']),1)
        self.assertEqual(len(self.call('POST','/admin/posts/list',{'query':'%'},self.a)['items']),0)
        self.error(400,'POST','/admin/posts/list',{'offset':-1},self.a)
        self.error(400,'POST','/admin/reports/list',{'status':'wrong'},self.a)
    def test_report_retention(self):
        pid=self.post();rid=self.report(pid)
        old=time.time()-31*86400
        self.s.db.execute('UPDATE moderation_reports SET created=?',(old,))
        self.s.db.execute('UPDATE reports SET created=?',(old,))
        self.s.cleanup(force=True)
        self.assertEqual(self.call('POST','/admin/reports/list',{},self.a)['items'],[])
    def test_report_push_only_for_administrator_and_no_private_body(self):
        import os
        from unittest.mock import patch, MagicMock
        self.call('POST','/devices',{'token':'ab'*32,'environment':'sandbox'},self.a)
        self.call('POST','/devices',{'token':'cd'*32,'environment':'sandbox'},self.b)
        pid=self.post();rid=self.report(pid)
        jobs=self.s.db.execute("SELECT * FROM push_queue WHERE chat_id='admin-reports'").fetchall()
        self.assertEqual(len(jobs),1);self.assertEqual(jobs[0]['user_id'],self.aid)
        client=MagicMock();client.post.return_value.status_code=200
        environment={'APNS_KEY_PATH':__file__,'APNS_KEY_ID':'test','APNS_TEAM_ID':'test','APNS_TOPIC':'org.test.Community'}
        with patch.dict(os.environ,environment),patch('jwt.encode',return_value='fake'),patch('httpx.Client') as http:
            http.return_value.__enter__.return_value=client
            self.s.deliver_pushes()
            self.assertEqual(client.post.call_count,1)
            payload=client.post.call_args.kwargs['json']
            self.assertTrue(payload['adminReports']);self.assertNotIn('Please review',str(payload))
            self.assertNotIn('reporter',str(payload))
            self.report(pid);self.s.db.execute("UPDATE users SET role='Student' WHERE id=?",(self.aid,))
            client.post.reset_mock();self.s.deliver_pushes();client.post.assert_not_called()
    def test_local_bootstrap_first_account_and_repeat(self):
        with tempfile.TemporaryDirectory() as folder:
            db=Path(folder)/'db.sqlite'
            service=Service(str(db),['buckley.org'],'test-secret'*4)
            for uid in ('first','second'):service.db.execute('INSERT INTO users(id,email,name) VALUES(?,?,?)',(uid,uid+'@buckley.org',uid))
            service.db.close()
            command=[sys.executable,str(Path(__file__).with_name('admin.py')),'--db',str(db),'bootstrap-administrator']
            first=subprocess.run(command,capture_output=True,text=True,check=True)
            self.assertIn('Administrator: first@buckley.org',first.stdout)
            subprocess.run(command,capture_output=True,text=True,check=True)
            import sqlite3
            con=sqlite3.connect(db)
            self.assertEqual(con.execute("SELECT id FROM users WHERE role='Administrator'").fetchall(),[('first',)])
            self.assertEqual(con.execute("SELECT count(*) FROM audit").fetchone()[0],1)
            con.close()

if __name__=='__main__':unittest.main()
