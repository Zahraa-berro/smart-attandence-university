from typing import Literal

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from passlib.context import CryptContext
from uuid import uuid4
from datetime import datetime, timezone

from app.api.v1.routes.attendance import STUDENTS_COLLECTION
from app.api.v1.routes.courses import COURSES_COLLECTION
from app.api.v1.routes.auth import USERS_COLLECTION, public_user
from app.api.v1.routes.sensors import SENSOR_COLLECTION
from app.db.mongodb import get_database

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


router = APIRouter()


@router.get("/admin/stats")
async def get_admin_stats():
    db = get_database()
    total_users = await db[USERS_COLLECTION].count_documents({})
    doctors = await db[USERS_COLLECTION].count_documents({"role": "doctor"})
    students = await db[USERS_COLLECTION].count_documents({"role": "student"})
    admins = await db[USERS_COLLECTION].count_documents({"role": "admin"})
    total_courses = await db[COURSES_COLLECTION].count_documents({})
    total_student_profiles = await db[STUDENTS_COLLECTION].count_documents({})
    active_users = await db[USERS_COLLECTION].count_documents({"isActive": {"$ne": False}})

    attendance_total = await db["attendance_records"].count_documents({})
    attendance_present = await db["attendance_records"].count_documents({"present": True})
    final_average = 0.0
    if attendance_total > 0:
        final_average = round((attendance_present / attendance_total) * 100, 2)

    return {
        "totalUsers": total_users,
        "doctors": doctors,
        "students": students,
        "admins": admins,
        "totalCourses": total_courses,
        "totalStudentProfiles": total_student_profiles,
        "activeUsers": active_users,
        "averageAttendance": final_average,
    }


@router.get("/users")
async def get_users(
    role: Literal["student", "doctor", "admin"] | None = None,
    includeInactive: bool | None = False,
):
    db = get_database()
    query: dict = {}
    if role:
        query["role"] = role
    if not includeInactive:
        query["isActive"] = {"$ne": False}

    cursor = db[USERS_COLLECTION].find(query).sort("createdAt", -1)
    users = await cursor.to_list(length=500)
    return [public_user(user) for user in users]


class UserUpdateRequest(BaseModel):
    name: str | None = None
    email: str | None = None
    department: str | None = None
    phoneNumber: str | None = None
    role: Literal["student", "doctor", "admin"] | None = None
    studentId: str | None = None


