from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.db.mongodb import get_database
from app.api.v1.routes.notifications import create_notification, notify_class_students  # ← new

router = APIRouter(prefix="/assignments")

ASSIGNMENTS_COLLECTION            = "assignments"
ASSIGNMENT_SUBMISSIONS_COLLECTION = "assignment_submissions"
COURSES_COLLECTION                = "courses"
COURSE_CLASSES_COLLECTION         = "course_classes"
STUDENTS_COLLECTION               = "users"


class AssignmentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    dueDate: datetime | None = None
    pdfUrl: str | None = None
    pdfBase64: str | None = None
    totalPoints: float = 100


class AssignmentUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    dueDate: datetime | None = None
    pdfBase64: str | None = None  # ← add this
    pdfUrl: str | None = None

    totalPoints: float | None = None


class AssignmentSubmissionCreate(BaseModel):
    studentId: str
    studentName: str
    pdfUrl: str | None = None
    pdfBase64: str | None = None  # ← add this
    comment: str | None = None


class GradeSubmissionRequest(BaseModel):
    grade: float = Field(ge=0)
    feedback: str | None = None


def serialize_document(document: dict) -> dict:
    document["_id"] = str(document["_id"])
    return document


@router.post("/course/{course_id}/class/{class_id}", status_code=status.HTTP_201_CREATED)
async def create_assignment(course_id: str, class_id: str, payload: AssignmentCreate):
    db = get_database()

    assignment = {
        "assignmentId": f"ASSIGN-{course_id}-{class_id}-{int(datetime.now(timezone.utc).timestamp())}",
        "courseId":     course_id,
        "classId":      class_id,
        "title":        payload.title,
        "description":  payload.description,
        "dueDate":      payload.dueDate,
        "pdfUrl":       payload.pdfUrl,
        "pdfBase64":    payload.pdfBase64,
        "totalPoints":  payload.totalPoints,
        "createdAt":    datetime.now(timezone.utc),
        "updatedAt":    datetime.now(timezone.utc),
    }

    result = await db[ASSIGNMENTS_COLLECTION].insert_one(assignment)
    assignment["_id"] = str(result.inserted_id)

    # ── Notify all enrolled students about the new assignment ─────────────────
    course_doc = await db[COURSES_COLLECTION].find_one({"courseId": course_id})
    course_name = (course_doc or {}).get("courseName") or course_id

    due_str = ""
    if payload.dueDate:
        due_str = f" — due {payload.dueDate.strftime('%b %d')}"

    await notify_class_students(
        db,
        course_id=course_id,
        class_id=class_id,
        notif_type="assignment",
        title=f"New assignment in {course_name}",
        message=f"\"{payload.title}\"{due_str}",
        metadata={
            "assignmentId": assignment["assignmentId"],
            "courseId":     course_id,
            "classId":      class_id,
            "courseName":   course_name,
        },
    )

    return serialize_document(assignment)


@router.get("/course/{course_id}/class/{class_id}")
async def get_class_assignments(course_id: str, class_id: str):
    db = get_database()
    cursor = (
        db[ASSIGNMENTS_COLLECTION]
        .find({"courseId": course_id, "classId": class_id})
        .sort("dueDate", 1)
    )
    assignments = await cursor.to_list(length=200)
    return [serialize_document(a) for a in assignments]


@router.get("/{assignment_id}")
async def get_assignment(assignment_id: str):
    db = get_database()
    assignment = await db[ASSIGNMENTS_COLLECTION].find_one({"assignmentId": assignment_id})
    if assignment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    return serialize_document(assignment)


@router.patch("/{assignment_id}")
async def update_assignment(assignment_id: str, payload: AssignmentUpdate):
    db = get_database()
    updates = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}
    if not updates:
        assignment = await db[ASSIGNMENTS_COLLECTION].find_one({"assignmentId": assignment_id})
        if assignment is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
        return serialize_document(assignment)

    updates["updatedAt"] = datetime.now(timezone.utc)
    result = await db[ASSIGNMENTS_COLLECTION].update_one(
        {"assignmentId": assignment_id}, {"$set": updates}
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    updated = await db[ASSIGNMENTS_COLLECTION].find_one({"assignmentId": assignment_id})
    return serialize_document(updated)


@router.delete("/{assignment_id}")
async def delete_assignment(assignment_id: str):
    db = get_database()
    result = await db[ASSIGNMENTS_COLLECTION].delete_one({"assignmentId": assignment_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].delete_many({"assignmentId": assignment_id})
    return {"status": "ok", "deleted": assignment_id}


@router.post("/{assignment_id}/submissions", status_code=status.HTTP_201_CREATED)
async def submit_assignment(assignment_id: str, payload: AssignmentSubmissionCreate):
    db = get_database()

    assignment = await db[ASSIGNMENTS_COLLECTION].find_one({"assignmentId": assignment_id})
    if assignment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    existing = await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].find_one({
        "assignmentId": assignment_id,
        "studentId":    payload.studentId,
    })

    submission = {
        "submissionId": f"SUB-{assignment_id}-{payload.studentId}",
        "assignmentId": assignment_id,
        "courseId":     assignment["courseId"],
        "classId":      assignment["classId"],
        "studentId":    payload.studentId,
        "studentName":  payload.studentName,
        "pdfUrl":       payload.pdfUrl,
        "pdfBase64": payload.pdfBase64,  # ← add this
        "comment":      payload.comment,
        "grade":        None,
        "feedback":     None,
        "submittedAt":  datetime.now(timezone.utc),
        "updatedAt":    datetime.now(timezone.utc),
    }

    if existing:
        await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].update_one(
            {"submissionId": submission["submissionId"]}, {"$set": submission}
        )
    else:
        await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].insert_one(submission)

        submission.pop("_id", None)
        doc = await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].find_one(
            {"submissionId": submission["submissionId"]}
        )
        return serialize_document(doc)


