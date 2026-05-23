import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum
from app.routes.health import router as health_router

app = FastAPI(
    title="Life-XP Serverless Backend",
    description="Secure, HIPAA-compliant serverless API backend for Life-XP",
    version="1.0.0"
)

# Configures CORS. Secure strictly in production to align with your API limits and iOS app domain.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update with restricted origins in production settings
    allow_credentials=True,
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)

# Security Headers Middleware (injects standards outlined in security best-practices)
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none';"
    return response

# Public System Route (Allowlisted)
@app.get("/health", tags=["system"])
def health_check():
    """
    Unauthenticated public health-check endpoint.
    """
    return {
        "status": "healthy",
        "region": os.getenv("AWS_REGION", "us-east-2"),
        "version": "1.0.0"
    }

# Register private/authenticated telemetry routes
app.include_router(health_router)

# Serverless ASGI adapter wrapping for AWS Lambda executions
handler = Mangum(app)
