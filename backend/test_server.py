import json
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from server import Service, APIError, Handler

class SecurityTests(unittest.TestCase):
    def setUp(self):
        self.mail = {}
        self.service = Service(":memory:", ["students.example.edu"], "test-secret-" * 4,
            mailer=lambda email, code: self.mail.update({email: code}), reviewer=lambda text: "published")
        self.alice = self.register("alice")
        self.bob = self.register("bob")
        self.cara = self.register("cara")
    def tearDown(self): self.service.db.close()
    def register(self, name):
        email = name + "@students.example.edu"
        self.call("POST", "/auth/request", {"email": email})
        result = self.call("POST", "/auth/verify", {"email": email, "code": self.mail[email]})
        self.call("POST", "/auth/password", {"password": "test-password-123"}, result["token"])
        self.call("PATCH", "/profile", {"name": name, "year": "Grade 11", "bio": "", "instagram": ""}, result["token"])
        return result["token"]
    def call(self, method, path, body=None, token=""):
        return self.service.handle(method, path, body, token)
    def user_id(self, token): return self.call("GET", "/bootstrap", token=token)["me"]["id"]
    def assert_error(self, status, method, path, body=None, token=""):
        with self.assertRaises(APIError) as error: self.call(method, path, body, token)
        self.assertEqual(error.exception.status, status)
    def post(self, token=None, **changes):
        data = {"title": "A question", "body": "How can I join?", "kind": "Question", "anonymous": False, "groupID": "all", "visibility": "school"}
        data.update(changes)
        return self.call("POST", "/posts", data, token or self.alice)
    def test_unverified_access_denied(self):
        self.assert_error(401, "GET", "/bootstrap")
    def test_school_domain_exact_match(self):
        for email in ["a@students.example.edu.evil.com", "a@evil-students.example.edu", "a@example.edu", "a@students.example.edu@evil.com"]:
            with self.assertRaises(APIError): self.call("POST", "/auth/request", {"email": email})
    def test_otp_is_hashed_and_single_use(self):
        email = "next@students.example.edu"
        self.call("POST", "/auth/request", {"email": email})
        row = self.service.db.execute("SELECT * FROM otp WHERE email=?", (email,)).fetchone()
        self.assertNotIn(self.mail[email], row["digest"])
        data = {"email": email, "code": self.mail[email]}
        self.call("POST", "/auth/verify", data)
        self.assert_error(401, "POST", "/auth/verify", data)
    def test_otp_locks_after_five_wrong_attempts(self):
        email = "next@students.example.edu"
        self.call("POST", "/auth/request", {"email": email})
        for _ in range(5): self.assert_error(401, "POST", "/auth/verify", {"email": email, "code": "xxxxxx"})
        self.assert_error(401, "POST", "/auth/verify", {"email": email, "code": self.mail[email]})
    def test_expired_otp_rejected(self):
        email = "next@students.example.edu"
        self.call("POST", "/auth/request", {"email": email})
        self.service.db.execute("UPDATE otp SET expires=0 WHERE email=?", (email,))
        self.assert_error(401, "POST", "/auth/verify", {"email": email, "code": self.mail[email]})
    def test_logout_revokes_session(self):
        self.call("POST", "/auth/logout", token=self.alice)
        self.assert_error(401, "GET", "/bootstrap", token=self.alice)
    def test_anonymous_author_never_serialized(self):
        self.post(anonymous=True)
        post = self.call("GET", "/bootstrap", token=self.bob)["posts"][0]
        self.assertIsNone(post["author"])
        self.assertNotIn(self.user_id(self.alice), json.dumps(post))
        self.assertNotIn("email", json.dumps(post))
    def test_targeting_does_not_make_public_post_private(self):
        self.post(groupID="mentors")
        self.assertEqual(len(self.call("GET", "/bootstrap", token=self.bob)["posts"]), 1)
    def test_group_visibility_enforced(self):
        aid, bid = self.user_id(self.alice), self.user_id(self.bob)
        self.service.db.executemany("INSERT INTO memberships VALUES(?, 'international')", [(aid,), (bid,)])
        self.post(groupID="international", visibility="group")
        post = self.call("GET", "/bootstrap", token=self.bob)["posts"][0]
        self.assertEqual(self.call("GET", "/bootstrap", token=self.cara)["posts"], [])
        self.assert_error(404, "POST", f"/posts/{post['id']}/replies", {"body": "Secret?"}, self.cara)
        self.assert_error(404, "POST", "/reports", {"postID": post["id"], "reason": "Try access"}, self.cara)
    def test_nonmember_cannot_post_privately(self):
        with self.assertRaises(APIError): self.post(groupID="mentors", visibility="group")
    def test_moderation_cannot_be_bypassed(self):
        self.service.reviewer = lambda text: "pending"
        self.assertEqual(self.post(status="published", important=True)["status"], "pending")
        self.assertEqual(self.call("GET", "/bootstrap", token=self.bob)["posts"], [])
    def test_moderation_failure_does_not_store_post(self):
        def fail(text): raise APIError(503, "Unavailable")
        self.service.reviewer = fail
        with self.assertRaises(APIError): self.post()
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM posts").fetchone()[0], 0)
    def test_invalid_review_result_fails_closed(self):
        self.service.reviewer = lambda text: None
        with self.assertRaises(APIError): self.post()
    def test_role_and_id_cannot_be_self_assigned(self):
        aid = self.user_id(self.alice)
        self.call("PATCH", "/profile", {"id": "someone-else", "role": "Teacher", "name": "Alice", "year": "Grade 11", "bio": "Hello", "instagram": "alice"}, self.alice)
        me = self.call("GET", "/bootstrap", token=self.alice)["me"]
        self.assertEqual(me["role"], "Student"); self.assertEqual(me["id"], aid)
    def test_chat_membership_and_blocking(self):
        bid = self.user_id(self.bob)
        chat = self.call("POST", "/conversations", {"peerID": bid}, self.alice)
        path = f"/conversations/{chat['id']}/messages"
        self.assert_error(404, "POST", path, {"body": "Intruder"}, self.cara)
        self.call("POST", path, {"body": "Hello", "senderID": self.user_id(self.cara)}, self.alice)
        messages = self.call("GET", "/bootstrap", token=self.bob)["conversations"][0]["messages"]
        self.assertEqual(messages[0]["senderID"], self.user_id(self.alice))
        self.call("POST", "/blocks", {"userID": bid}, self.alice)
        self.assert_error(403, "POST", path, {"body": "Blocked"}, self.bob)
        self.assertEqual(self.call("GET", "/bootstrap", token=self.bob)["conversations"], [])
    def test_report_recorded(self):
        self.post()
        post_id = self.call("GET", "/bootstrap", token=self.bob)["posts"][0]["id"]
        self.call("POST", "/reports", {"postID": post_id, "reason": "Please review"}, self.bob)
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM reports").fetchone()[0], 1)
    def test_post_rate_limit(self):
        for _ in range(5): self.post()
        with self.assertRaises(APIError) as error: self.post()
        self.assertEqual(error.exception.status, 429)
    def test_sql_injection_is_stored_as_text(self):
        self.post(title="'); DROP TABLE users; --")
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM users").fetchone()[0], 3)
    def test_malformed_settings_rejected(self):
        for changes in [{"anonymous": "false"}, {"groupID": "no-such-group"}, {"title": " "}, {"kind": "Other"}]:
            with self.assertRaises(APIError): self.post(**changes)
    def test_http_round_trip_and_payload_limit(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        server.service = self.service
        worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
        try:
            base = "http://127.0.0.1:" + str(server.server_port)
            request = urllib.request.Request(base+"/bootstrap", headers={"Authorization": "Bearer "+self.alice})
            with urllib.request.urlopen(request) as response:
                self.assertEqual(response.headers["Cache-Control"], "no-store")
                self.assertIn("me", json.load(response))
            request = urllib.request.Request(base+"/posts", data=b"x"*20001, method="POST")
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request)
            self.assertEqual(error.exception.code, 413)
        finally:
            server.shutdown(); server.server_close(); worker.join()

    def create_group(self):
        return self.call("POST", "/group-conversations", {"title": "New student helpers", "participantIDs": [self.user_id(self.bob), self.user_id(self.cara)]}, self.alice)
    def test_group_create_includes_exact_members(self):
        group = self.create_group()
        self.assertEqual(group["kind"], "group")
        self.assertEqual({p["id"] for p in group["participants"]}, {self.user_id(t) for t in [self.alice,self.bob,self.cara]})
        for token in [self.alice, self.bob, self.cara]:
            self.assertIn(group["id"], [c["id"] for c in self.call("GET", "/bootstrap", token=token)["conversations"]])
    def test_group_outsider_cannot_read_or_send(self):
        outsider = self.register("outsider")
        group = self.create_group()
        path = "/conversations/" + group["id"]
        self.assert_error(404, "GET", path, token=outsider)
        self.assert_error(404, "POST", path+"/messages", {"body":"intruder"}, outsider)
        self.assertNotIn(group["id"], [c["id"] for c in self.call("GET", "/bootstrap", token=outsider)["conversations"]])
    def test_group_sender_identity_and_shared_delivery(self):
        group = self.create_group()
        path = "/conversations/" + group["id"]
        self.call("POST", path+"/messages", {"body":"Hello team", "senderID":self.user_id(self.alice)}, self.bob)
        received = self.call("GET", path, token=self.cara)["messages"]
        self.assertEqual(received[0]["body"], "Hello team")
        self.assertEqual(received[0]["senderID"], self.user_id(self.bob))
    def test_group_leave_revokes_history_and_sending(self):
        group = self.create_group()
        path = "/conversations/" + group["id"]
        self.call("POST", path+"/leave", token=self.bob)
        self.assert_error(404, "GET", path, token=self.bob)
        self.assert_error(404, "POST", path+"/messages", {"body":"Still here?"}, self.bob)
        self.assertEqual(len(self.call("GET", path, token=self.cara)["participants"]),2)
    def test_group_blocks_hide_messages_not_whole_group(self):
        group = self.create_group()
        path = "/conversations/" + group["id"]
        self.call("POST", path+"/messages", {"body":"Hello"}, self.bob)
        self.call("POST", "/blocks", {"userID":self.user_id(self.bob)}, self.alice)
        self.assertEqual(self.call("GET", path, token=self.alice)["messages"], [])
        self.assertEqual(len(self.call("GET", path, token=self.cara)["messages"]), 1)
        self.assert_error(403, "POST", "/group-conversations", {"title":"Again", "participantIDs":[self.user_id(self.bob), self.user_id(self.cara)]}, self.alice)
    def test_group_invalid_members_rejected_atomically(self):
        bid, cid, aid = self.user_id(self.bob),self.user_id(self.cara),self.user_id(self.alice)
        for ids in [[bid,bid], [aid,bid], [bid], [bid,"unknown"], [bid,{}]]:
            with self.assertRaises(APIError): self.call("POST", "/group-conversations", {"title":"Invalid", "participantIDs":ids},self.alice)
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM group_chats").fetchone()[0],0)
    def test_group_title_and_message_moderation(self):
        self.service.reviewer = lambda text: "pending"
        self.assert_error(422,"POST","/group-conversations",{"title":"Review me","participantIDs":[self.user_id(self.bob),self.user_id(self.cara)]},self.alice)
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM group_chats").fetchone()[0],0)
        self.service.reviewer = lambda text: "published"
        group=self.create_group()
        self.service.reviewer = lambda text: "pending"
        self.assert_error(422,"POST","/conversations/"+group["id"]+"/messages",{"body":"Review me"},self.alice)
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM group_messages").fetchone()[0],0)
    def test_member_directory_requires_auth_and_omits_emails(self):
        self.assert_error(401,"GET","/members")
        members=self.call("GET","/members",token=self.alice)
        self.assertEqual(len(members),2)
        self.assertNotIn("email",json.dumps(members))
        self.assertNotIn(self.user_id(self.alice),[p["id"] for p in members])
    def test_existing_private_database_upgrade(self):
        import tempfile, sqlite3
        from pathlib import Path
        direct=self.call("POST","/conversations",{"peerID":self.user_id(self.bob)},self.alice)
        self.call("POST","/conversations/"+direct["id"]+"/messages",{"body":"Before upgrade"},self.alice)
        with tempfile.TemporaryDirectory() as temp:
            path=str(Path(temp)/"legacy.sqlite")
            old=sqlite3.connect(path)
            self.service.db.backup(old)
            for table in ["group_messages","chat_members","group_chats"]:old.execute("DROP TABLE "+table)
            old.commit();old.close()
            updated=Service(path,["students.example.edu"],"test-secret-"*4,mailer=lambda *args:None,reviewer=lambda text:"published")
            try:
                data=updated.handle("GET","/bootstrap",token=self.alice)
                self.assertEqual(data["conversations"][0]["messages"][0]["body"],"Before upgrade")
                self.assertEqual(data["conversations"][0]["kind"],"direct")
            finally:updated.db.close()

    def test_priority_cannot_self_pin_and_can_be_downgraded(self):
        self.service.priority_reviewer = lambda text: 'normal'
        result = self.post(priority='urgent', important=True, pin_until=9999999999)
        self.assertEqual(result['priority'], 'normal')
        post = self.call('GET','/bootstrap',token=self.bob)['posts'][0]
        self.assertFalse(post['important'])
        self.assertEqual(post['priority'],'normal')

    def test_approved_urgent_expires_and_duplicate_pin_is_lowered(self):
        self.service.priority_reviewer = lambda text: 'urgent'
        self.assertEqual(self.post(priority='urgent')['priority'],'urgent')
        post = self.call('GET','/bootstrap',token=self.bob)['posts'][0]
        self.assertTrue(post['important'])
        expiry = self.service.db.execute('SELECT pin_until FROM posts').fetchone()[0]
        self.assertAlmostEqual(expiry-time.time(),86400,delta=3)
        self.assertEqual(self.post(priority='urgent')['priority'],'important')
        self.service.db.execute('UPDATE posts SET pin_until=0')
        self.assertFalse(any(p['important'] for p in self.call('GET','/bootstrap',token=self.bob)['posts']))

    def test_flagged_content_never_gets_priority_approval(self):
        self.service.reviewer = lambda text: 'pending'
        self.service.priority_reviewer = lambda text: self.fail('Flagged content must not be pinned')
        self.assertEqual(self.post(priority='urgent')['status'],'pending')
        self.assertEqual(self.service.db.execute('SELECT pin_until FROM posts').fetchone()[0],0)
        self.assertEqual(self.call('GET','/bootstrap',token=self.bob)['posts'],[])

    def test_priority_failure_does_not_publish(self):
        for result in ['invalid', None, {}, 2]:
            self.service.priority_reviewer = lambda text: result
            with self.assertRaises(APIError): self.post(priority='urgent')
        self.assertEqual(self.service.db.execute('SELECT count(*) FROM posts').fetchone()[0],0)

    def test_priority_cannot_exceed_request_and_group_visibility_survives_pin(self):
        self.service.priority_reviewer = lambda text: 'urgent'
        self.assertEqual(self.post(priority='important')['priority'],'important')
        aid = self.user_id(self.alice)
        self.service.db.execute('INSERT INTO memberships VALUES(?,?)',(aid,'mentors'))
        self.post(priority='urgent',groupID='mentors',visibility='group')
        self.assertEqual(len(self.call('GET','/bootstrap',token=self.bob)['posts']),1)
        self.assertTrue(any(p['important'] for p in self.call('GET','/bootstrap',token=self.alice)['posts']))

    def test_group_supports_100_members_but_not_101(self):
        ids=[]
        for i in range(100):
            uid='large-'+str(i);ids.append(uid)
            self.service.db.execute('INSERT INTO users(id,email,name) VALUES(?,?,?)',(uid,uid+'@students.example.edu',uid))
        group=self.call('POST','/group-conversations',{'title':'Grade group','participantIDs':ids[:99]},self.alice)
        self.assertEqual(len(group['participants']),100)
        self.assert_error(400,'POST','/group-conversations',{'title':'Too big','participantIDs':ids},self.alice)

    def test_all_post_categories_round_trip(self):
        kinds = ["Question", "Advice", "Club Meeting", "Lost & Found", "Events", "Study", "Resources", "Buy & Sell", "Volunteering", "General"]
        for kind in kinds:
            self.service.rates.clear()
            self.post(kind=kind)
        actual = [p['kind'] for p in self.call('GET','/bootstrap',token=self.bob)['posts']]
        self.assertEqual(set(actual),set(kinds))

    def test_mention_is_personal_and_expires(self):
        bid=self.user_id(self.bob)
        self.post(askedUserID=bid)
        bob=self.call('GET','/bootstrap',token=self.bob)['posts'][0]
        cara=self.call('GET','/bootstrap',token=self.cara)['posts'][0]
        self.assertEqual(bob['askedPerson']['id'],bid)
        self.assertAlmostEqual(bob['requestedAnswerUntil']-time.time(),86400,delta=3)
        self.assertFalse(bob['important'])
        self.assertIsNone(cara['requestedAnswerUntil'])
        self.service.db.execute('UPDATE post_mentions SET expires=?',(time.time()-1,))
        self.assertLess(self.call('GET','/bootstrap',token=self.bob)['posts'][0]['requestedAnswerUntil'],time.time())

    def test_invalid_mention_target_or_kind_is_rejected(self):
        aid,bid=self.user_id(self.alice),self.user_id(self.bob)
        for changes in [dict(askedUserID=aid),dict(askedUserID='missing'),dict(askedUserID={}),dict(askedUserID=bid,kind='Events')]:
            with self.assertRaises(APIError):self.post(**changes)
        self.assertEqual(self.service.db.execute('SELECT count(*) FROM posts').fetchone()[0],0)

    def test_mention_respects_group_and_blocks(self):
        aid,bid=self.user_id(self.alice),self.user_id(self.bob)
        self.service.db.execute('INSERT INTO memberships VALUES(?,?)',(aid,'mentors'))
        with self.assertRaises(APIError):self.post(askedUserID=bid,groupID='mentors',visibility='group')
        self.service.db.execute('INSERT INTO memberships VALUES(?,?)',(bid,'mentors'))
        self.post(askedUserID=bid,groupID='mentors',visibility='group')
        self.assertEqual(self.call('GET','/bootstrap',token=self.cara)['posts'],[])
        self.call('POST','/blocks',{'userID':aid},self.bob)
        self.assertEqual(self.call('GET','/bootstrap',token=self.bob)['posts'],[])
        with self.assertRaises(APIError):self.post(askedUserID=bid)

    def test_mention_rate_limit_and_pending_invisibility(self):
        bid=self.user_id(self.bob)
        self.service.reviewer=lambda text:'pending'
        for _ in range(3):self.post(askedUserID=bid)
        self.assertEqual(self.call('GET','/bootstrap',token=self.bob)['posts'],[])
        self.assertEqual(self.service.db.execute('SELECT max(expires) FROM post_mentions').fetchone()[0],0)
        with self.assertRaises(APIError) as error:self.post(askedUserID=bid)
        self.assertEqual(error.exception.status,429)

    def test_moderator_approval_starts_24_hours_once(self):
        import tempfile,sqlite3,subprocess,sys
        from pathlib import Path
        self.service.reviewer=lambda text:'pending'
        self.post(askedUserID=self.user_id(self.bob))
        post_id=self.service.db.execute('SELECT id FROM posts').fetchone()[0]
        with tempfile.TemporaryDirectory() as directory:
            dbpath=str(Path(directory)/'review.sqlite')
            copy=sqlite3.connect(dbpath);self.service.db.backup(copy);copy.close()
            command=[sys.executable,str(Path(__file__).with_name('admin.py')),'--db',dbpath,'review','post',post_id]
            subprocess.run(command+['published'],check=True,capture_output=True)
            copy=sqlite3.connect(dbpath)
            expiry=copy.execute('SELECT expires FROM post_mentions').fetchone()[0]
            self.assertAlmostEqual(expiry-time.time(),86400,delta=3)
            subprocess.run(command+['published'],check=True,capture_output=True)
            self.assertEqual(copy.execute('SELECT expires FROM post_mentions').fetchone()[0],expiry)
            subprocess.run(command+['rejected'],check=True,capture_output=True)
            self.assertEqual(copy.execute('SELECT expires FROM post_mentions').fetchone()[0],0)
            copy.close()

    def test_active_mentions_not_lost_after_500_new_posts(self):
        self.post(askedUserID=self.user_id(self.bob))
        aid=self.user_id(self.alice)
        for i in range(501):
            self.service.db.execute('INSERT INTO posts VALUES(?,?,?,?,?,?,?,?,?,?,?)',(str(i),aid,'Later','Later','Question',0,'all','school','published',time.time()+i,0))
        posts=self.call('GET','/bootstrap',token=self.bob)['posts']
        self.assertTrue(any(p['requestedAnswerUntil'] for p in posts))

    def photo(self, token=None):
        import base64, io
        from PIL import Image
        image = Image.new("RGB", (32, 24), "red")
        output = io.BytesIO()
        exif = Image.Exif(); exif[0x010E] = "Private camera metadata"
        image.save(output, format="JPEG", exif=exif)
        return self.call("POST", "/photos", {"jpeg": base64.b64encode(output.getvalue()).decode()}, token or self.alice)["id"]

    def test_photo_upload_requires_login_and_real_jpeg(self):
        self.assert_error(401, "POST", "/photos", {"jpeg": "a"})
        self.assert_error(400, "POST", "/photos", {"jpeg": "invalid!"}, self.alice)
        self.assert_error(413, "POST", "/photos", {"jpeg": "x"*700001}, self.alice)

    def test_unused_photo_is_private_and_metadata_is_removed(self):
        import base64, io
        from PIL import Image
        photo = self.photo()
        self.assert_error(404, "GET", "/photos/"+photo, token=self.bob)
        response = self.call("GET", "/photos/"+photo, token=self.alice)
        with Image.open(io.BytesIO(base64.b64decode(response["jpeg"]))) as image:
            self.assertEqual(image.size, (32, 24))
            self.assertFalse(image.getexif())

    def test_gallery_publishes_photos_without_required_caption(self):
        photo = self.photo()
        reviewed = []
        self.service.photo_reviewer = lambda text, images: reviewed.append(images) or "published"
        result = self.post(kind="Photo Gallery", body="", photoIDs=[photo])
        self.assertEqual(result["status"], "published")
        feed = self.call("GET", "/bootstrap", token=self.bob)
        self.assertEqual(feed["posts"][0]["photoIDs"], [photo])
        self.assertNotIn("jpeg", json.dumps(feed))
        self.assertEqual(len(reviewed[0]), 1)
        self.assertIn("jpeg", self.call("GET", "/photos/"+photo, token=self.bob))

    def test_gallery_cannot_attach_another_users_photo_or_reuse_one(self):
        photo = self.photo()
        self.service.photo_reviewer = lambda *_: "published"
        with self.assertRaises(APIError) as error: self.post(token=self.bob, kind="Photo Gallery", photoIDs=[photo])
        self.assertEqual(error.exception.status, 403)
        self.post(kind="Photo Gallery", photoIDs=[photo])
        with self.assertRaises(APIError): self.post(kind="Photo Gallery", photoIDs=[photo])

    def test_gallery_requires_one_to_twenty_unique_photos(self):
        for ids in [[], ["x"]*21, ["x", "x"], "x", [1]]:
            with self.assertRaises(APIError) as error: self.post(kind="Photo Gallery", photoIDs=ids)
            self.assertEqual(error.exception.status, 400)

    def test_photo_permission_follows_private_post_block_and_removal(self):
        photo = self.photo()
        aid = self.user_id(self.alice)
        self.service.db.execute("INSERT INTO memberships VALUES(?,?)", (aid, "mentors"))
        self.service.photo_reviewer = lambda *_: "published"
        self.post(kind="Photo Gallery", photoIDs=[photo], groupID="mentors", visibility="group")
        self.assert_error(404, "GET", "/photos/"+photo, token=self.bob)
        bid = self.user_id(self.bob)
        self.service.db.execute("INSERT INTO memberships VALUES(?,?)", (bid, "mentors"))
        self.assertIn("jpeg", self.call("GET", "/photos/"+photo, token=self.bob))
        self.service.db.execute("INSERT INTO blocks VALUES(?,?)", (bid, aid))
        self.assert_error(404, "GET", "/photos/"+photo, token=self.bob)
        self.service.db.execute("DELETE FROM blocks")
        self.service.db.execute("UPDATE posts SET status='removed'")
        self.assert_error(404, "GET", "/photos/"+photo, token=self.bob)

    def test_flagged_photo_holds_whole_post(self):
        photo = self.photo()
        self.service.photo_reviewer = lambda *_: "pending"
        self.assertEqual(self.post(kind="Photo Gallery", photoIDs=[photo])["status"], "pending")
        self.assertEqual(self.call("GET", "/bootstrap", token=self.bob)["posts"], [])
        self.assert_error(404, "GET", "/photos/"+photo, token=self.bob)

    def test_image_review_failure_does_not_publish_and_can_retry(self):
        photo = self.photo()
        self.service.photo_reviewer = lambda *_: "invalid"
        with self.assertRaises(APIError): self.post(kind="Photo Gallery", photoIDs=[photo])
        self.assertEqual(self.service.db.execute("SELECT count(*) FROM posts").fetchone()[0], 0)
        self.service.photo_reviewer = lambda *_: "published"
        self.assertEqual(self.post(kind="Photo Gallery", photoIDs=[photo])["status"], "published")

    def test_non_gallery_cannot_attach_photos(self):
        photo = self.photo()
        with self.assertRaises(APIError) as error: self.post(photoIDs=[photo])
        self.assertEqual(error.exception.status, 400)

    def test_twenty_photo_gallery_round_trip_preserves_order(self):
        ids = [self.photo() for _ in range(20)]
        reviewed = []
        self.service.photo_reviewer = lambda text, images: reviewed.append(len(images)) or "published"
        self.assertEqual(self.post(kind="Photo Gallery", photoIDs=ids)["status"], "published")
        post = self.call("GET", "/bootstrap", token=self.bob)["posts"][0]
        self.assertEqual(post["photoIDs"], ids)
        self.assertEqual(reviewed, [20])
        # A full album must not consume the entire hourly upload allowance.
        self.assertIn("jpeg", self.call("GET", "/photos/"+self.photo(), token=self.alice))

    def test_twenty_one_distinct_photos_rejected_before_review(self):
        self.service.photo_reviewer = lambda *_: self.fail("oversized gallery reached review")
        with self.assertRaises(APIError) as error:
            self.post(kind="Photo Gallery", photoIDs=[str(i) for i in range(21)])
        self.assertEqual(error.exception.status, 400)

if __name__ == "__main__": unittest.main(verbosity=2)
