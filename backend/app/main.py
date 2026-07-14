from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.db.mongodb import close_mongo_connection, connect_to_mongo
from app.services.ai_service import check_ai_model_folder
from fastapi.staticfiles import StaticFiles
from pathlib import Path

@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_to_mongo()
    yield
    await close_mongo_connection()


settings = get_settings()

app = FastAPI(
    title=settings.APP_NAME,
    lifespan=lifespan,
)


uploads_path = Path("uploads")
if uploads_path.exists():
    app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,  # ← change True to False
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(
    api_router,
    prefix=settings.API_V1_PREFIX,
)


@app.get("/")
async def root():
    return {
        "message": "Smart University Backend is running",
    }


@app.get("/ai-status")
async def ai_status():
    return check_ai_model_folder()  