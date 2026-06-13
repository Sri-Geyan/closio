import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    REDIS_URL = os.getenv("REDIS_URL")
    HUGGINGFACE_API_KEY = os.getenv("HUGGINGFACE_API_KEY")

    # Stream/Topic names
    STREAM_LOCATION_UPDATE = "location_update"
    STREAM_CHAT_MESSAGES = "chat_messages"
    STREAM_USER_ACTIVITY = "user_activity"
    STREAM_AI_RESULTS = "ai_results"
