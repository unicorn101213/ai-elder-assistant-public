"""
对话会话记忆管理 (SQLite)
每个会话保存完整的消息历史，支持上下文对话。
"""

import json
import uuid
from datetime import datetime

import aiosqlite
import structlog

logger = structlog.get_logger()

DB_PATH = "elder_assistant.db"


async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                device_id TEXT DEFAULT '',
                title TEXT DEFAULT '새 대화',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
        """)
        # 兼容旧表：如果 device_id 列不存在则添加
        try:
            await db.execute("ALTER TABLE sessions ADD COLUMN device_id TEXT DEFAULT ''")
        except Exception:
            pass
        await db.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                message_type TEXT DEFAULT 'text',
                created_at TEXT NOT NULL,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
        """)
        await db.commit()
    logger.info("数据库初始化完成")


async def create_session(device_id: str = "") -> str:
    session_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO sessions (id, device_id, created_at, updated_at) VALUES (?, ?, ?, ?)",
            (session_id, device_id, now, now),
        )
        await db.commit()
    return session_id


async def get_session_history(session_id: str, limit: int = 20) -> list[dict]:
    """获取最近的对话历史，返回 LLM 所需的 {role, content} 格式"""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute(
            """
            SELECT role, content FROM messages
            WHERE session_id = ?
            ORDER BY created_at ASC
            LIMIT ?
            """,
            (session_id, limit),
        ) as cursor:
            rows = await cursor.fetchall()

    return [{"role": row["role"], "content": row["content"]} for row in rows]


async def save_message(session_id: str, role: str, content: str, message_type: str = "text"):
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO messages (session_id, role, content, message_type, created_at) VALUES (?, ?, ?, ?, ?)",
            (session_id, role, content, message_type, now),
        )
        # 第一条用户消息自动设为会话标题
        if role == "user":
            async with db.execute(
                "SELECT title FROM sessions WHERE id = ?", (session_id,)
            ) as cursor:
                row = await cursor.fetchone()
            if row and row[0] in ("새 대화", "新对话"):
                title = content[:30].replace("[사진을 보냈습니다]", "사진 질문")
                await db.execute(
                    "UPDATE sessions SET title = ?, updated_at = ? WHERE id = ?",
                    (title, now, session_id),
                )
            else:
                await db.execute(
                    "UPDATE sessions SET updated_at = ? WHERE id = ?",
                    (now, session_id),
                )
        else:
            await db.execute(
                "UPDATE sessions SET updated_at = ? WHERE id = ?",
                (now, session_id),
            )
        await db.commit()


async def list_sessions(device_id: str = "") -> list[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        if device_id:
            async with db.execute(
                "SELECT id, title, created_at, updated_at FROM sessions WHERE device_id = ? ORDER BY updated_at DESC LIMIT 50",
                (device_id,),
            ) as cursor:
                rows = await cursor.fetchall()
        else:
            async with db.execute(
                "SELECT id, title, created_at, updated_at FROM sessions ORDER BY updated_at DESC LIMIT 50"
            ) as cursor:
                rows = await cursor.fetchall()
    return [dict(row) for row in rows]


async def delete_session(session_id: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM messages WHERE session_id = ?", (session_id,))
        await db.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
        await db.commit()
