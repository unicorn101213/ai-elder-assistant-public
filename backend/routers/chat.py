"""
对话路由
POST /chat — 文字对话（Qwen 原生搜索，模型自主判断是否联网）
"""

from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from services import memory_service, qwen_service

router = APIRouter()


class ChatRequest(BaseModel):
    session_id: str
    message: str
    use_search: bool = False  # True=强制搜索（地球图标），False=模型自主判断


@router.post("")
async def chat(req: ChatRequest):
    """对话 — Qwen 原生搜索能力，模型自主判断是否需要联网"""
    history = await memory_service.get_session_history(req.session_id)
    await memory_service.save_message(req.session_id, "user", req.message)

    async def generate():
        full_response = ""
        async for chunk in qwen_service.chat_stream(
            messages=[{"role": "user", "content": req.message}],
            session_history=history,
            enable_search=True,
            forced_search=req.use_search,
        ):
            full_response += chunk
            yield chunk.encode("utf-8")

        await memory_service.save_message(req.session_id, "assistant", full_response)

    return StreamingResponse(generate(), media_type="text/plain; charset=utf-8")
