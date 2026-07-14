from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel, Field

from app.api.v1.routes.auth import USERS_COLLECTION
from app.api.v1.routes.attendance import (
    STUDENTS_COLLECTION,
    ENROLLMENTS_COLLECTION,
    ATTENDANCE_RECORDS_COLLECTION,
)
from app.api.v1.routes.courses import COURSES_COLLECTION, COURSE_CLASSES_COLLECTION
from app.db.mongodb import get_database

router = APIRouter(prefix="/students")

SEAT_RESERVATIONS_COLLECTION = "seat_reservations"
ASSIGNMENTS_COLLECTION = "assignments"
GRADES_COLLECTION = "grades"
ANNOUNCEMENTS_COLLECTION = "announcements"


class SeatReservationRequest(BaseModel):
    courseId: str = Field(min_length=1)
    classId: str = Field(min_length=1)
    seatNumber: str = Field(min_length=1)


class SeatReservationUpdateRequest(BaseModel):
    seatNumber: str = Field(min_length=1)


async def get_current_student(x_user_id: str | None = Header(None, alias="X-User-Id")) -> dict:
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing user identity",
        )

    db = get_database()
    user = await db[USERS_COLLECTION].find_one({"userId": x_user_id})
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user identity",
        )

    student = await db[STUDENTS_COLLECTION].find_one({"userId": x_user_id})
    if student is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student profile not found for this user",
        )

    return {"user": user, "student": student}


def serialize_document(document: dict) -> dict:
    serialized = {**document}
    serialized["_id"] = str(document["_id"])
    return serialized


async def get_enrolled_course_ids(db, student_id: str) -> list[str]:
    """Get course IDs where student is enrolled (from enrollments, not attendance records)."""
    enrollments = await db[ENROLLMENTS_COLLECTION].find(
        {
            "studentId": student_id,
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        },
        {"courseId": 1}
    ).to_list(length=2000)
    
    course_ids = list({e["courseId"] for e in enrollments if e.get("courseId")})
    return course_ids


async def calculate_course_attendance(db, course_id: str, student_id: str) -> tuple[int, int]:
    records = await db[ATTENDANCE_RECORDS_COLLECTION].find(
        {"courseId": course_id, "studentId": student_id}
    ).to_list(length=1000)
    if not records:
        return 0, 0

    sessions: dict[str, dict] = {}
    for record in records:
        session_id = record.get("sessionId")
        if not session_id:
            continue
        sessions[session_id] = record

    total_sessions = len(sessions)
    if total_sessions == 0:
        return 0, 0

    present_count = sum(1 for record in sessions.values() if record.get("present") is True)
    absence_count = sum(1 for record in sessions.values() if record.get("present") is False)
    attendance_percentage = round((present_count / total_sessions) * 100)
    return attendance_percentage, absence_count


async def calculate_overall_attendance(db, student_id: str) -> dict:
    records = await db[ATTENDANCE_RECORDS_COLLECTION].find(
        {"studentId": student_id}
    ).to_list(length=2000)
    if not records:
        return {
            "attendancePercentage": 0,
            "absencesCount": 0,
        }

    sessions: dict[str, dict] = {}
    for record in records:
        session_id = record.get("sessionId")
        if not session_id:
            continue
        sessions[session_id] = record

    total_sessions = len(sessions)
    if total_sessions == 0:
        return {
            "attendancePercentage": 0,
            "absencesCount": 0,
        }

    present_count = sum(1 for record in sessions.values() if record.get("present") is True)
    absence_count = sum(1 for record in sessions.values() if record.get("present") is False)
    return {
        "attendancePercentage": round((present_count / total_sessions) * 100),
        "absencesCount": absence_count,
    }


async def verify_student_enrollment(db, course_id: str, student_id: str) -> bool:
    """Verify that the student is enrolled in the course."""
    enrollment = await db[ENROLLMENTS_COLLECTION].find_one(
        {
            "courseId": course_id,
            "studentId": student_id,
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        }
    )
    return enrollment is not None


# REPLACE load_student_courses with this:
async def load_student_courses(db, student_id: str) -> list[dict]:
    course_ids = await get_enrolled_course_ids(db, student_id)
    if not course_ids:
        return []

    cursor = db[COURSES_COLLECTION].find({"courseId": {"$in": course_ids}}).sort("courseName", 1)
    courses = await cursor.to_list(length=500)
    
    student_courses = []

    for course in courses:
        attendance_percentage, absences_count = await calculate_course_attendance(
            db, course["courseId"], student_id
        )

        class_docs = await db[COURSE_CLASSES_COLLECTION].find(
            {"courseId": course["courseId"]}
        ).to_list(length=200)

        schedule = [
            {
                "classId": class_item.get("classId"),
                "day": class_item.get("day"),
                "room": class_item.get("room"),
                "startTime": class_item.get("startTime"),
                "endTime": class_item.get("endTime"),
            }
            for class_item in class_docs
        ]

        first_class = schedule[0] if schedule else None
