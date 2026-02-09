from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uuid
from app.services.database_service import get_database_service

router = APIRouter()

# Schema for user data preferences

class UserPreferences(BaseModel):
    user_id: str
    goal: Optional[str] = None
    persons_count: Optional[int] = None
    age: Optional[int] = None
    height: Optional[float] = None
    weight_current: Optional[float] = None
    weight_target: Optional[float] = None
    gender: Optional[str] = None
    activity_level: Optional[str] = None
    allergies: Optional[List[str]] = None


# endpoint to save user settings
@router.post("/user/preferences")
async def save_user_preferences(preferences: UserPreferences):
    try:
        db = await get_database_service()

        async with db.pool.acquire() as conn:
            preference_id = str(uuid.uuid4())
            await conn.execute(
                """
                INSERT INTO user_settings (
                    preference_id, user_id, goal, persons_count, age, height,
                    weight_current, weight_target, gender,
                    activity_level, allergens
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                ON CONFLICT (user_id) DO UPDATE SET
                    goal = $3,
                    persons_count = $4,
                    age = $5,
                    height = $6,
                    weight_current = $7,
                    weight_target = $8,
                    gender = $9,
                    activity_level = $10,
                    allergens = $11
                """,
                preference_id,
                preferences.user_id,
                preferences.goal,
                preferences.persons_count,
                preferences.age,
                preferences.height,
                preferences.weight_current,
                preferences.weight_target,
                preferences.gender,
                preferences.activity_level,
                preferences.allergies,
            )

        return {"message": "User settings saved successfully"}

    except Exception as e:
        print(f"Error saving user settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))
