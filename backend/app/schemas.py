from pydantic import BaseModel, Field
from datetime import date

class HealthSyncPayload(BaseModel):
    sync_date: date = Field(..., description="The date of the health metrics in YYYY-MM-DD format")
    step_count: int = Field(default=0, ge=0, description="Cumulative step count for the day")
    active_energy_kcal: float = Field(default=0.0, ge=0.0, description="Active energy burned in kilocalories")
    sleep_hours: float = Field(default=0.0, ge=0.0, description="Duration of sleep in hours")
    water_intake_liters: float = Field(default=0.0, ge=0.0, description="Water intake in liters")
