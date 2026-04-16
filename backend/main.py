import os
import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from config import settings
from routers import chat, voice, vision, search, sessions
from services.memory_service import init_db

AUDIO_DIR = "/tmp/ai-assistant-audio"
os.makedirs(AUDIO_DIR, exist_ok=True)

logger = structlog.get_logger()

app = FastAPI(
    title="AI Elder Assistant",
    description="韩语AI助手后端服务",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(chat.router, prefix="/chat", tags=["对话"])
app.include_router(voice.router, prefix="/voice", tags=["语音"])
app.include_router(vision.router, prefix="/vision", tags=["识图"])
app.include_router(search.router, prefix="/search", tags=["搜索"])
app.include_router(sessions.router, prefix="/sessions", tags=["会话"])

app.mount("/audio", StaticFiles(directory=AUDIO_DIR), name="audio")

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(STATIC_DIR, exist_ok=True)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.on_event("startup")
async def startup():
    await init_db()
    logger.info("服务启动成功")


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=settings.debug)
