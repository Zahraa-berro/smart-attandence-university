from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.db.mongodb import get_database
from app.api.v1.routes.notifications import create_notification


router = APIRouter()

STUDENTS_COLLECTION = "students"
ENROLLMENTS_COLLECTION = "enrollments"
COURSES_COLLECTION = "courses"
ATTENDANCE_SESSIONS_COLLECTION = "attendance_sessions"
ATTENDANCE_RECORDS_COLLECTION = "attendance_records"
COURSE_CLASSES_COLLECTION = "course_classes"

MAX_ABSENCES = 10


class EnrollmentRequest(BaseModel):
    studentId: str | None = None
    email: str | None = None
    classId: str | None = None


class AttendanceUpdate(BaseModel):
    present: bool


class AddStudentToSessionRequest(BaseModel):
    studentId: str


SAMPLE_STUDENTS = [
    {
        "studentId": "20220145",
        "name": "Ali Hassan",
        "email": "ali.hassan@student.smart.edu",
        "image": "assets/students/ali.jpg",
    },
    {
        "studentId": "20220188",
        "name": "Sara Ali",
        "email": "sara.ali@student.smart.edu",
        "image": "assets/students/sara.jpg",
    },
    {
        "studentId": "20220210",
        "name": "Omar Khaled",
        "email": "omar.khaled@student.smart.edu",
        "image": "assets/students/omar.jpg",
    },
    {
        "studentId": "20220234",
        "name": "Nour Tarek",
        "email": "nour.tarek@student.smart.edu",
        "image": "assets/students/nour.jpg",
    },
    {
        "studentId": "20220267",
        "name": "Youssef Adel",
        "email": "youssef.adel@student.smart.edu",
        "image": "assets/students/youssef.jpg",
    },
    {
        "studentId": "20220301",
        "name": "Lara Mansour",
        "email": "lara.mansour@student.smart.edu",
        "image": "assets/students/default.jpg",
    },
]

SAMPLE_COURSE_STUDENTS = {
    "COURSE-MAD-2026": ["20220145", "20220188", "20220210", "20220234", "20220267"],
    "COURSE-NET-2026": ["20220145", "20220188", "20220210", "20220301"],
}

SAMPLE_SESSIONS = {
    "COURSE-MAD-2026": [
        ("SESSION-MAD-2026-01", datetime(2026, 1, 6, tzinfo=timezone.utc), "Tue", "C1.3", "08:30", "11:15"),
        ("SESSION-MAD-2026-02", datetime(2026, 1, 13, tzinfo=timezone.utc), "Tue", "C1.3", "08:30", "11:15"),
        ("SESSION-MAD-2026-03", datetime(2026, 1, 20, tzinfo=timezone.utc), "Tue", "C1.3", "08:30", "11:15"),
    ],
    "COURSE-NET-2026": [
        ("SESSION-NET-2026-01", datetime(2026, 1, 5, tzinfo=timezone.utc), "Mon", "C2.1", "10:00", "12:00"),
        ("SESSION-NET-2026-02", datetime(2026, 1, 12, tzinfo=timezone.utc), "Mon", "C2.1", "10:00", "12:00"),
        ("SESSION-NET-2026-03", datetime(2026, 1, 19, tzinfo=timezone.utc), "Mon", "C2.1", "10:00", "12:00"),
    ],
}


def serialize_document(document: dict) -> dict:
    # Convert ObjectId to string and serialize datetimes to ISO strings (UTC)
    document["_id"] = str(document["_id"])
    for k, v in list(document.items()):
        try:
            from datetime import datetime
        except Exception:
            datetime = None
        if v is None:
            continue
        if isinstance(v, datetime):
            try:
                iso = v.astimezone(timezone.utc).isoformat()
            except Exception:
                iso = v.isoformat()
            if iso.endswith('+00:00'):
                iso = iso.replace('+00:00', 'Z')
            document[k] = iso
    return document


