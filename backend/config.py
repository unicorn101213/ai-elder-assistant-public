from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    dashscope_api_key: str
    dashscope_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    chat_model: str = "qwen3.5-flash"  # 多模态（文本+图片），速度更快
    vision_model: str = "qwen3.5-flash"  # 同上，复用
    tavily_api_key: str = ""  # 备用，当前使用 Qwen 原生搜索
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False
    allowed_origins: str = "*"
    public_base_url: str = "http://你的服务器IP:19000"

    class Config:
        env_file = ".env"


settings = Settings()
