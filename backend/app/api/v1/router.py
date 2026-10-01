from fastapi import APIRouter

from app.api.v1 import auth, catalog, field, ops, routes, shifts
from app.api.v1.inventory import router as inventory_router
from app.api.v1.credit import router as credit_router

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(catalog.router)
api_router.include_router(shifts.router)
api_router.include_router(routes.router)
api_router.include_router(field.router)
api_router.include_router(ops.router)
api_router.include_router(inventory_router)
api_router.include_router(credit_router)
