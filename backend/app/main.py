from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import db_health

app = FastAPI(
    title="Gas Cylinder Distribution API",
    version="0.1.0",
    description="Multi-tenant B2B LPG distributor-to-retailer delivery platform",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Idempotency-Key"],
)

app.include_router(api_router, prefix="/api/v1")


@app.get("/health")
def health():
    try:
        ok = db_health()
    except Exception:
        ok = False
    return {"status": "ok" if ok else "degraded", "database": ok}
