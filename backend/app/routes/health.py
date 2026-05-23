import os
from datetime import datetime
import boto3
from botocore.exceptions import ClientError
from fastapi import APIRouter, Depends, HTTPException, status
from app.auth import verify_jwt
from app.schemas import HealthSyncPayload

router = APIRouter(prefix="/api/v1/private/health", tags=["health"])

# Initialize the DynamoDB resource globally to benefit from AWS Lambda container reuse
dynamodb = boto3.resource("dynamodb", region_name=os.getenv("AWS_REGION", "us-east-2"))
table_name = os.getenv("TABLE_NAME")

def get_table():
    if not table_name:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="DynamoDB environment variable 'TABLE_NAME' is not configured"
        )
    return dynamodb.Table(table_name)

@router.post("/sync", status_code=status.HTTP_200_OK)
def sync_health_data(
    payload: HealthSyncPayload,
    user_id: str = Depends(verify_jwt),
    table = Depends(get_table)
):
    """
    Saves/updates daily health telemetry aggregate summaries into DynamoDB.
    Access is restricted: users can only write to their own namespace.
    """
    pk = f"USER#{user_id}"
    sk = f"HEALTH#{payload.sync_date}"
    
    # Standardized ISO timestamp with Z suffix for Zulu/UTC
    now_iso = datetime.utcnow().isoformat() + "Z"
    
    try:
        # Standard put_item will create the record or overwrite existing daily summary (upsert)
        table.put_item(
            Item={
                "PK": pk,
                "SK": sk,
                "step_count": payload.step_count,
                "active_energy_kcal": payload.active_energy_kcal,
                "sleep_hours": payload.sleep_hours,
                "water_intake_liters": payload.water_intake_liters,
                "updated_at": now_iso
            }
        )
    except ClientError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database write failed: {e.response['Error']['Message']}"
        )
        
    return {
        "status": "success",
        "message": f"Successfully synced health metrics for {payload.sync_date}",
        "user_id": user_id
    }
