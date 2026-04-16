"""
Tavily 网络搜索服务
"""

import structlog
from tavily import TavilyClient

from config import settings

logger = structlog.get_logger()

_client = None


def get_client() -> TavilyClient:
    global _client
    if _client is None:
        _client = TavilyClient(api_key=settings.tavily_api_key)
    return _client


async def search(query: str, max_results: int = 5) -> str:
    """
    执行网络搜索，返回摘要文本
    结果会被注入到 LLM 对话中生成韩语回复
    """
    client = get_client()
    try:
        result = client.search(
            query=query,
            search_depth="basic",
            max_results=max_results,
            include_answer=True,
        )

        # 优先使用 Tavily 的聚合答案
        if result.get("answer"):
            return result["answer"]

        # 否则拼接搜索结果摘要
        snippets = []
        for item in result.get("results", []):
            title = item.get("title", "")
            content = item.get("content", "")[:300]
            snippets.append(f"{title}: {content}")

        return "\n".join(snippets) if snippets else "검색 결과를 찾을 수 없습니다."

    except Exception as e:
        logger.error("tavily search error", error=str(e))
        raise RuntimeError(f"搜索失败: {e}")
