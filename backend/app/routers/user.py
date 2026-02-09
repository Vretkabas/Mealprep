from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

router = APIRouter()

# Schema for user data preferences

class UserPreferences(BaseModel):
    user_id: str
    goal: Optional[str] = None
    personsCount: Optional[int] = None
    age: Optional[int] = None
    height: Optional[float] = None
    weightCurrent: Optional[float] = None
    weightTarget: Optional[float] = None
    gender: Optional[str] = None
    activityLevel: Optional[str] = None
    allergies: Optional[List[str]] = None


# endpoint to save user preferences
@router.post("/user/preferences")
async def save_user_preferences(preferences: UserPreferences):
    # For demonstration, we will just return the preferences
    return {"message": "User preferences saved successfully", "data": preferences}