def session_document(
    course_id: str,
    session_id: str,
    date: datetime,
    day: str,
    room: str,
    start_time: str,
    end_time: str,
    class_id: str = "",
) -> dict:
    return {
        "sessionId": session_id,
        "courseId": course_id,
        "classId": class_id,
        "date": date,
        "day": day,
        "room": room,
        "startTime": start_time,
        "endTime": end_time,
        "status": "completed",
        "createdAt": datetime.now(timezone.utc),
    }


def record_document(
    session_id: str,
    course_id: str,
    student_id: str,
    present: bool,
    detected_by: str = "Manual",
) -> dict:
    return {
        "recordId": f"{session_id}-{student_id}",
        "sessionId": session_id,
        "courseId": course_id,
        "studentId": student_id,
        "present": present,
        "detectedBy": detected_by if present else None,
        "markedAt": datetime.now(timezone.utc),
    }


async def count_active_enrollments(db, course_id: str) -> int:
    """Count active enrollments for a course (default capacity limit is 34)."""
    count = await db[ENROLLMENTS_COLLECTION].count_documents({
        "courseId": course_id,
        "studentId": {"$exists": True},
        "$or": [
            {"status": {"$exists": False}},
            {"status": "active"},
        ],
    })
    return count


async def get_enrolled_students(db, course_id: str, class_id: str | None = None) -> list[dict]:
    if class_id:
        enrollment_cursor = db[ENROLLMENTS_COLLECTION].find(
            {"courseId": course_id, "classId": class_id, "studentId": {"$exists": True}}
        )
    else:
        enrollment_cursor = db[ENROLLMENTS_COLLECTION].find(
            {"courseId": course_id, "studentId": {"$exists": True}}
        )
    enrollments = await enrollment_cursor.to_list(length=500)
    student_ids = list({item["studentId"] for item in enrollments})

    if not student_ids:
        return []

    student_cursor = db[STUDENTS_COLLECTION].find(
        {"studentId": {"$in": student_ids}}
    ).sort("name", 1)
    students = await student_cursor.to_list(length=500)
    return [serialize_document(student) for student in students]


async def maybe_warn_absence(
    db,
    student_id: str,
    course_id: str,
    course_name: str,
    absence_count: int,
    max_allowed: int,
) -> None:
    """
    Fire an absence-warning notification when a student hits 75% or 100% of
    the allowed absence limit. Call this after every absence is recorded.
    """
    warn_at_75 = max_allowed * 0.75
    at_limit = absence_count >= max_allowed
    at_75 = warn_at_75 <= absence_count < max_allowed

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
            metadata={
                "courseId": course_id,
                "absenceCount": absence_count,
                "maxAllowed": max_allowed,
            },
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
            metadata={
                "courseId": course_id,
                "absenceCount": absence_count,
                "maxAllowed": max_allowed,
            },
        )


@router.post("/attendance/seed-sample")
async def seed_sample_attendance():
    db = get_database()
    now = datetime.now(timezone.utc)

    for student in SAMPLE_STUDENTS:
        await db[STUDENTS_COLLECTION].update_one(
            {"studentId": student["studentId"]},
            {"$set": {**student, "createdAt": now}},
            upsert=True,
        )

    course_ids = list(SAMPLE_COURSE_STUDENTS.keys())
    await db[ENROLLMENTS_COLLECTION].delete_many(
        {"courseId": {"$in": course_ids}, "studentId": {"$exists": True}}
    )
    await db[ATTENDANCE_SESSIONS_COLLECTION].delete_many(
        {"courseId": {"$in": course_ids}}
    )
    await db[ATTENDANCE_RECORDS_COLLECTION].delete_many(
        {"courseId": {"$in": course_ids}}
    )

    enrollment_docs = []
    for course_id, student_ids in SAMPLE_COURSE_STUDENTS.items():
        for student_id in student_ids:
            enrollment_docs.append(
                {
                    "enrollmentId": f"{course_id}-{student_id}",
                    "courseId": course_id,
                    "studentId": student_id,
                    "status": "active",
                    "enrolledAt": now,
                }
            )

    if enrollment_docs:
        await db[ENROLLMENTS_COLLECTION].insert_many(enrollment_docs)

    session_docs = []
    record_docs = []
    for course_id, sessions in SAMPLE_SESSIONS.items():
        student_ids = SAMPLE_COURSE_STUDENTS[course_id]
        for session_index, session in enumerate(sessions):
            session_id, date, day, room, start_time, end_time = session
            session_docs.append(
                session_document(
                    course_id, session_id, date, day, room, start_time, end_time
                )
            )
            for student_index, student_id in enumerate(student_ids):
                present = (session_index + student_index) % 4 != 0
                record_docs.append(
                    record_document(session_id, course_id, student_id, present)
                )

    if session_docs:
        await db[ATTENDANCE_SESSIONS_COLLECTION].insert_many(session_docs)
    if record_docs:
        await db[ATTENDANCE_RECORDS_COLLECTION].insert_many(record_docs)

    return {
        "status": "ok",
        "students": len(SAMPLE_STUDENTS),
        "enrollments": len(enrollment_docs),
        "sessions": len(session_docs),
        "records": len(record_docs),
    }


