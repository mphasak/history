import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db import init_pool, close_pool
from .perspectives import router as perspectives_router
from .routes.world import router as world_router
from .routes.trait import router as trait_router
from .routes.claim import router as claim_router
from .routes.carrier import router as carrier_router
from .routes.basemap import router as basemap_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    dsn = os.environ["DATABASE_URL"]
    await init_pool(dsn)
    yield
    await close_pool()


app = FastAPI(
    title="Human History Simulator API",
    description="Spatiotemporal map of human history with Perspective-based rendering.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(perspectives_router)
app.include_router(world_router)
app.include_router(trait_router)
app.include_router(claim_router)
app.include_router(carrier_router)
app.include_router(basemap_router)


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}