@router.patch("/users/{user_id}")
async def update_user(user_id: str, payload: UserUpdateRequest):
    db = get_database()

    # Try to find by userId first, then by _id string
    user = await db[USERS_COLLECTION].find_one({"userId": user_id})
    if user is None:
        # fallback to ObjectId string match
        user = await db[USERS_COLLECTION].find_one({"_id": user_id})

    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    update_fields = {}
    if payload.name is not None:
        update_fields["name"] = payload.name.strip()
    if payload.email is not None:
        update_fields["email"] = payload.email.strip().lower()
    if payload.department is not None:
        update_fields["department"] = payload.department.strip()
    if payload.phoneNumber is not None:
        update_fields["phoneNumber"] = payload.phoneNumber.strip()
    if payload.role is not None:
        update_fields["role"] = payload.role
    if payload.studentId is not None:
        update_fields["studentId"] = payload.studentId.strip()

    if not update_fields:
        return public_user(user)

    # Prevent changing the last active admin to a non-admin role
    if user.get("role") == "admin" and payload.role is not None and payload.role != "admin":
        admins_count = await db[USERS_COLLECTION].count_documents({"role": "admin", "isActive": {"$ne": False}})
        if admins_count <= 1:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot convert the last admin to another role")

    await db[USERS_COLLECTION].update_one({"userId": user["userId"]}, {"$set": update_fields})

    new_role = update_fields.get("role", user.get("role"))
    old_role = user.get("role")

    # Role changed to student: ensure profile exists
    if new_role == "student":
        student_id = update_fields.get("studentId") or user.get("studentId")
        if not student_id:
            student_id = f"S{uuid4().hex[:12].upper()}"
            await db[USERS_COLLECTION].update_one({"userId": user["userId"]}, {"$set": {"studentId": student_id}})

        student_profile_data = {
            "studentId": student_id,
            "userId": user["userId"],
            "name": update_fields.get("name", user["name"]).strip(),
            "email": update_fields.get("email", user["email"]).strip().lower(),
            "department": update_fields.get("department", user.get("department", "General")).strip() if (update_fields.get("department") or user.get("department")) else "General",
            "phoneNumber": update_fields.get("phoneNumber", user.get("phoneNumber")),
            "createdAt": datetime.now(timezone.utc),
            "isActive": True,
        }
        await db[STUDENTS_COLLECTION].update_one(
            {"$or": [{"studentId": student_id}, {"userId": user["userId"]}]},
            {"$set": student_profile_data},
            upsert=True,
        )

    # Role changed from student to doctor/admin => keep profile but mark it inactive
    if old_role == "student" and new_role != "student":
        await db[STUDENTS_COLLECTION].update_one(
            {"userId": user["userId"]},
            {"$set": {"isActive": False, "roleChanged": new_role}},
        )

    # If user remains or becomes student, sync student profile fields
    if new_role == "student" or old_role == "student":
        student_query = {"$or": [{"userId": user["userId"]}]}
        student_update = {"$set": {}}
        if payload.studentId is not None:
            student_update["$set"]["studentId"] = payload.studentId.strip()
        if payload.name is not None:
            student_update["$set"]["name"] = payload.name.strip()
        if payload.email is not None:
            student_update["$set"]["email"] = payload.email.strip().lower()
        if payload.department is not None:
            student_update["$set"]["department"] = payload.department.strip()
        if payload.phoneNumber is not None:
            student_update["$set"]["phoneNumber"] = payload.phoneNumber.strip()

        if student_update["$set"] and new_role == "student":
            await db[STUDENTS_COLLECTION].update_one(student_query, student_update, upsert=True)

    updated = await db[USERS_COLLECTION].find_one({"userId": user["userId"]})
    return public_user(updated)


@router.delete("/users/{user_id}")
async def delete_user(user_id: str):
    db = get_database()
    user = await db[USERS_COLLECTION].find_one({"userId": user_id})
    if user is None:
        user = await db[USERS_COLLECTION].find_one({"_id": user_id})
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Prevent removing last admin
    if user.get("role") == "admin":
        admins_count = await db[USERS_COLLECTION].count_documents({"role": "admin", "isActive": {"$ne": False}})
        if admins_count <= 1:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete the last admin")

    # Soft delete: mark isActive = False and set deactivatedAt
    await db[USERS_COLLECTION].update_one({"userId": user["userId"]}, {"$set": {"isActive": False}})

    # If student, also deactivate student profile
    if user.get("role") == "student":
        await db[STUDENTS_COLLECTION].update_one({"userId": user["userId"]}, {"$set": {"isActive": False}})

    return {"status": "ok"}


class AdminCreateRequest(BaseModel):
    name: str
    email: str
    password: str
    role: Literal["student", "doctor", "admin"]
    phoneNumber: str | None = None
    studentId: str | None = None
    department: str | None = None


@router.post("/admin/users")
async def create_user_admin(payload: AdminCreateRequest):
    db = get_database()
    email = payload.email.strip().lower()

    existing_user = await db[USERS_COLLECTION].find_one({"email": email})
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Email is already registered"
        )

    user = {
        "userId": f"U{uuid4().hex[:12].upper()}",
        "name": payload.name.strip(),
        "email": email,
        "passwordHash": pwd_context.hash(payload.password),
        "role": payload.role,
        "createdAt": datetime.now(timezone.utc),
        "isActive": True,
    }
    if payload.phoneNumber:
        user["phoneNumber"] = payload.phoneNumber.strip()
    if payload.studentId:
        user["studentId"] = payload.studentId.strip()
    if payload.department:
        user["department"] = payload.department.strip()

    result = await db[USERS_COLLECTION].insert_one(user)
    user["_id"] = result.inserted_id

    # If student, create/update student profile
    if payload.role == "student":
        student_id = payload.studentId.strip() if payload.studentId else f"S{uuid4().hex[:12].upper()}"
        student_profile_data = {
            "studentId": student_id,
            "userId": user["userId"],
            "name": payload.name.strip(),
            "email": email,
            "department": payload.department.strip() if payload.department else "General",
            "phoneNumber": payload.phoneNumber.strip() if payload.phoneNumber else None,
            "createdAt": datetime.now(timezone.utc),
            "isActive": True,
        }
        await db[STUDENTS_COLLECTION].update_one(
            {"$or": [{"studentId": student_id}, {"email": email}]}, {"$set": student_profile_data}, upsert=True
        )

    return public_user(user)


