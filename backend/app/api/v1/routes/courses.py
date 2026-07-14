from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from app.db.mongodb import get_database


router = APIRouter(prefix="/courses")

COURSES_COLLECTION = "courses"
COURSE_CLASSES_COLLECTION = "course_classes"
ENROLLMENTS_COLLECTION = "enrollments"
ATTENDANCE_SESSIONS_COLLECTION = "attendance_sessions"
ATTENDANCE_RECORDS_COLLECTION = "attendance_records"
GRADE_COMPONENTS_COLLECTION = "grade_components"

SAMPLE_COURSES = [
    {
        "courseId": "COURSE-MAD-2026",
        "courseName": "Mobile Application Development",
        "courseCode": "CS 412",
        "doctorId": "doctor-sample",
        "department": "Software Engineering",
        "semester": "Spring 2026",
        "startDate": datetime(2026, 1, 2, tzinfo=timezone.utc),
        "endDate": datetime(2026, 5, 28, tzinfo=timezone.utc),
        "attendancePercent": 92,
        "studentsCount": 35,
        "schedule": [
            {
                "day": "Tue",
                "room": "C1.3",
                "startTime": "08:30",
                "endTime": "11:15",
            }
        ],
    },
    {
        "courseId": "COURSE-NET-2026",
        "courseName": "Computer Networks",
        "courseCode": "CS 330",
        "doctorId": "doctor-sample",
        "department": "Software Engineering",
        "semester": "Spring 2026",
        "startDate": datetime(2026, 1, 5, tzinfo=timezone.utc),
        "endDate": datetime(2026, 5, 25, tzinfo=timezone.utc),
        "attendancePercent": 85,
        "studentsCount": 40,
        "schedule": [
            {
                "day": "Mon",
                "room": "C2.1",
                "startTime": "10:00",
                "endTime": "12:00",
            }
        ],
    },
    {
        "courseId": "COURSE-DB-2026",
        "courseName": "Database Systems",
        "courseCode": "CS 305",
        "doctorId": "doctor-sample",
        "department": "Software Engineering",
        "semester": "Spring 2026",
        "startDate": datetime(2026, 1, 4, tzinfo=timezone.utc),
        "endDate": datetime(2026, 5, 24, tzinfo=timezone.utc),
        "attendancePercent": 78,
        "studentsCount": 30,
        "schedule": [
            {
                "day": "Sun",
                "room": "C3.2",
                "startTime": "09:00",
                "endTime": "11:00",
            }
        ],
    },
]


class CourseClassCreate(BaseModel):
    day: str
    room: str
    startTime: str
    endTime: str


class CourseCreate(BaseModel):
    courseId: str | None = None
    courseName: str = Field(min_length=1)
    courseCode: str | None = None
    doctorId: str | None = None
    department: str = "Software Engineering"
    semester: str = "Spring 2026"
    startDate: datetime | None = None
    endDate: datetime | None = None
    attendancePercent: int = 0
    studentsCount: int = 0
    schedule: list[CourseClassCreate] = Field(default_factory=list)


class CourseUpdate(BaseModel):
    courseName: str | None = None
    studentsCount: int | None = None
    startDate: datetime | None = None
    endDate: datetime | None = None
    attendancePercent: int | None = None


async def count_active_enrollments_for_course(db, course_id: str) -> int:
    """Count active enrollments for a course."""
    count = await db[ENROLLMENTS_COLLECTION].count_documents({
        "courseId": course_id,
        "studentId": {"$exists": True},
        "$or": [
            {"status": {"$exists": False}},
            {"status": "active"},
        ],
    })
    return count


def serialize_course(course: dict) -> dict:
    course["_id"] = str(course["_id"])
    return course


async def serialize_course_with_capacity(db, course: dict) -> dict:
    """Serialize course and compute studentsCount and attendancePercent from active enrollments."""
    serialized = serialize_course(course)
    active_count = await count_active_enrollments_for_course(db, course["courseId"])
    serialized["studentsCount"] = active_count

    session_cursor = db[ATTENDANCE_SESSIONS_COLLECTION].find({"courseId": course["courseId"], "status": "completed"})
    sessions = await session_cursor.to_list(length=500)
    session_ids = [session["sessionId"] for session in sessions]

    if sessions and active_count > 0:
        records_cursor = db[ATTENDANCE_RECORDS_COLLECTION].find({
            "courseId": course["courseId"],
            "sessionId": {"$in": session_ids},
        })
        records = await records_cursor.to_list(length=5000)
        total_present = sum(1 for record in records if record.get("present"))
        total_possible = len(sessions) * active_count
        attendance_percent = round(total_present * 100 / total_possible) if total_possible > 0 else 0
    else:
        attendance_percent = 0

    serialized["attendancePercent"] = int(attendance_percent)

    return serialized


