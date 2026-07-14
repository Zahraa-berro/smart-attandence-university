# ── Drop this into your attendance/mark-absent endpoint ──────────────────────
# After you save the absence record, call this block:

from app.api.v1.routes.notifications import create_notification

async def maybe_warn_absence(db, student_id: str, course_id: str, course_name: str, absence_count: int, max_allowed: int):
    """
    Fire an absence-warning notification when a student hits 75% or 100% of the limit.
    Call after every absence is recorded.
    """
    warn_at_75  = max_allowed * 0.75
    at_limit    = absence_count >= max_allowed
    at_75       = absence_count >= warn_at_75 and absence_count < max_allowed

    if at_limit:
        await create_notification(
            db,
            student_id=student_id,
            notif_type="absence_warning",
            title=f"Absence limit reached — {course_name}",
            message=(
                f"You have reached {absence_count}/{max_allowed} absences in {course_name}. "
                "Contact your advisor — exceeding the limit may result in course withdrawal."
            ),
            metadata={"courseId": course_id, "absenceCount": absence_count, "maxAllowed": max_allowed},
        )
    elif at_75:
        remaining = max_allowed - absence_count
        await create_notification(
            db,
            student_id=student_id,
            notif_type="absence_warning",
            title=f"Attendance warning — {course_name}",
            message=(
                f"You have {absence_count}/{max_allowed} absences in {course_name}. "
                f"Only {remaining} absence{'s' if remaining != 1 else ''} remaining before the limit."
            ),
            metadata={"courseId": course_id, "absenceCount": absence_count, "maxAllowed": max_allowed},
        )

# ── Usage example inside your attendance router ───────────────────────────────
#
# after_absence_count = await db["attendances"].count_documents(
#     {"studentId": student_id, "courseId": course_id, "status": "absent"}
# )
# await maybe_warn_absence(db, student_id, course_id, course_name, after_absence_count, max_allowed=10)