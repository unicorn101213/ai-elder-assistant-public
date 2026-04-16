"""
语音路由
POST /voice/stt — 音频 → 韩语文字（Paraformer 异步）
POST /voice/tts — 文字 → 音频
"""

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

from services import qwen_service

router = APIRouter()


@router.post("/stt")
async def speech_to_text(
    audio: UploadFile = File(...),
    format: str = "wav",
):
    """语音识别：Paraformer-v2 异步识别"""
    audio_data = await audio.read()
    if not audio_data:
        raise HTTPException(status_code=400, detail="音频文件为空")

    text = await qwen_service.speech_to_text(audio_data, format)
    return {"text": text}


@router.post("/tts")
async def text_to_speech(text: str = Form(...)):
    """语音合成：输入文字，返回 WAV 音频"""
    if not text.strip():
        raise HTTPException(status_code=400, detail="文字内容为空")

    audio_bytes = await qwen_service.text_to_speech(text)
    return Response(content=audio_bytes, media_type="audio/wav")
