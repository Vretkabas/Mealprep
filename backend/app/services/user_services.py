import uuid
from typing import List, Optional, Dict, Any
from app.services.database_service import get_database_service


# calorie and protein target calculations based on user info

# Activity level multipliers (Mifflin-St Jeor)
ACTIVITY_MULTIPLIERS = {
    "low": 1.2,              # Sedentary
    "slightly_active": 1.375, # Light exercise 1-3 days/week
    "medium": 1.55,           # Moderate exercise 3-5 days/week
    "very_active": 1.725,     # Heavy exercise 6-7 days/week
}

# Goal adjustments (calorie surplus/deficit)
GOAL_ADJUSTMENTS = {
    "lose": -500,      # 500 kcal deficit per day (~0.5kg/week)
    "maintain": 0,
    "gain": 300,       # 300 kcal surplus per day
}


def calculate_bmr(gender: str, weight_kg: float, height_cm: float, age: int) -> float:
    """
    Calculate Basal Metabolic Rate using Mifflin-St Jeor equation.
    Returns BMR in kcal/day.
    """
    if gender == "Man":
        return (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
    else:
        return (10 * weight_kg) + (6.25 * height_cm) - (5 * age) - 161


def calculate_daily_targets(
    gender: Optional[str],
    weight_current: Optional[float],
    height: Optional[float],
    age: Optional[int],
    activity_level: Optional[str],
    goal: Optional[str],
) -> tuple[Optional[int], Optional[float]]:
    """
    Calculate daily calorie and protein targets.
    Returns (daily_calorie_target, daily_protein_target).
    """
    # Need all fields to calculate
    if not all([gender, weight_current, height, age, activity_level, goal]):
        return None, None

    # Step 1: BMR
    bmr = calculate_bmr(gender, weight_current, height, age)

    # Step 2: TDEE (Total Daily Energy Expenditure)
    multiplier = ACTIVITY_MULTIPLIERS.get(activity_level, 1.2)
    tdee = bmr * multiplier

    # Step 3: Adjust for goal
    adjustment = GOAL_ADJUSTMENTS.get(goal, 0)
    daily_calories = round(tdee + adjustment)

    # Step 4: Protein target (g/day)
    # Lose weight: 2.0g/kg (preserve muscle), Maintain: 1.6g/kg, Gain: 1.8g/kg
    protein_multipliers = {"lose": 2.0, "maintain": 1.6, "gain": 1.8}
    protein_per_kg = protein_multipliers.get(goal, 1.6)
    daily_protein = round(weight_current * protein_per_kg, 2)

    return daily_calories, daily_protein


# db operations for user settings

async def save_user_settings(
    user_id: str,
    goal: Optional[str] = None,
    persons_count: Optional[int] = None,
    age: Optional[int] = None,
    height: Optional[float] = None,
    weight_current: Optional[float] = None,
    weight_target: Optional[float] = None,
    gender: Optional[str] = None,
    activity_level: Optional[str] = None,
    allergies: Optional[List[str]] = None,
) -> str:
    """Insert or update user settings, return preference_id."""
    db = await get_database_service()
    preference_id = str(uuid.uuid4())

    # Calculate daily targets based on user info
    daily_calories, daily_protein = calculate_daily_targets(
        gender, weight_current, height, age, activity_level, goal
    )

    async with db.pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO user_settings (
                preference_id, user_id, goal, persons_count, age, height,
                weight_current, weight_target, gender,
                activity_level, allergens,
                daily_calorie_target, daily_protein_target
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            ON CONFLICT (user_id) DO UPDATE SET
                goal = $3,
                persons_count = $4,
                age = $5,
                height = $6,
                weight_current = $7,
                weight_target = $8,
                gender = $9,
                activity_level = $10,
                allergens = $11,
                daily_calorie_target = $12,
                daily_protein_target = $13
            """,
            preference_id,
            user_id,
            goal,
            persons_count,
            age,
            height,
            weight_current,
            weight_target,
            gender,
            activity_level,
            allergies,
            daily_calories,
            daily_protein,
        )

    return preference_id


async def get_user_settings(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user settings by user_id."""
    db = await get_database_service()

    async with db.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM user_settings WHERE user_id = $1",
            user_id,
        )
        return dict(row) if row else None