@router.get("/{assignment_id}/submissions")
async def get_assignment_submissions(assignment_id: str):
    db = get_database()
    cursor = (
        db[ASSIGNMENT_SUBMISSIONS_COLLECTION]
        .find({"assignmentId": assignment_id})
        .sort("submittedAt", -1)
    )
    submissions = await cursor.to_list(length=500)
    return [serialize_document(s) for s in submissions]


@router.patch("/submissions/{submission_id}/grade")
async def grade_submission(submission_id: str, payload: GradeSubmissionRequest):
    db = get_database()

    result = await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].update_one(
        {"submissionId": submission_id},
        {
            "$set": {
                "grade":    payload.grade,
                "feedback": payload.feedback,
                "gradedAt": datetime.now(timezone.utc),
            }
        },
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found")

    updated = await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].find_one(
        {"submissionId": submission_id}
    )

    # ── Notify the student their grade is ready ───────────────────────────────
    if updated:
        student_id  = updated.get("studentId")
        assignment  = await db[ASSIGNMENTS_COLLECTION].find_one(
            {"assignmentId": updated.get("assignmentId")}
        )
        course_doc  = await db[COURSES_COLLECTION].find_one(
            {"courseId": updated.get("courseId")}
        ) if updated.get("courseId") else None

        course_name = (course_doc or {}).get("courseName") or updated.get("courseId", "")
        assign_title = (assignment or {}).get("title") or updated.get("assignmentId", "")
        grade_val   = payload.grade
        total_pts   = (assignment or {}).get("totalPoints") or 100

        notif_message = f"You scored {grade_val}/{total_pts} on \"{assign_title}\""
        if payload.feedback:
            notif_message += f'. Feedback: "{payload.feedback[:60]}{"…" if len(payload.feedback) > 60 else ""}"'

        if student_id:
            await create_notification(
                db,
                student_id=student_id,
                notif_type="grade",
                title=f"Grade posted — {course_name}",
                message=notif_message,
                metadata={
                    "submissionId": submission_id,
                    "assignmentId": updated.get("assignmentId"),
                    "courseId":     updated.get("courseId"),
                    "classId":      updated.get("classId"),
                    "grade":        grade_val,
                    "totalPoints":  total_pts,
                },
            )

    return serialize_document(updated)


@router.get("/student/{student_id}/assignments")
async def get_student_assignments(student_id: str):
    db = get_database()
    cursor = (
        db[ASSIGNMENT_SUBMISSIONS_COLLECTION]
        .find({"studentId": student_id})
        .sort("submittedAt", -1)
    )
    submissions = await cursor.to_list(length=500)
    return [serialize_document(s) for s in submissions]

@router.get("/course/{course_id}/missing-submissions")
async def get_missing_submissions(course_id: str, class_id: str | None = None):
    db = get_database()

    # Get all assignments for this course
    query = {"courseId": course_id}
    if class_id:
        query["classId"] = class_id

    assignments = await db[ASSIGNMENTS_COLLECTION].find(query).to_list(length=200)

    # Get all enrollments
    enroll_query = {"courseId": course_id, "status": "active"}
    if class_id:
        enroll_query["classId"] = class_id
    enrollments = await db["enrollments"].find(enroll_query).to_list(length=500)

    result = []
    for assignment in assignments:
        assignment_id = assignment["assignmentId"]
        submitted_ids = set()
        submissions = await db[ASSIGNMENT_SUBMISSIONS_COLLECTION].find(
            {"assignmentId": assignment_id}
        ).to_list(length=500)
        for s in submissions:
            submitted_ids.add(s["studentId"])

        missing_students = []
        for enrollment in enrollments:
            student_number = enrollment.get("studentId")
            if not student_number:
                continue
            user = await db["users"].find_one({"studentId": student_number})
            if not user:
                continue
            uid = user.get("userId") or str(user["_id"])
            if uid not in submitted_ids and student_number not in submitted_ids:
                missing_students.append({
                    "studentId": student_number,
                    "userId": uid,
                    "name": user.get("name", "Unknown"),
                })

        if missing_students:
            result.append({
                "assignmentId": assignment_id,
                "title": assignment.get("title", ""),
                "dueDate": assignment.get("dueDate", "").isoformat() if assignment.get("dueDate") else "",
                "missingStudents": missing_students,
            })

    return result