"""
阿里百炼 DashScope 服务
- 对话+识图: qwen3.5-flash (多模态，速度更快)
- 实时语音识别: 在 main.py 中通过 WebSocket 直接代理到 DashScope
"""

import asyncio
import base64
import os
import uuid
from typing import AsyncGenerator

import httpx
from openai import AsyncOpenAI

from config import settings

_client = AsyncOpenAI(
    api_key=settings.dashscope_api_key,
    base_url=settings.dashscope_base_url,
)

SYSTEM_PROMPT = """당신은 노인을 위해 특별히 설계된 친절한 AI 어시스턴트입니다.
항상 한국어로 답변해 주세요.
답변은 간단하고 명확하게 해주세요. 전문 용어는 피해주세요.
따뜻하고 인내심 있는 어조로 말해주세요.
숫자나 중요한 정보는 천천히 명확하게 설명해 주세요."""


async def chat_stream(
    messages: list[dict],
    session_history: list[dict] | None = None,
    enable_search: bool = True,
    forced_search: bool = False,
) -> AsyncGenerator[str, None]:
    """
    流式对话，使用 qwen3.5-flash 多模态模型。
    enable_search=True: 模型自主判断是否联网搜索（Qwen 原生能力）
    forced_search=True: 强制每句都搜索
    """
    full_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if session_history:
        full_messages.extend(session_history)
    full_messages.extend(messages)

    # Qwen 原生搜索参数，通过 extra_body 传入
    extra = {}
    if enable_search or forced_search:
        extra["enable_search"] = True
        search_options = {"search_strategy": "turbo"}
        if forced_search:
            search_options["forced_search"] = True
        extra["search_options"] = search_options

    stream = await _client.chat.completions.create(
        model=settings.chat_model,
        messages=full_messages,
        stream=True,
        extra_body=extra if extra else None,
    )

    async for chunk in stream:
        content = chunk.choices[0].delta.content
        if content:
            yield content


async def chat(
    messages: list[dict],
    session_history: list[dict] | None = None,
) -> str:
    """非流式对话"""
    result = ""
    async for chunk in chat_stream(messages, session_history):
        result += chunk
    return result


async def vision_chat(
    image_data: bytes,
    question: str = "",
    session_history: list[dict] | None = None,
) -> str:
    """图片识别 + 韩语回复 — qwen3.5-plus 多模态"""
    image_b64 = base64.b64encode(image_data).decode()

    user_content = [
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
        {"type": "text", "text": question if question else "이 이미지에 무엇이 있는지 자세히 설명해 주세요. 노인분도 이해하기 쉽게 쉽게 설명해주세요."},
    ]

    full_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if session_history:
        full_messages.extend(session_history)
    full_messages.append({"role": "user", "content": user_content})

    response = await _client.chat.completions.create(
        model=settings.chat_model,
        messages=full_messages,
    )
    return response.choices[0].message.content


# 降级方案：Paraformer 异步 STT
async def speech_to_text(audio_data: bytes, audio_format: str = "m4a") -> str:
    """韩语语音识别 — Paraformer-v2 异步（降级方案）"""
    audio_dir = "/tmp/ai-assistant-audio"
    os.makedirs(audio_dir, exist_ok=True)

    filename = f"{uuid.uuid4().hex}.{audio_format}"
    file_path = os.path.join(audio_dir, filename)
    with open(file_path, "wb") as f:
        f.write(audio_data)

    public_url = f"{settings.public_base_url}/audio/{filename}"

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription",
                headers={
                    "Authorization": f"Bearer {settings.dashscope_api_key}",
                    "Content-Type": "application/json",
                    "X-DashScope-Async": "enable",
                },
                json={
                    "model": "paraformer-v2",
                    "input": {"file_urls": [public_url]},
                },
            )
            if resp.status_code != 200:
                raise RuntimeError(f"STT 创建失败 {resp.status_code}: {resp.text}")
            task_id = resp.json().get("output", {}).get("task_id")
            if not task_id:
                raise RuntimeError(f"STT 无 task_id: {resp.text}")

            query_url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
            qh = {"Authorization": f"Bearer {settings.dashscope_api_key}"}
            for _ in range(80):
                await asyncio.sleep(0.5)
                q = await client.get(query_url, headers=qh)
                if q.status_code != 200:
                    continue
                qdata = q.json().get("output", {})
                status = qdata.get("task_status")
                if status == "SUCCEEDED":
                    results = qdata.get("results", [])
                    if not results:
                        return ""
                    url = results[0].get("transcription_url")
                    if url:
                        t = await client.get(url)
                        td = t.json()
                        sentences = td.get("transcripts", [{}])[0].get("sentences", [])
                        return "".join(s.get("text", "") for s in sentences)
                    return results[0].get("text", "")
                if status == "FAILED":
                    if qdata.get("code") == "SUCCESS_WITH_NO_VALID_FRAGMENT":
                        return ""
                    raise RuntimeError(f"STT 失败: {qdata}")
            raise RuntimeError("STT 超时")
    finally:
        try:
            os.unlink(file_path)
        except Exception:
            pass
