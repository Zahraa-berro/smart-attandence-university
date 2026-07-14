from typing import Any

from pymongo import AsyncMongoClient

from app.core.config import get_settings


class MongoDB:
    client: AsyncMongoClient | None = None
    database: Any = None


mongodb = MongoDB()


async def connect_to_mongo() -> None:
    settings = get_settings()

    mongodb.client = AsyncMongoClient(
        settings.MONGODB_URI,
        serverSelectionTimeoutMS=5000,
    )

    mongodb.database = mongodb.client[settings.MONGODB_DB_NAME]

    await mongodb.client.admin.command("ping")

    print(f"Connected to MongoDB database: {settings.MONGODB_DB_NAME}")


async def close_mongo_connection() -> None:
    if mongodb.client is not None:
        await mongodb.client.close()
        print("MongoDB connection closed")


def get_database() -> Any:
    if mongodb.database is None:
        raise RuntimeError("MongoDB is not connected")

    return mongodb.database