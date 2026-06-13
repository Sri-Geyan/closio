import requests
import random
import json
from config import Config
from redis_client import redis_client

def optimize_sport_event(sport_type: str, date: str, lat: float, lng: float):
    cache_key = f"sport:{sport_type}:{date}:{lat}:{lng}"
    cached_sport = redis_client.get(cache_key)
    if cached_sport:
        print("[Sport Worker] Serving sport event from Redis Cache!")
        return json.loads(cached_sport)

    # Free API: Open-Meteo (No API Key required)
    weather_info = {
        "suitability_score": 85,
        "rain_probability": "10%",
        "uv_index": 5,
        "temperature": "24°C",
        "aqi": 42
    }
    
    try:
        # Fetching current weather as a proxy for the date to keep it simple
        res = requests.get(f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,rain,uv_index&hourly=temperature_2m,rain,uv_index")
        if res.status_code == 200:
            data = res.json()
            weather_info["temperature"] = f"{data['current']['temperature_2m']}°C"
            weather_info["uv_index"] = data['current']['uv_index']
            weather_info["rain_probability"] = f"{data['current']['rain']}%"
    except Exception as e:
        print(f"Weather API failed: {e}")

    # Sport specific heuristics
    if sport_type.lower() == "running":
        weather_info["hazards"] = ["High traffic on route B", "Construction on 4th Ave"]
        weather_info["pace_suggestion"] = "6:30 / km"
    elif sport_type.lower() in ["cricket", "football"]:
        weather_info["ground_quality"] = {
            "rating": 4.2,
            "surface_type": "Artificial Turf" if sport_type.lower() == "football" else "Hard pitch",
            "status": "Open"
        }

    hf_key = Config.HUGGINGFACE_API_KEY
    if hf_key:
        print("[Sport Worker] Enriching sport heuristics with HuggingFace Mixtral...")
        try:
            url = "https://api-inference.huggingface.co/models/mistralai/Mixtral-8x7B-Instruct-v0.1"
            headers = {"Authorization": f"Bearer {hf_key}", "Content-Type": "application/json"}
            
            prompt = f"[INST] You are an expert sports coach. Given the sport '{sport_type}' and weather info: {weather_info['temperature']}, UV {weather_info['uv_index']}, Rain {weather_info['rain_probability']}, suggest a suitability score (0-100), a list of 2 short hazards/advice strings, and a pace/intensity suggestion. Return ONLY a valid JSON object with keys: suitability_score (int), hazards (list of strings), suggestion (string). [/INST]"
            
            response = requests.post(url, headers=headers, json={"inputs": prompt, "parameters": {"max_new_tokens": 100, "temperature": 0.3}}, timeout=10)
            
            if response.status_code == 200:
                result_text = response.json()[0]['generated_text'].split('[/INST]')[-1].strip()
                if "```json" in result_text:
                    result_text = result_text.split("```json")[1].split("```")[0].strip()
                elif "```" in result_text:
                    result_text = result_text.split("```")[1].split("```")[0].strip()

                enriched_data = json.loads(result_text)
                
                weather_info["suitability_score"] = enriched_data.get("suitability_score", weather_info["suitability_score"])
                if "hazards" in enriched_data:
                    weather_info["hazards"] = enriched_data["hazards"]
                
                if sport_type.lower() == "running":
                    weather_info["pace_suggestion"] = enriched_data.get("suggestion", weather_info.get("pace_suggestion", "6:30 / km"))
                else:
                    weather_info["ground_quality"]["status"] = enriched_data.get("suggestion", "Open")
                    
        except Exception as e:
            print(f"[Sport Worker] HuggingFace enrichment failed: {e}")

    redis_client.setex(cache_key, 3600, json.dumps(weather_info))
    return weather_info