# ── Load grades ──────────────────────────────────────────────
        grade_doc = await db["grades"].find_one({
            "studentId": student_id,
            "courseId": course["courseId"],
        })

        midterm = grade_doc.get("midterm", 0) if grade_doc else 0
        final_exam = grade_doc.get("finalExam", 0) if grade_doc else 0
        project = grade_doc.get("project", 0) if grade_doc else 0
        performance_percentage = round(
            (midterm + final_exam + project) / 3
        ) if grade_doc else attendance_percentage

        student_courses.append(
            {
                "courseId": course["courseId"],
                "courseCode": course.get("courseCode"),
                "courseName": course.get("courseName"),
                "department": course.get("department"),
                "classId": first_class.get("classId") if first_class else None,
                "room": first_class.get("room") if first_class else None,
                "schedule": schedule,
                "attendancePercentage": attendance_percentage,
                "absencesCount": absences_count,
                "performancePercentage": performance_percentage,
                "midterm": midterm,
                "final": final_exam,
                "project": project,
            }

        )

    return student_courses

@router.get("/seats/class/{class_id}")
async def get_class_seats(class_id: str):
    db = get_database()
    cursor = db[SEAT_RESERVATIONS_COLLECTION].find(
        {
            "classId": class_id,
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        }
    )
    reservations = await cursor.to_list(length=500)
    return [serialize_document(r) for r in reservations]
@router.get("/me/dashboard")
async def get_student_dashboard(x_user_id: str | None = Header(None, alias="X-User-Id")):
    student_data = await get_current_student(x_user_id)
    db = get_database()

    enrolled_courses = await load_student_courses(db, student_data["student"]["studentId"])
    overall_attendance = await calculate_overall_attendance(db, student_data["student"]["studentId"])

    reserved_doc = await db[SEAT_RESERVATIONS_COLLECTION].find_one(
        {
            "userId": student_data["user"]["userId"],
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        },
        sort=[("updatedAt", -1)],
    )

    reserved_seat = None
    if reserved_doc is not None:
        reserved_seat = {
            "reservationId": reserved_doc["reservationId"],
            "courseId": reserved_doc["courseId"],
            "classId": reserved_doc["classId"],
            "seatNumber": reserved_doc["seatNumber"],
            "status": reserved_doc.get("status", "active"),
            "createdAt": reserved_doc.get("createdAt"),
            "updatedAt": reserved_doc.get("updatedAt"),
        }

    profile = {
        "userId": student_data["user"]["userId"],
        "studentId": student_data["student"]["studentId"],
        "name": student_data["student"].get("name") or student_data["user"].get("name"),
        "email": student_data["student"].get("email") or student_data["user"].get("email"),
        "role": student_data["user"].get("role"),
        "department": student_data["student"].get("department") or student_data["user"].get("department"),
    }

    return {
        "profile": profile,
        "enrolledCoursesCount": len(enrolled_courses),
        "attendancePercentage": overall_attendance["attendancePercentage"],
        "absencesCount": overall_attendance["absencesCount"],
        "reservedSeat": reserved_seat,
        "enrolledCourses": enrolled_courses,
    }


@router.get("/me/courses")
async def get_student_courses(x_user_id: str | None = Header(None, alias="X-User-Id")):
    student_data = await get_current_student(x_user_id)
    db = get_database()
    return await load_student_courses(db, student_data["student"]["studentId"])