def make_course_id(course_name: str) -> str:
    slug = "".join(
        char.upper() if char.isalnum() else "-"
        for char in course_name.strip()
    )
    slug = "-".join(part for part in slug.split("-") if part)
    timestamp = int(datetime.now(timezone.utc).timestamp())
    return f"COURSE-{slug[:24]}-{timestamp}"


def course_document(sample: dict) -> dict:
    now = datetime.now(timezone.utc)
    schedule = sample["schedule"]

    return {
        **sample,
        "classesCount": len(schedule),
        "createdAt": now,
    }


def class_document(course_id: str, item: dict) -> dict:
    class_id = item.get("classId") or (
        f"{course_id}-{item['day']}-{item['room']}-"
        f"{int(datetime.now(timezone.utc).timestamp())}"
    )
    return {
        "classId": class_id,
        "courseId": course_id,
        "day": item["day"],
        "room": item["room"],
        "startTime": item["startTime"],
        "endTime": item["endTime"],
        "createdAt": datetime.now(timezone.utc),
    }


@router.post("/seed-sample")
async def seed_sample_courses():
    db = get_database()

    for sample in SAMPLE_COURSES:
        course_id = sample["courseId"]
        document = course_document(sample)

        await db[COURSES_COLLECTION].update_one(
            {"courseId": course_id},
            {"$set": document},
            upsert=True,
        )

        await db[COURSE_CLASSES_COLLECTION].delete_many({"courseId": course_id})
        if sample["schedule"]:
            await db[COURSE_CLASSES_COLLECTION].insert_many(
                [
                    class_document(course_id, class_item)
                    for class_item in sample["schedule"]
                ]
            )

        await db[ENROLLMENTS_COLLECTION].update_one(
            {"courseId": course_id, "doctorId": sample["doctorId"]},
            {
                "$set": {
                    "courseId": course_id,
                    "doctorId": sample["doctorId"],
                    "studentsCount": sample["studentsCount"],
                    "createdAt": datetime.now(timezone.utc),
                }
            },
            upsert=True,
        )

    return {
        "status": "ok",
        "seeded": len(SAMPLE_COURSES),
    }


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_course(
    payload: CourseCreate,
    x_user_id: str | None = Header(default=None, alias="X-User-Id"),
):
    db = get_database()
    course_id = payload.courseId or make_course_id(payload.courseName)

    duplicate_filter = [{"courseId": course_id}]
    if payload.courseCode:
        duplicate_filter.append({"courseCode": payload.courseCode})

    duplicate = await db[COURSES_COLLECTION].find_one({"$or": duplicate_filter})
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Course ID or course code already exists",
        )

    now = datetime.now(timezone.utc)
    schedule = [item.model_dump() for item in payload.schedule]
    doctor_id = x_user_id or payload.doctorId
    if not doctor_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Doctor ID is required to create a course",
        )
    course = {
        "courseId": course_id,
        "courseName": payload.courseName.strip(),
        "courseCode": payload.courseCode or course_id,
        "doctorId": doctor_id,
        "department": payload.department,
        "semester": payload.semester,
        "startDate": payload.startDate,
        "endDate": payload.endDate,
        "attendancePercent": payload.attendancePercent,
        "classesCount": len(schedule),
        "schedule": schedule,
        "createdAt": now,
    }

    result = await db[COURSES_COLLECTION].insert_one(course)

    if schedule:
        await db[COURSE_CLASSES_COLLECTION].insert_many(
            [class_document(course_id, item) for item in schedule]
        )

    created = await db[COURSES_COLLECTION].find_one({"_id": result.inserted_id})
    return await serialize_course_with_capacity(db, created)


@router.get("")
async def get_courses(
    x_user_id: str | None = Header(default=None, alias="X-User-Id"),
):
    db = get_database()
    query = {"doctorId": x_user_id} if x_user_id else {}
    cursor = db[COURSES_COLLECTION].find(query).sort("courseName", 1)
    courses = await cursor.to_list(length=100)
    return [await serialize_course_with_capacity(db, course) for course in courses]


@router.get("/{course_id}")
async def get_course(course_id: str):
    db = get_database()
    course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    return await serialize_course_with_capacity(db, course)


@router.get("/{course_id}/classes")
async def get_course_classes(course_id: str):
    db = get_database()
    cursor = (
        db[COURSE_CLASSES_COLLECTION]
        .find({"courseId": course_id})
        .sort("day", 1)
    )
    classes = await cursor.to_list(length=100)
    return [
        {
            **class_item,
            "_id": str(class_item["_id"]),
        }
        for class_item in classes
    ]


@router.patch("/{course_id}")
async def update_course(course_id: str, payload: CourseUpdate):
    db = get_database()
    updates = {
        key: value
        for key, value in payload.model_dump(exclude_unset=True).items()
        if value is not None and key != "studentsCount"  # Ignore studentsCount from frontend
    }

    if "courseName" in updates:
        updates["courseName"] = updates["courseName"].strip()

    if not updates:
        course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
        if course is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Course not found",
            )
        return await serialize_course_with_capacity(db, course)

    result = await db[COURSES_COLLECTION].update_one(
        {"courseId": course_id},
        {"$set": updates},
    )
    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
    return await serialize_course_with_capacity(db, course)


