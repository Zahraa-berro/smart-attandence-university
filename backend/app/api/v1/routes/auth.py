from datetime import datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status
from passlib.context import CryptContext
from pydantic import BaseModel, Field

from app.db.mongodb import get_database
from app.api.v1.routes.attendance import STUDENTS_COLLECTION # Import STUDENTS_COLLECTION


router = APIRouter(prefix="/auth")

USERS_COLLECTION = "users"
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1)
    email: str = Field(min_length=3)
    password: str = Field(min_length=6)
    role: Literal["student", "doctor", "admin"]
    phoneNumber: str | None = None
    studentId: str | None = None
    department: str | None = None


class LoginRequest(BaseModel):
    email: str = Field(min_length=3)
    password: str = Field(min_length=1)


def public_user(user: dict) -> dict:
    data = {
        "_id": str(user["_id"]),
        "userId": user["userId"],
        "name": user["name"],
        "email": user["email"],
        "role": user["role"],
        "createdAt": user["createdAt"],
    }
    for field in ["phoneNumber", "studentId", "department"]:
        if field in user:
            data[field] = user[field]
    if "isActive" in user:
        data["isActive"] = user["isActive"]
    return data


@router.post("/register")
async def register_user(payload: RegisterRequest):
    db = get_database()
    email = payload.email.strip().lower()
    # Prevent public registration of admin accounts from the public endpoint
    if payload.role == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot create admin users from public registration",
        )
    existing_user = await db[USERS_COLLECTION].find_one({"email": email})
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email is already registered",
        )

    user = {
        "userId": f"U{uuid4().hex[:12].upper()}",
        "name": payload.name.strip(),
        "email": email,
        "passwordHash": pwd_context.hash(payload.password),
        "role": payload.role,
        "createdAt": datetime.now(timezone.utc),
    }
    if payload.phoneNumber:
        user["phoneNumber"] = payload.phoneNumber.strip()
    if payload.studentId:
        user["studentId"] = payload.studentId.strip()
    if payload.department:
        user["department"] = payload.department.strip()

    result = await db[USERS_COLLECTION].insert_one(user)
    user["_id"] = result.inserted_id

    # If the user is a student, create or update a corresponding student profile
    if payload.role == "student":
        # Generate studentId if not provided
        student_id = payload.studentId.strip() if payload.studentId else f"S{uuid4().hex[:12].upper()}"
        
        student_profile_data = {
            "studentId": student_id,
            "userId": user["userId"], # Link to the newly created user
            "name": payload.name.strip(),
            "email": email,
            "department": payload.department.strip() if payload.department else "General",
            "phoneNumber": payload.phoneNumber.strip() if payload.phoneNumber else None,
            "createdAt": datetime.now(timezone.utc),
        }

        # Use upsert to handle both creation and update if a matching student profile exists
        # This avoids duplicates by studentId or email and handles existing seeded students.
        await db[STUDENTS_COLLECTION].update_one(
            {"$or": [{"studentId": student_id}, {"email": email}]},
            {"$set": student_profile_data},
            upsert=True
        )

    return public_user(user)


@router.post("/login")
async def login_user(payload: LoginRequest):
    db = get_database()
    email = payload.email.strip().lower()

    user = await db[USERS_COLLECTION].find_one({"email": email})
    if user is None or not pwd_context.verify(
        payload.password,
        user["passwordHash"],
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    # Reject login for deactivated users
    if user.get("isActive") is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    return public_user(user)