@router.get("/me/courses/{course_id}")
async def get_student_course_details(
    course_id: str,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    """Get detailed course info with assignments, grades, announcements, and seat reservation for enrolled student."""
    student_data = await get_current_student(x_user_id)
    db = get_database()
    student_id = student_data["student"]["studentId"]
    
    # Verify student is enrolled in this course
    is_enrolled = await verify_student_enrollment(db, course_id, student_id)
    if not is_enrolled:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student is not enrolled in this course",
        )
    
    # Get course info
    course = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )
    
    # Get class schedules
    class_docs = await db[COURSE_CLASSES_COLLECTION].find(
        {"courseId": course_id}
    ).to_list(length=200)
    
    schedule = [
        {
            "classId": class_item.get("classId"),
            "day": class_item.get("day"),
            "room": class_item.get("room"),
            "startTime": class_item.get("startTime"),
            "endTime": class_item.get("endTime"),
        }
        for class_item in class_docs
    ]
    
    first_class = schedule[0] if schedule else None
    
    # Get attendance
    attendance_percentage, absences_count = await calculate_course_attendance(
        db, course_id, student_id
    )
    
    # Get grades for this student only
    grade_doc = await db[GRADES_COLLECTION].find_one({
        "studentId": student_id,
        "courseId": course_id,
    })
    
    midterm = grade_doc.get("midterm", 0) if grade_doc else 0
    final_exam = grade_doc.get("finalExam", 0) if grade_doc else 0
    project = grade_doc.get("project", 0) if grade_doc else 0
    performance_percentage = round(
        (midterm + final_exam + project) / 3
    ) if grade_doc else attendance_percentage
    
    # Get assignments for this course
    assignment_cursor = db[ASSIGNMENTS_COLLECTION].find(
        {"courseId": course_id}
    ).sort("dueDate", 1)
    assignments = await assignment_cursor.to_list(length=200)
    assignments_list = [serialize_document(a) for a in assignments]
    
    # Get announcements for this course
    announcement_cursor = db[ANNOUNCEMENTS_COLLECTION].find(
        {"courseId": course_id}
    ).sort("createdAt", -1)
    announcements = await announcement_cursor.to_list(length=200)
    announcements_list = [serialize_document(a) for a in announcements]
    
    # Get seat reservation for this student (if exists)
    seat_reservation = await db[SEAT_RESERVATIONS_COLLECTION].find_one({
        "userId": student_data["user"]["userId"],
        "courseId": course_id,
        "$or": [
            {"status": {"$exists": False}},
            {"status": {"$ne": "cancelled"}},
        ],
    })
    
    seat_info = None
    if seat_reservation is not None:
        seat_info = {
            "reservationId": seat_reservation["reservationId"],
            "classId": seat_reservation["classId"],
            "seatNumber": seat_reservation["seatNumber"],
            "status": seat_reservation.get("status", "active"),
            "createdAt": seat_reservation.get("createdAt"),
            "updatedAt": seat_reservation.get("updatedAt"),
        }
    
    return {
        "courseId": course["courseId"],
        "courseCode": course.get("courseCode"),
        "courseName": course.get("courseName"),
        "department": course.get("department"),
        "classId": first_class.get("classId") if first_class else None,
        "room": first_class.get("room") if first_class else None,
        "schedule": schedule,
        "attendancePercentage": attendance_percentage,
        "absencesCount": absences_count,
        "performancePercentage": performance_percentage,
        "midterm": midterm,
        "final": final_exam,
        "project": project,
        "assignments": assignments_list,
        "grades": {
            "midterm": midterm,
            "final": final_exam,
            "project": project,
            "total": performance_percentage,
        },
        "announcements": announcements_list,
        "seatReservation": seat_info,
    }


@router.get("/me/courses/{course_id}/assignments")
async def get_student_course_assignments(
    course_id: str,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    """Get assignments for an enrolled course."""
    student_data = await get_current_student(x_user_id)
    db = get_database()
    student_id = student_data["student"]["studentId"]
    
    # Verify student is enrolled in this course
    is_enrolled = await verify_student_enrollment(db, course_id, student_id)
    if not is_enrolled:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student is not enrolled in this course",
        )
    
    # Get assignments for this course
    cursor = db[ASSIGNMENTS_COLLECTION].find(
        {"courseId": course_id}
    ).sort("dueDate", 1)
    assignments = await cursor.to_list(length=200)
    return [serialize_document(a) for a in assignments]


@router.get("/me/courses/{course_id}/grades")
async def get_student_course_grades(
    course_id: str,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    """Get grades for current student in an enrolled course."""
    student_data = await get_current_student(x_user_id)
    db = get_database()
    student_id = student_data["student"]["studentId"]
    
    # Verify student is enrolled in this course
    is_enrolled = await verify_student_enrollment(db, course_id, student_id)
    if not is_enrolled:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student is not enrolled in this course",
        )
    
    # Get grades for this student only in this course
    grade_doc = await db[GRADES_COLLECTION].find_one({
        "studentId": student_id,
        "courseId": course_id,
    })
    
    if grade_doc is None:
        return {
            "studentId": student_id,
            "courseId": course_id,
            "midterm": 0,
            "final": 0,
            "project": 0,
            "total": 0,
        }
    
    midterm = grade_doc.get("midterm", 0)
    final_exam = grade_doc.get("finalExam", 0)
    project = grade_doc.get("project", 0)
    total = round((midterm + final_exam + project) / 3)
    
    return {
        "studentId": student_id,
        "courseId": course_id,
        "midterm": midterm,
        "final": final_exam,
        "project": project,
        "total": total,
    }


