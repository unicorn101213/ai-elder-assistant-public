"""
会话管理路由
POST   /sessions          — 创建新会话
GET    /sessions          — 列出会话（按设备隔离）
GET    /sessions/{id}     — 获取会话消息历史
DELETE /sessions/{id}     — 删除会话
"""

from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional

from services import memory_service

router = APIRouter()


class CreateSessionRequest(BaseModel):
    device_id: str = ""


@router.post("")
async def create_session(req: CreateSessionRequest):
    session_id = await memory_service.create_session(device_id=req.device_id)
    return {"session_id": session_id}


@router.get("")
async def list_sessions(device_id: str = Query(default="")):
    sessions = await memory_service.list_sessions(device_id=device_id)
    return {"sessions": sessions}


@router.get("/{session_id}")
async def get_session(session_id: str):
    history = await memory_service.get_session_history(session_id, limit=100)
    return {"session_id": session_id, "messages": history}


@router.delete("/{session_id}")
async def delete_session(session_id: str):
    await memory_service.delete_session(session_id)
    return {"status": "deleted"}
