from datetime import datetime, timezone
import random

from fastapi import APIRouter

from app.db.mongodb import get_database


router = APIRouter(prefix="/sensors")

SENSOR_COLLECTION = "sensor_data"
CLASSROOM_IDS = ["R101", "R102"]


def serialize_sensor_reading(reading: dict) -> dict:
    reading["_id"] = str(reading["_id"])
    return reading


def build_alerts(reading: dict) -> list[str]:
    alerts = []

    if reading["temperature"] > 30:
        alerts.append("high_temperature")
    if reading["humidity"] > 70:
        alerts.append("high_humidity")
    if reading["airQuality"] > 100:
        alerts.append("poor_air_quality")
    if reading["noiseLevel"] > 80:
        alerts.append("high_noise")
    if reading["occupancy"] > 35:
        alerts.append("high_occupancy")

    return alerts


def classroom_status(alerts: list[str]) -> str:
    if len(alerts) >= 3:
        return "critical"
    if alerts:
        return "moderate"
    return "good"


def generate_sensor_reading() -> dict:
    timestamp = datetime.now(timezone.utc)

    reading = {
        "sensorId": f"SD{timestamp.strftime('%Y%m%d%H%M%S')}{random.randint(1000, 9999)}",
        "classroomId": random.choice(CLASSROOM_IDS),
        "temperature": round(random.uniform(18, 35), 2),
        "humidity": random.randint(30, 80),
        "airQuality": random.randint(20, 150),
        "noiseLevel": random.randint(30, 100),
        "occupancy": random.randint(0, 40),
        "timestamp": timestamp,
    }

    alerts = build_alerts(reading)
    reading["classroomStatus"] = classroom_status(alerts)
    reading["alertsTriggered"] = alerts

    return reading


async def get_sensor_readings(query: dict, limit: int) -> list[dict]:
    db = get_database()
    cursor = (
        db[SENSOR_COLLECTION]
        .find(query)
        .sort("timestamp", -1)
        .limit(limit)
    )

    readings = await cursor.to_list(length=limit)
    return [serialize_sensor_reading(reading) for reading in readings]


@router.post("/generate-random")
async def generate_random_sensor_reading():
    db = get_database()
    reading = generate_sensor_reading()

    result = await db[SENSOR_COLLECTION].insert_one(reading)
    reading["_id"] = result.inserted_id

    return serialize_sensor_reading(reading)


@router.get("/latest")
async def latest_sensor_readings():
    return await get_sensor_readings({}, 10)


@router.get("/history")
async def sensor_history():
    return await get_sensor_readings({}, 100)


@router.get("/classroom/{classroom_id}")
async def classroom_sensor_readings(classroom_id: str):
    return await get_sensor_readings({"classroomId": classroom_id}, 50)