@router.get("/me/courses/{course_id}/announcements")
async def get_student_course_announcements(
    course_id: str,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    """Get announcements for an enrolled course."""
    student_data = await get_current_student(x_user_id)
    db = get_database()
    student_id = student_data["student"]["studentId"]
    
    # Verify student is enrolled in this course
    is_enrolled = await verify_student_enrollment(db, course_id, student_id)
    if not is_enrolled:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student is not enrolled in this course",
        )
    
    # Get announcements for this course
    cursor = db[ANNOUNCEMENTS_COLLECTION].find(
        {"courseId": course_id}
    ).sort("createdAt", -1)
    announcements = await cursor.to_list(length=200)
    return [serialize_document(a) for a in announcements]


@router.get("/me/seats")
async def get_student_seats(x_user_id: str | None = Header(None, alias="X-User-Id")):
    student_data = await get_current_student(x_user_id)
    db = get_database()

    cursor = db[SEAT_RESERVATIONS_COLLECTION].find({"userId": student_data["user"]["userId"]}).sort("updatedAt", -1)
    reservations = await cursor.to_list(length=500)
    return [serialize_document(reservation) for reservation in reservations]


@router.post("/me/seats", status_code=status.HTTP_201_CREATED)
async def create_student_seat(
    payload: SeatReservationRequest,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    student_data = await get_current_student(x_user_id)
    db = get_database()

    course = await db[COURSES_COLLECTION].find_one({"courseId": payload.courseId})
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    class_doc = await db[COURSE_CLASSES_COLLECTION].find_one(
        {"courseId": payload.courseId, "classId": payload.classId}
    )
    if class_doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found")

    enrollment = await db[ENROLLMENTS_COLLECTION].find_one(
        {
            "courseId": payload.courseId,
            "studentId": student_data["student"]["studentId"],
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        }
    )
    if enrollment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student is not enrolled in this course",
        )

    existing_reservation = await db[SEAT_RESERVATIONS_COLLECTION].find_one(
        {
            "studentId": student_data["student"]["studentId"],
            "classId": payload.classId,
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        }
    )
    if existing_reservation is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Duplicate active reservation for this student and class",
        )

    existing_seat = await db[SEAT_RESERVATIONS_COLLECTION].find_one(
        {
            "classId": payload.classId,
            "seatNumber": payload.seatNumber,
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        }
    )
    if existing_seat is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seat already taken",
        )

    reservation = {
        "reservationId": f"RES-{uuid4().hex[:12].upper()}",
        "userId": student_data["user"]["userId"],
        "studentId": student_data["student"]["studentId"],
        "courseId": payload.courseId,
        "classId": payload.classId,
        "seatNumber": payload.seatNumber,
        "status": "active",
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    }

    result = await db[SEAT_RESERVATIONS_COLLECTION].insert_one(reservation)
    reservation["_id"] = result.inserted_id
    return serialize_document(reservation)


@router.patch("/me/seats/{reservation_id}")
async def update_student_seat(
    reservation_id: str,
    payload: SeatReservationUpdateRequest,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    student_data = await get_current_student(x_user_id)
    db = get_database()

    reservation = await db[SEAT_RESERVATIONS_COLLECTION].find_one(
        {"reservationId": reservation_id, "userId": student_data["user"]["userId"]}
    )
    if reservation is None or reservation.get("status") == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reservation not found",
        )

    seat_taken = await db[SEAT_RESERVATIONS_COLLECTION].find_one(
        {
            "classId": reservation["classId"],
            "seatNumber": payload.seatNumber,
            "reservationId": {"$ne": reservation_id},
            "$or": [
                {"status": {"$exists": False}},
                {"status": {"$ne": "cancelled"}},
            ],
        }
    )
    if seat_taken is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seat already taken",
        )

    await db[SEAT_RESERVATIONS_COLLECTION].update_one(
        {"reservationId": reservation_id},
        {
            "$set": {
                "seatNumber": payload.seatNumber,
                "updatedAt": datetime.now(timezone.utc),
            }
        },
    )

    updated = await db[SEAT_RESERVATIONS_COLLECTION].find_one({"reservationId": reservation_id})
    return serialize_document(updated)


@router.delete("/me/seats/{reservation_id}")
async def cancel_student_seat(
    reservation_id: str,
    x_user_id: str | None = Header(None, alias="X-User-Id"),
):
    student_data = await get_current_student(x_user_id)
    db = get_database()

    reservation = await db[SEAT_RESERVATIONS_COLLECTION].find_one(
        {"reservationId": reservation_id, "userId": student_data["user"]["userId"]}
    )
    if reservation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reservation not found",
        )

    await db[SEAT_RESERVATIONS_COLLECTION].update_one(
        {"reservationId": reservation_id},
        {
            "$set": {
                "status": "cancelled",
                "updatedAt": datetime.now(timezone.utc),
            }
        },
    )

    return {"status": "cancelled", "reservationId": reservation_id}