@router.get("/courses/{course_id}/students")
async def get_course_students(course_id: str, class_id: str | None = None):
    db = get_database()
    return await get_enrolled_students(db, course_id, class_id)


@router.post("/courses/{course_id}/students")
async def enroll_course_student(course_id: str, payload: EnrollmentRequest):
    db = get_database()

    if not payload.studentId and not payload.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="studentId or email is required",
        )

    course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    query = {}
    if payload.studentId:
        query["studentId"] = payload.studentId.strip()
    if payload.email:
        query["email"] = payload.email.strip().lower()

    student = await db[STUDENTS_COLLECTION].find_one(query)
    if student is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )

    student_id = student["studentId"]
    enrollment_filter = {"courseId": course_id, "studentId": student_id}
    if payload.classId:
        enrollment_filter["classId"] = payload.classId

    # Prevent enrolling if attendance records for this student/course already exist
    existing_any_record = await db[ATTENDANCE_RECORDS_COLLECTION].find_one({
        "courseId": course_id,
        "studentId": student_id,
    })
    if existing_any_record is not None:
        return {"status": "already_exists", "studentId": student_id}

    existing = await db[ENROLLMENTS_COLLECTION].find_one(enrollment_filter)
    if existing is not None:
        return {"status": "already_enrolled", "studentId": student_id}

    active_count = await count_active_enrollments(db, course_id)
    if active_count >= 34:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Class capacity is full",
        )

    enrollment_doc = {
        "enrollmentId": f"{course_id}-{student_id}",
        "courseId": course_id,
        "studentId": student_id,
        "status": "active",
        "enrolledAt": datetime.now(timezone.utc),
    }
    if payload.classId:
        enrollment_doc["classId"] = payload.classId

    await db[ENROLLMENTS_COLLECTION].insert_one(enrollment_doc)

    session_filter = {"courseId": course_id}
    if payload.classId:
        session_filter["classId"] = payload.classId

    all_sessions = await db[ATTENDANCE_SESSIONS_COLLECTION].find(
        session_filter
    ).to_list(length=500)

    for session in all_sessions:
        existing = await db[ATTENDANCE_RECORDS_COLLECTION].find_one({
            "sessionId": session["sessionId"],
            "studentId": student_id,
        })
        if existing is None:
            await db[ATTENDANCE_RECORDS_COLLECTION].insert_one(
                record_document(
                    session_id=session["sessionId"],
                    course_id=course_id,
                    student_id=student_id,
                    present=False,
                )
            )
    return {"status": "enrolled", "studentId": student_id}


@router.get("/courses/{course_id}/sessions")
async def get_course_sessions(course_id: str, class_id: str | None = None):
    db = get_database()
    query = {"courseId": course_id}
    if class_id:
        query["classId"] = class_id
    cursor = (
        db[ATTENDANCE_SESSIONS_COLLECTION]
        .find(query)
        .sort("date", 1)
    )
    sessions = await cursor.to_list(length=200)
    return [serialize_document(session) for session in sessions]