@router.delete("/{course_id}")
async def delete_course(course_id: str):
    db = get_database()
    result = await db[COURSES_COLLECTION].delete_one({"courseId": course_id})
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    await db[COURSE_CLASSES_COLLECTION].delete_many({"courseId": course_id})
    await db[ENROLLMENTS_COLLECTION].delete_many({"courseId": course_id})
    await db[ATTENDANCE_SESSIONS_COLLECTION].delete_many({"courseId": course_id})
    await db[ATTENDANCE_RECORDS_COLLECTION].delete_many({"courseId": course_id})

    return {"status": "ok", "deleted": course_id}


@router.post("/{course_id}/classes", status_code=status.HTTP_201_CREATED)
async def add_course_class(course_id: str, payload: CourseClassCreate):
    db = get_database()
    course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    # Fetch ALL classes on the same day AND same room
    existing = await db[COURSE_CLASSES_COLLECTION].find(
        {"day": payload.day, "room": payload.room}
    ).to_list(length=500)

    def to_minutes(t: str) -> int:
        h, m = map(int, t.split(":"))
        return h * 60 + m

    new_start = to_minutes(payload.startTime)
    new_end   = to_minutes(payload.endTime)

    # Check conflict only for same room
    for cls in existing:
        ex_start = to_minutes(cls["startTime"])
        ex_end   = to_minutes(cls["endTime"])
        if new_start < ex_end and ex_start < new_end:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    f"Time conflict on {payload.day} in room '{payload.room}': "
                    f"already scheduled {cls['startTime']}–{cls['endTime']}."
                ),
            )

    class_item = class_document(course_id, payload.model_dump())
    result = await db[COURSE_CLASSES_COLLECTION].insert_one(class_item)
    class_item["_id"] = result.inserted_id

    schedule_item = {
        "classId": class_item["classId"],
        "day": class_item["day"],
        "room": class_item["room"],
        "startTime": class_item["startTime"],
        "endTime": class_item["endTime"],
    }
    await db[COURSES_COLLECTION].update_one(
        {"courseId": course_id},
        {
            "$push": {"schedule": schedule_item},
            "$inc": {"classesCount": 1},
        },
    )

    return {**class_item, "_id": str(class_item["_id"])}


@router.delete("/{course_id}/classes/{class_id}")
async def delete_course_class(course_id: str, class_id: str):
    db = get_database()
    result = await db[COURSE_CLASSES_COLLECTION].delete_one(
        {"courseId": course_id, "classId": class_id}
    )
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found",
        )

    await db[COURSES_COLLECTION].update_one(
        {"courseId": course_id},
        {
            "$pull": {"schedule": {"classId": class_id}},
            "$inc": {"classesCount": -1},
        },
    )

    return {"status": "ok", "deleted": class_id}


@router.get("/{course_id}/sessions")
async def get_course_sessions(course_id: str):
    db = get_database()

    existing = await db[ATTENDANCE_SESSIONS_COLLECTION]\
        .find({"courseId": course_id}).sort("date", 1).to_list(length=200)

    if not existing:
        course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
        if course:
            start: datetime = course["startDate"]
            end: datetime = course["endDate"]

            if start.tzinfo is None or start.tzinfo.utcoffset(start) is None:
                start = start.replace(tzinfo=timezone.utc)
            else:
                start = start.astimezone(timezone.utc)

            if end.tzinfo is None or end.tzinfo.utcoffset(end) is None:
                end = end.replace(tzinfo=timezone.utc)
            else:
                end = end.astimezone(timezone.utc)

            schedule = course.get("schedule", [])
            day_map = {"Mon": 0, "Tue": 1, "Wed": 2, "Thu": 3,
                       "Fri": 4, "Sat": 5, "Sun": 6}

            sessions = []
            for slot in schedule:
                target_weekday = day_map.get(slot["day"])
                if target_weekday is None:
                    continue
                delta = (target_weekday - start.weekday()) % 7
                current = start + timedelta(days=delta)
                while current <= end:
                    sessions.append({
                        "sessionId": f"{course_id}-{current.strftime('%Y%m%d')}",
                        "courseId": course_id,
                        "classId": slot.get("classId", ""),
                        "date": datetime(current.year, current.month, current.day, tzinfo=timezone.utc),
                        "day": slot["day"],
                        "room": slot["room"],
                        "startTime": slot["startTime"],
                        "endTime": slot["endTime"],
                       "status": "pending"
                       if current.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc)
                       else "completed",
                        "createdAt": datetime.now(timezone.utc),
                    })
                    current += timedelta(weeks=1)

            if sessions:
                await db[ATTENDANCE_SESSIONS_COLLECTION].insert_many(sessions)
                existing = sessions

    for s in existing:
        s["_id"] = str(s["_id"])
    return existing