@router.patch("/users/{user_id}/activate")
async def activate_user(user_id: str):
    db = get_database()
    user = await db[USERS_COLLECTION].find_one({"userId": user_id})
    if user is None:
        user = await db[USERS_COLLECTION].find_one({"_id": user_id})
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    await db[USERS_COLLECTION].update_one({"userId": user["userId"]}, {"$set": {"isActive": True}})

    if user.get("role") == "student":
        await db[STUDENTS_COLLECTION].update_one({"userId": user["userId"]}, {"$set": {"isActive": True}})

    updated = await db[USERS_COLLECTION].find_one({"userId": user["userId"]})
    return public_user(updated)


@router.get("/admin/sensors/overview")
async def get_admin_sensor_overview():
    db = get_database()
    cursor = db[SENSOR_COLLECTION].find({}).sort("timestamp", -1)
    readings = await cursor.to_list(length=500)

    latest_by_room: dict[str, dict] = {}
    for reading in readings:
        room = reading.get("classroomId")
        if room and room not in latest_by_room:
            latest_by_room[room] = reading

    values = list(latest_by_room.values())
    count = len(values)
    status_counts = {"good": 0, "moderate": 0, "critical": 0}
    temp_sum = 0.0
    humidity_sum = 0.0
    air_sum = 0.0
    noise_sum = 0.0
    latest_ts = None
    most_critical = None
    for reading in values:
        status = reading.get("classroomStatus", "good")
        if status in status_counts:
            status_counts[status] += 1
        temp_sum += float(reading.get("temperature", 0))
        humidity_sum += float(reading.get("humidity", 0))
        air_sum += float(reading.get("airQuality", 0))
        noise_sum += float(reading.get("noiseLevel", 0))
        ts = reading.get("timestamp")
        if latest_ts is None or (ts and ts > latest_ts):
            latest_ts = ts
        if status == "critical" and most_critical is None:
            most_critical = reading.get("classroomId")

    average_temperature = count > 0 and round(temp_sum / count, 1) or 0.0
    average_humidity = count > 0 and round(humidity_sum / count, 1) or 0.0
    average_air_quality = count > 0 and round(air_sum / count, 1) or 0.0
    average_noise_level = count > 0 and round(noise_sum / count, 1) or 0.0

    return {
        "latestReadingsCount": count,
        "goodClassrooms": status_counts["good"],
        "moderateClassrooms": status_counts["moderate"],
        "criticalClassrooms": status_counts["critical"],
        "averageTemperature": average_temperature,
        "averageHumidity": average_humidity,
        "averageAirQuality": average_air_quality,
        "averageNoiseLevel": average_noise_level,
        "mostCriticalClassroom": most_critical,
        "latestTimestamp": latest_ts,
    }
class FcmTokenRequest(BaseModel):
    fcmToken: str

@router.post("/users/{user_id}/fcm-token")
async def save_fcm_token(user_id: str, payload: FcmTokenRequest):
    db = get_database()
    await db[USERS_COLLECTION].update_one(
        {"userId": user_id},
        {"$set": {"fcmToken": payload.fcmToken}},
    )
    return {"status": "ok"}

@router.delete("/users/{user_id}/fcm-token")
async def clear_fcm_token(user_id: str):
    db = get_database()
    await db[USERS_COLLECTION].update_one(
        {"userId": user_id},
        {"$unset": {"fcmToken": ""}},
    )
    return {"status": "ok"}