from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status, Header
from pydantic import BaseModel, Field

from app.db.mongodb import get_database
from app.api.v1.routes.courses import COURSES_COLLECTION, COURSE_CLASSES_COLLECTION
from app.api.v1.routes.notifications import notify_class_students   # ← new import

router = APIRouter(prefix="/announcements")

ANNOUNCEMENTS_COLLECTION = "announcements"


class AnnouncementCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    message: str | None = None


class AnnouncementUpdate(BaseModel):
    title: str | None = None
    message: str | None = None


def serialize_document(document: dict) -> dict:
    document["_id"] = str(document["_id"])
    return document


@router.post("/course/{course_id}/class/{class_id}", status_code=status.HTTP_201_CREATED)
async def create_announcement(
    course_id: str,
    class_id: str,
    payload: AnnouncementCreate,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
    x_user_name: str | None = Header(None, alias="X-User-Name"),   # doctor display name
):
    db = get_database()

    course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    class_doc = await db[COURSE_CLASSES_COLLECTION].find_one(
        {"courseId": course_id, "classId": class_id}
    )
    if class_doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found for this course")

    if not x_user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing user identity")

    announcement = {
        "announcementId": f"ANN-{course_id}-{class_id}-{int(datetime.now(timezone.utc).timestamp())}",
        "courseId":            course_id,
        "classId":             class_id,
        "title":               payload.title,
        "message":             payload.message,
        "createdByDoctorId":   x_user_id,
        "createdAt":           datetime.now(timezone.utc),
        "updatedAt":           datetime.now(timezone.utc),
    }

    result = await db[ANNOUNCEMENTS_COLLECTION].insert_one(announcement)
    announcement["_id"] = str(result.inserted_id)

    # ── Notify all enrolled students ──────────────────────────────────────────
    course_name  = course.get("courseName") or course.get("name") or course_id
    class_name   = class_doc.get("className") or class_doc.get("name") or class_id
    doctor_label = x_user_name or "Your doctor"

    notif_title   = f"New announcement in {course_name}"
    notif_message = (
        f"{doctor_label} posted: \"{payload.title}\""
        + (f" — {payload.message[:80]}{'…' if payload.message and len(payload.message) > 80 else ''}"
           if payload.message else "")
    )

    await notify_class_students(
        db,
        course_id=course_id,
        class_id=class_id,
        notif_type="announcement",
        title=notif_title,
        message=notif_message,
        metadata={
            "announcementId": announcement["announcementId"],
            "courseId":       course_id,
            "classId":        class_id,
            "courseName":     course_name,
            "className":      class_name,
        },
    )

    return serialize_document(announcement)


@router.get("/course/{course_id}/class/{class_id}")
async def get_class_announcements(course_id: str, class_id: str):
    db = get_database()
    cursor = (
        db[ANNOUNCEMENTS_COLLECTION]
        .find({"courseId": course_id, "classId": class_id})
        .sort("createdAt", -1)
    )
    announcements = await cursor.to_list(length=500)
    return [serialize_document(a) for a in announcements]


@router.patch("/{announcement_id}")
async def update_announcement(announcement_id: str, payload: AnnouncementUpdate):
    db = get_database()
    updates = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        announcement = await db[ANNOUNCEMENTS_COLLECTION].find_one(
            {"announcementId": announcement_id}
        )
        if announcement is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found")
        return serialize_document(announcement)

    updates["updatedAt"] = datetime.now(timezone.utc)
    result = await db[ANNOUNCEMENTS_COLLECTION].update_one(
        {"announcementId": announcement_id}, {"$set": updates}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found")
    updated = await db[ANNOUNCEMENTS_COLLECTION].find_one({"announcementId": announcement_id})
    return serialize_document(updated)


@router.delete("/{announcement_id}")
async def delete_announcement(announcement_id: str):
    db = get_database()
    result = await db[ANNOUNCEMENTS_COLLECTION].delete_one(
        {"announcementId": announcement_id}
    )
    if result.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found")
    return {"status": "ok", "deleted": announcement_id}