@router.get("/attendance/sessions/{session_id}")
async def get_attendance_session(session_id: str):
    db = get_database()
    session = await db[ATTENDANCE_SESSIONS_COLLECTION].find_one(
        {"sessionId": session_id}
    )
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    enrolled_students = await get_enrolled_students(db, session["courseId"], session.get("classId"))
    enrolled_ids = {s["studentId"] for s in enrolled_students}

    records_cursor = db[ATTENDANCE_RECORDS_COLLECTION].find({"sessionId": session_id})
    records = await records_cursor.to_list(length=500)
    records_by_student = {r["studentId"]: r for r in records}

    extra_ids = [sid for sid in records_by_student if sid not in enrolled_ids]
    extra_students = []
    if extra_ids:
        cursor = db[STUDENTS_COLLECTION].find({"studentId": {"$in": extra_ids}})
        extra_students = await cursor.to_list(length=500)
        extra_students = [serialize_document(s) for s in extra_students]

    all_students = enrolled_students + extra_students

    return {
        "session": serialize_document(session),
        "records": [
            {
                "student": student,
                "record": serialize_document(records_by_student[student["studentId"]])
                if student["studentId"] in records_by_student
                else None,
            }
            for student in all_students
        ],
    }


@router.post("/attendance/sessions/{session_id}/students", status_code=201)
async def add_student_to_session(session_id: str, payload: AddStudentToSessionRequest):
    db = get_database()

    session = await db[ATTENDANCE_SESSIONS_COLLECTION].find_one({"sessionId": session_id})
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found")

    course_id = session["courseId"]

    student = await db[STUDENTS_COLLECTION].find_one({"studentId": payload.studentId})
    if student is None:
        raise HTTPException(status_code=404, detail="Student not found")

    enrollment_filter = {"courseId": course_id, "studentId": payload.studentId}
    if session.get("classId"):
        enrollment_filter["classId"] = session["classId"]

    # Check if student is already enrolled for this course/class
    existing_enrollment = await db[ENROLLMENTS_COLLECTION].find_one(enrollment_filter)

    # If the student already has any attendance records for this course, avoid duplicates
    existing_any_record = await db[ATTENDANCE_RECORDS_COLLECTION].find_one({
        "courseId": course_id,
        "studentId": payload.studentId,
    })
    if existing_any_record is not None:
        return {"status": "already_exists", "studentId": payload.studentId}

    # If already enrolled, and already has a record for this session, return early
    existing_session_record = await db[ATTENDANCE_RECORDS_COLLECTION].find_one({
        "sessionId": session_id,
        "studentId": payload.studentId,
    })
    if existing_session_record is not None:
        return {"status": "already_enrolled", "studentId": payload.studentId}

    # If not already enrolled, check capacity before creating enrollment
    if not existing_enrollment:
        active_count = await count_active_enrollments(db, course_id)
        if active_count >= 34:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Class capacity is full",
            )

    # Create enrollment if missing (setOnInsert prevents duplicates)
    await db[ENROLLMENTS_COLLECTION].update_one(
        enrollment_filter,
        {
            "$setOnInsert": {
                "enrollmentId": f"{course_id}-{payload.studentId}",
                "courseId": course_id,
                "studentId": payload.studentId,
                "status": "active",
                "enrolledAt": datetime.now(timezone.utc),
            }
        },
        upsert=True,
    )

    # Ensure the student has attendance records for other sessions (insert missing records)
    session_filter = {"courseId": course_id}
    if session.get("classId"):
        session_filter["classId"] = session["classId"]

    all_sessions_cursor = db[ATTENDANCE_SESSIONS_COLLECTION].find(
        {**session_filter, "sessionId": {"$ne": session_id}}
    )
    all_sessions = await all_sessions_cursor.to_list(length=200)
    for other_session in all_sessions:
        other_session_id = other_session["sessionId"]
        existing_record = await db[ATTENDANCE_RECORDS_COLLECTION].find_one({
            "sessionId": other_session_id,
            "studentId": payload.studentId,
        })
        if existing_record is None:
            await db[ATTENDANCE_RECORDS_COLLECTION].insert_one(
                record_document(
                    session_id=other_session_id,
                    course_id=course_id,
                    student_id=payload.studentId,
                    present=False,
                )
            )

    # Finally, create the record for the requested session (already checked above)
    doc = record_document(
        session_id=session_id,
        course_id=course_id,
        student_id=payload.studentId,
        present=False,
    )
    result = await db[ATTENDANCE_RECORDS_COLLECTION].insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    student["_id"] = str(student["_id"])

    return {"student": student, "record": doc}

