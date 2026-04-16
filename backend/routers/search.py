"""
搜索路由
POST /search — 关键词 → 搜索摘要
"""

from fastapi import APIRouter
from pydantic import BaseModel

from services import search_service

router = APIRouter()


class SearchRequest(BaseModel):
    query: str


@router.post("")
async def web_search(req: SearchRequest):
    result = await search_service.search(req.query)
    return {"result": result}
