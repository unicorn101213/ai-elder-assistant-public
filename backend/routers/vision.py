"""
识图路由
POST /vision — 图片 + 可选问题 → 韩语回复
"""

from fastapi import APIRouter, File, Form, UploadFile

from services import memory_service, qwen_service

router = APIRouter()


@router.post("")
async def analyze_image(
    image: UploadFile = File(...),
    session_id: str = Form(...),
    question: str = Form(default=""),
):
    """
    上传图片（药品说明书、商品标签等），返回韩语识别结果。
    识别结果同时保存到会话历史。
    """
    image_data = await image.read()
    history = await memory_service.get_session_history(session_id)
    result = await qwen_service.vision_chat(image_data, question, session_history=history)

    # 保存到会话记忆 — 用户消息包含图片描述，便于后续文字对话时模型理解上下文
    user_msg = f"[사진을 보냈습니다] {question}" if question else "[사진을 보냈습니다]"
    await memory_service.save_message(session_id, "user", user_msg, "image")
    await memory_service.save_message(session_id, "assistant", result)

    return {"result": result}
