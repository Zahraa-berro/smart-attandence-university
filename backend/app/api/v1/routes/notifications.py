from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from app.db.mongodb import get_database

import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase Admin SDK once
if not firebase_admin._apps:
    cred = credentials.Certificate("smart-classroom-e0584-firebase-adminsdk-fbsvc-a5fe817b2b.json")
    firebase_admin.initialize_app(cred)

router = APIRouter(prefix="/notifications")

NOTIFICATIONS_COLLECTION = "notifications"
ENROLLMENTS_COLLECTION   = "enrollments"


def serialize_document(doc: dict) -> dict:
    doc["_id"] = str(doc["_id"])
    if isinstance(doc.get("createdAt"), datetime):
        doc["createdAt"] = doc["createdAt"].replace(tzinfo=timezone.utc).isoformat()
    return doc


# ── Push notification ─────────────────────────────────────────────────────────

async def send_push_notification(db, student_id: str, title: str, message: str):
    """Send FCM push notification to the student's device."""
    user = await db["users"].find_one({"userId": student_id})
    if not user:
        return

    fcm_token = user.get("fcmToken")
    if not fcm_token:
        return

    try:
        msg = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=message,
            ),
            android=messaging.AndroidConfig(
                priority="high",
            ),
            token=fcm_token,
        )
        messaging.send(msg)
    except Exception as e:
        print(f"FCM error: {e}")


# ── Helper called from other routers ─────────────────────────────────────────

async def create_notification(
    db,
    student_id: str,
    notif_type: str,
    title: str,
    message: str,
    metadata: dict | None = None,
):
    ts = int(datetime.now(timezone.utc).timestamp() * 1000)
    doc = {
        "notificationId": f"NOTIF-{student_id}-{ts}",
        "studentId":      student_id,
        "type":           notif_type,
        "title":          title,
        "message":        message,
        "isRead":         False,
        "metadata":       metadata or {},
        "createdAt":      datetime.now(timezone.utc),
    }
    await db[NOTIFICATIONS_COLLECTION].insert_one(doc)

    # ── Send push to device ───────────────────────────────────────────────
    await send_push_notification(db, student_id, title, message)

    return doc


async def notify_class_students(
    db,
    course_id: str,
    class_id: str,
    notif_type: str,
    title: str,
    message: str,
    metadata: dict | None = None,
):
    cursor = db[ENROLLMENTS_COLLECTION].find(
        {"courseId": course_id, "classId": class_id, "status": "active"}
    )
    enrollments = await cursor.to_list(length=500)
    for enrollment in enrollments:
        student_number = enrollment.get("studentId") or enrollment.get("userId")
        if not student_number:
            continue

        user = await db["users"].find_one({"studentId": student_number})
        if user:
            uid = user.get("userId") or str(user["_id"])
        else:
            uid = student_number

        await create_notification(db, uid, notif_type, title, message, metadata)


# ── REST endpoints ────────────────────────────────────────────────────────────

@router.get("/student/{student_id}")
async def get_student_notifications(student_id: str, limit: int = 50):
    db = get_database()
    cursor = (
        db[NOTIFICATIONS_COLLECTION]
        .find({"studentId": student_id})
        .sort("createdAt", -1)
        .limit(limit)
    )
    items = await cursor.to_list(length=limit)
    return [serialize_document(n) for n in items]


@router.get("/student/{student_id}/unread-count")
async def get_unread_count(student_id: str):
    db = get_database()
    count = await db[NOTIFICATIONS_COLLECTION].count_documents(
        {"studentId": student_id, "isRead": False}
    )
    return {"unreadCount": count}


@router.patch("/{notification_id}/read")
async def mark_as_read(notification_id: str):
    db = get_database()
    result = await db[NOTIFICATIONS_COLLECTION].update_one(
        {"notificationId": notification_id},
        {"$set": {"isRead": True}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    updated = await db[NOTIFICATIONS_COLLECTION].find_one({"notificationId": notification_id})
    return serialize_document(updated)


@router.patch("/student/{student_id}/read-all")
async def mark_all_read(student_id: str):
    db = get_database()
    await db[NOTIFICATIONS_COLLECTION].update_many(
        {"studentId": student_id, "isRead": False},
        {"$set": {"isRead": True}},
    )
    return {"status": "ok"}