@router.patch("/attendance/sessions/{session_id}/records/{student_id}")
async def update_attendance_record(
    session_id: str,
    student_id: str,
    payload: AttendanceUpdate,
):
    db = get_database()

    session = await db[ATTENDANCE_SESSIONS_COLLECTION].find_one(
        {"sessionId": session_id}
    )
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    course_id = session["courseId"]

    document = record_document(
        session_id=session_id,
        course_id=course_id,
        student_id=student_id,
        present=payload.present,
    )
    await db[ATTENDANCE_RECORDS_COLLECTION].update_one(
        {"sessionId": session_id, "studentId": student_id},
        {"$set": document},
        upsert=True,
    )

    # Fire absence warnings only when marking absent
    if not payload.present:
        course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
        # ✅ Fix 2: use courseName not name
        course_name = (course or {}).get("courseName") or (course or {}).get("name") or course_id

        absence_count = await db[ATTENDANCE_RECORDS_COLLECTION].count_documents(
            {"courseId": course_id, "studentId": student_id, "present": False}
        )

        # ✅ Fix 1: resolve userId from student number
        user = await db["users"].find_one({"studentId": student_id})
        uid = user.get("userId") or str(user["_id"]) if user else student_id

        await maybe_warn_absence(
            db,
            student_id=uid,   # ← use userId not student number
            course_id=course_id,
            course_name=course_name,
            absence_count=absence_count,
            max_allowed=MAX_ABSENCES,
        )

    saved = await db[ATTENDANCE_RECORDS_COLLECTION].find_one(
        {"sessionId": session_id, "studentId": student_id}
    )
    return serialize_document(saved)

@router.get("/courses/{course_id}/attendance/report")
async def get_course_attendance_report(course_id: str, class_id: str | None = None):
    db = get_database()
    students = await get_enrolled_students(db, course_id, class_id)

    session_filter = {"courseId": course_id, "status": "completed"}
    if class_id:
        session_filter["classId"] = class_id

    sessions_cursor = db[ATTENDANCE_SESSIONS_COLLECTION].find(session_filter)
    sessions = await sessions_cursor.to_list(length=500)
    session_ids = [session["sessionId"] for session in sessions]

    if session_ids:
        records_cursor = db[ATTENDANCE_RECORDS_COLLECTION].find(
            {"courseId": course_id, "sessionId": {"$in": session_ids}}
        )
        records = await records_cursor.to_list(length=5000)
    else:
        records = []

    records_by_student: dict[str, list[dict]] = {}
    for record in records:
        records_by_student.setdefault(record["studentId"], []).append(record)

    per_student = []
    total_present = 0
    total_absent = 0
    conducted_count = len(sessions)

    for student in students:
        student_records = records_by_student.get(student["studentId"], [])
        present = sum(1 for record in student_records if record.get("present"))
        absent = conducted_count - present
        total_present += present
        total_absent += absent
        per_student.append(
            {
                "studentId": student["studentId"],
                "name": student["name"],
                "present": present,
                "absent": absent,
            }
        )

    total_possible_attendance = conducted_count * len(students) if conducted_count > 0 and students else 0
    attendance_percentage = 0
    if total_possible_attendance > 0:
        attendance_percentage = round(100 * total_present / total_possible_attendance)

    return {
        "courseId": course_id,
        "totalSessions": conducted_count,
        "conductedCount": conducted_count,
        "totalStudents": len(students),
        "totalPresent": total_present,
        "totalAbsent": total_absent,
        "attendancePercentage": attendance_percentage,
        "students": per_student,
    }