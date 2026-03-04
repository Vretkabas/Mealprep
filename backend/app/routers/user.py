from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from app.services.user_services import save_user_settings, get_user_settings
from app.auth import get_current_user

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
        await save_user_settings(
            user_id=preferences.user_id,
            goal=preferences.goal,
            persons_count=preferences.persons_count,
            age=preferences.age,
            height=preferences.height,
            weight_current=preferences.weight_current,
            weight_target=preferences.weight_target,
            gender=preferences.gender,
            activity_level=preferences.activity_level,
            allergies=preferences.allergies,
        )

        return {"message": "User settings saved successfully"}

    except Exception as e:
        print(f"Error saving user settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/user/settings")
async def get_user_preferences(user_id: str = Depends(get_current_user)):
    try:
        settings = await get_user_settings(user_id)
        if not settings:
            return {"total_savings": 0.0}
        return settings
    except Exception as e:
        print(f"Error fetching user settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))
