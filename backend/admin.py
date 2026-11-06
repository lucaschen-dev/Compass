#!/usr/bin/env python3
"""Local operator commands. Never expose this interface as a public endpoint."""
import argparse
import json
import os
import sqlite3
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default=os.getenv("COMMONS_DB", "data/commons.sqlite"))
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("pending")
    sub.add_parser("reports")
    sub.add_parser("bootstrap-administrator", help="Promote the earliest stored verified account; local server operator only")
    review = sub.add_parser("review")
    review.add_argument("kind", choices=["post", "reply"])
    review.add_argument("id")
    review.add_argument("decision", choices=["published", "rejected"])
    group = sub.add_parser("group")
    group.add_argument("email")
    group.add_argument("group_id")
    group.add_argument("action", choices=["add", "remove"])
    role = sub.add_parser("role")
    role.add_argument("email")
    role.add_argument("role", choices=["Student", "Mentor", "Teacher", "Administrator"])
    pin = sub.add_parser("pin")
    pin.add_argument("post_id")
    pin.add_argument("hours", type=int)
    resolve = sub.add_parser("resolve-report")
    resolve.add_argument("id")
    args = parser.parse_args()
    db = sqlite3.connect(f"file:{args.db}?mode=rw", uri=True)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    with db:
        if args.command == "bootstrap-administrator":
            first = db.execute("SELECT id,email,name,role FROM users ORDER BY rowid ASC LIMIT 1").fetchone()
            if not first: raise SystemExit("No verified accounts found. No administrator was created.")
            existing = db.execute("SELECT id FROM users WHERE role='Administrator' AND id!=?", (first["id"],)).fetchone()
            if existing: raise SystemExit("Another administrator already exists. Use the explicit role command for a specific email.")
            if first["role"] != "Administrator":
                db.execute("UPDATE users SET role='Administrator' WHERE id=?", (first["id"],))
                db.execute("INSERT INTO audit(action,object_id,created) VALUES(?,?,?)", ("operator:bootstrap-administrator", first["id"], time.time()))
            print("Administrator: " + first["email"] + " (" + first["name"] + ")")
        elif args.command == "pending":
            result = {table: [dict(r) for r in db.execute(f"SELECT * FROM {table} WHERE status='pending'")] for table in ["posts", "replies"]}
            print(json.dumps(result, indent=2))
        elif args.command == "reports":
            print(json.dumps([dict(r) for r in db.execute("SELECT * FROM reports WHERE resolved=0")], indent=2))
        elif args.command == "review":
            table = "posts" if args.kind == "post" else "replies"
            previous = db.execute(f"SELECT status FROM {table} WHERE id=?", (args.id,)).fetchone()
            cursor = db.execute(f"UPDATE {table} SET status=? WHERE id=?", (args.decision, args.id))
            if cursor.rowcount != 1: raise SystemExit("Content not found")
            if args.kind == "post":
                if args.decision == "published" and previous and previous[0] != "published":
                    db.execute("UPDATE post_mentions SET expires=? WHERE post_id=?", (time.time()+86400, args.id))
                elif args.decision == "rejected":
                    db.execute("UPDATE post_mentions SET expires=0 WHERE post_id=?", (args.id,))
            db.execute("INSERT INTO audit(action,object_id,created) VALUES(?,?,?)", ("review:"+args.decision, args.id, time.time()))
        elif args.command in {"group", "role"}:
            user = db.execute("SELECT id FROM users WHERE email=?", (args.email.lower(),)).fetchone()
            if not user: raise SystemExit("Verified account not found")
            if args.command == "role":
                db.execute("UPDATE users SET role=? WHERE id=?", (args.role, user[0]))
            elif args.action == "add":
                db.execute("INSERT OR IGNORE INTO memberships VALUES(?,?)", (user[0], args.group_id))
            else:
                db.execute("DELETE FROM memberships WHERE user_id=? AND group_id=?", (user[0], args.group_id))
            db.execute("INSERT INTO audit(action,object_id,created) VALUES(?,?,?)", (args.command, user[0], time.time()))
        elif args.command == "pin":
            if not 0 <= args.hours <= 168: raise SystemExit("Use 0–168 hours")
            cursor = db.execute("UPDATE posts SET pin_until=? WHERE id=? AND status='published'", (time.time()+args.hours*3600, args.post_id))
            if cursor.rowcount != 1: raise SystemExit("Published post not found")
            db.execute("INSERT INTO audit(action,object_id,created) VALUES(?,?,?)", ("pin", args.post_id, time.time()))
        elif args.command == "resolve-report":
            cursor = db.execute("UPDATE reports SET resolved=1 WHERE id=?", (args.id,))
            if cursor.rowcount != 1: raise SystemExit("Report not found")
            if db.execute("SELECT 1 FROM sqlite_master WHERE name='moderation_reports'").fetchone():
                db.execute("UPDATE moderation_reports SET resolved=1,decision='resolved',resolved_at=? WHERE id=?", (time.time(),args.id))
            db.execute("INSERT INTO audit(action,object_id,created) VALUES(?,?,?)", ("resolve-report", args.id, time.time()))

if __name__ == "__main__": main()
