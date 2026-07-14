from fastapi import APIRouter

from app.api.v1.routes import attendance, auth, notifications,courses, health, sensors, users, grades, students, assignments, uploads, announcements,ai_chat

api_router = APIRouter()

api_router.include_router(
    health.router,
    tags=["health"],
)

api_router.include_router(
    sensors.router,
    tags=["sensors"],
)

api_router.include_router(
    auth.router,
    tags=["auth"],
)

api_router.include_router(
    courses.router,
    tags=["courses"],
)

api_router.include_router(
    attendance.router,
    tags=["attendance"],
)

api_router.include_router(
    users.router,
    tags=["users"],
)

api_router.include_router(
    grades.router,
    tags=["grades"]
)

api_router.include_router(
    students.router,
    tags=["students"],
)

api_router.include_router(
    assignments.router,
    tags=["assignments"],
)

api_router.include_router(
    announcements.router,
    tags=["announcements"],
)

api_router.include_router(
    uploads.router,
    tags=["uploads"],
)
api_router.include_router(
    notifications.router,
    tags=["notifications"],
)
api_router.include_router(
    ai_chat.router,
    tags=["ai"],
)