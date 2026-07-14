from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from app.api.v1.routes.notifications import create_notification
from app.db.mongodb import get_database

router = APIRouter()

GRADES_COLLECTION = "grades"
GRADE_COMPONENTS_COLLECTION = "grade_components"


class GradeComponent(BaseModel):
    name: str
    percentage: float = Field(ge=0, le=100)


class GradeComponentsUpdate(BaseModel):
    components: list[GradeComponent]


class StudentGrade(BaseModel):
    studentId: str
    studentName: str
    courseId: str
    classId: str | None = None
    componentScores: dict[str, float] = Field(default_factory=dict)


class BulkGradeUpsert(BaseModel):
    courseId: str
    classId: str | None = None
    grades: list[StudentGrade]


def serialize_document(document: dict) -> dict:
    document["_id"] = str(document["_id"])
    return document


def calculate_total(components: list[dict], scores: dict[str, float]) -> float:
    total = 0.0
    for comp in components:
        percentage = comp.get("percentage", 0)
        score = scores.get(comp["name"], 0)
        total += (score * percentage / 100)
    return round(total, 2)


@router.get("/courses/{course_id}/grade-components")
async def get_grade_components(course_id: str, class_id: str | None = None):
    db = get_database()
    query = {"courseId": course_id}
    if class_id:
        query["classId"] = class_id
    else:
        query["classId"] = {"$exists": False}
    
    doc = await db[GRADE_COMPONENTS_COLLECTION].find_one(query)
    if doc:
        return serialize_document(doc)
    
    default_components = {
        "courseId": course_id,
        "classId": class_id,
        "components": [
            {"name": "Midterm", "percentage": 30},
            {"name": "Final Exam", "percentage": 40},
            {"name": "Project", "percentage": 30},
        ],
        "createdAt": datetime.now(timezone.utc),
    }
    return default_components


@router.post("/courses/{course_id}/grade-components")
async def set_grade_components(course_id: str, payload: GradeComponentsUpdate, class_id: str | None = None):
    db = get_database()
    
    total_percentage = sum(c.percentage for c in payload.components)
    if abs(total_percentage - 100) > 0.01:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Total percentage must sum to 100, got {total_percentage}",
        )
    
    query = {"courseId": course_id}
    if class_id:
        query["classId"] = class_id
    
    components_data = {
        "courseId": course_id,
        "classId": class_id,
        "components": [c.model_dump() for c in payload.components],
        "updatedAt": datetime.now(timezone.utc),
    }
    
    await db[GRADE_COMPONENTS_COLLECTION].update_one(
        query,
        {"$set": components_data, "$setOnInsert": {"createdAt": datetime.now(timezone.utc)}},
        upsert=True,
    )
    
    return {"status": "ok", "components": payload.components}


@router.post("/grades/bulk", status_code=200)
async def save_grades(payload: BulkGradeUpsert):
    db = get_database()
    now = datetime.now(timezone.utc)

    components_doc = await db[GRADE_COMPONENTS_COLLECTION].find_one({
        "courseId": payload.courseId,
        "classId": payload.classId if payload.classId else {"$exists": False}
    })
    components = components_doc.get("components", []) if components_doc else []

    for grade in payload.grades:
        total = calculate_total(components, grade.componentScores)

        query = {"studentId": grade.studentId, "courseId": grade.courseId}
        if grade.classId:
            query["classId"] = grade.classId

        scores = grade.componentScores or {}

        def _extract(key_substr: str) -> float:
            for k, v in scores.items():
                if key_substr in k.lower():
                    try:
                        return float(v)
                    except Exception:
                        return 0.0
            return 0.0

        midterm_val = _extract('midterm')
        final_val   = _extract('final')
        project_val = _extract('project')

        await db[GRADES_COLLECTION].update_one(
            query,
            {
                "$set": {
                    "studentId":      grade.studentId,
                    "studentName":    grade.studentName,
                    "courseId":       grade.courseId,
                    "classId":        grade.classId,
                    "componentScores": grade.componentScores,
                    "total":          total,
                    "midterm":        midterm_val,
                    "finalExam":      final_val,
                    "project":        project_val,
                    "updatedAt":      now,
                },
                "$setOnInsert": {"createdAt": now},
            },
            upsert=True,
        )

        # ── Notify the student ────────────────────────────────────────────
        user = await db["users"].find_one({"studentId": grade.studentId})
        if user:
            uid = user.get("userId") or str(user["_id"])
            await create_notification(
                db,
                student_id=uid,
                notif_type="grade",
                title="Grades updated",
                message=f"Your grades for course {grade.courseId} have been updated. Total: {total}%",
                metadata={
                    "courseId": grade.courseId,
                    "classId":  grade.classId,
                    "total":    total,
                },
            )

    return {"status": "ok", "saved": len(payload.grades)}


@router.get("/grades/course/{course_id}")
async def get_course_grades(course_id: str, class_id: str | None = None):
    db = get_database()
    query = {"courseId": course_id}
    if class_id:
        query["classId"] = class_id
    cursor = db[GRADES_COLLECTION].find(query)
    grades = await cursor.to_list(length=500)
    return [serialize_document(g) for g in grades]


@router.get("/grades/student/{student_id}")
async def get_student_grades(student_id: str):
    db = get_database()
    cursor = db[GRADES_COLLECTION].find({"studentId": student_id})
    grades = await cursor.to_list(length=500)
    return [serialize_document(g) for g in grades]


@router.get("/grades/course/{course_id}/student/{student_id}")
async def get_student_course_grade(course_id: str, student_id: str, class_id: str | None = None):
    db = get_database()
    query = {
        "courseId": course_id,
        "studentId": student_id,
    }
    if class_id:
        query["classId"] = class_id
    grade = await db[GRADES_COLLECTION].find_one(query)
    if grade is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grade not found",
        )
    return serialize_document(grade)

@router.get("/grades/course/{course_id}/missing")
async def get_missing_grades(course_id: str, class_id: str | None = None):
    db = get_database()

    enroll_query = {"courseId": course_id, "status": "active"}
    if class_id:
        enroll_query["classId"] = class_id
    enrollments = await db["enrollments"].find(enroll_query).to_list(length=500)

    missing = []
    for enrollment in enrollments:
        student_number = enrollment.get("studentId")
        if not student_number:
            continue
        grade = await db["grades"].find_one({
            "courseId": course_id,
            "studentId": student_number,
        })
        if not grade:
            user = await db["users"].find_one({"studentId": student_number})
            if user:
                missing.append({
                    "studentId": student_number,
                    "userId": user.get("userId", ""),
                    "name": user.get("name", "Unknown"),
                })

    return missing