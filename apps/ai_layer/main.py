import json
import time
import threading
import os
os.environ["USE_TF"] = "0"
os.environ["USE_TORCH"] = "1"
from fastapi import FastAPI
import uvicorn

from config import Config
from redis_client import redis_client

from workers.clustering_worker import process_location_update
from workers.nlp_worker import process_chat_message
from workers.matchmaking_worker import process_user_activity

from workers.summarise_worker import summarise_text
from workers.venue_worker import generate_plan
from workers.sport_worker import optimize_sport_event
from pydantic import BaseModel

app = FastAPI(title="Closio Real-Time AI Layer")

class SummariseRequest(BaseModel):
    text: str

class PlanRequest(BaseModel):
    event_type: str
    group_size: int
    location: dict
    budget: str

class OptimizeSportRequest(BaseModel):
    sport_type: str
    date: str
    lat: float
    lng: float

def handle_stream_message(stream_name, payload):
    if stream_name == Config.STREAM_LOCATION_UPDATE:
        process_location_update(payload)
    elif stream_name == Config.STREAM_CHAT_MESSAGES:
        process_chat_message(payload)
    elif stream_name == Config.STREAM_USER_ACTIVITY:
        process_user_activity(payload)

def consumer_loop():
    print("[AI Layer] Starting Redis Stream Consumer Loop...")
    redis_client.listen_streams([
        Config.STREAM_LOCATION_UPDATE,
        Config.STREAM_CHAT_MESSAGES,
        Config.STREAM_USER_ACTIVITY
    ], handle_stream_message)

@app.on_event("startup")
def startup_event():
    # Start Kafka consumer loop in a background thread
    t = threading.Thread(target=consumer_loop, daemon=True)
    t.start()

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "closio-ai-layer"}

@app.post("/summarise")
def summarise(req: SummariseRequest):
    bullets = summarise_text(req.text)
    return {"summary": bullets}

@app.post("/plan-event")
def plan_event(req: PlanRequest):
    plan = generate_plan(req.event_type, req.group_size, req.location, req.budget)
    return {"plan": plan}

@app.post("/optimize-sport")
def optimize_sport(req: OptimizeSportRequest):
    result = optimize_sport_event(req.sport_type, req.date, req.lat, req.lng)
    return {"optimization": result}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
