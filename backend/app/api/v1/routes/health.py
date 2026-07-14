from fastapi import APIRouter

from app.db.mongodb import get_database

router = APIRouter()


@router.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "smart-university-backend",
    }


@router.get("/health/db")
async def database_health_check():
    db = get_database()

    await db.command("ping")

    return {
        "status": "ok",
        "database": "connected",
    }