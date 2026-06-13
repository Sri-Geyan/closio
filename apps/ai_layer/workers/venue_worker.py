import random
import os
import requests

def get_venue_shortlist(event_type: str, location: dict, budget: str):
    # Retrieve the Google Maps API Key from the environment
    api_key = os.getenv("GOOGLE_MAPS_API_KEY")
    
    if not api_key:
        # Fallback to mock data if API key is not configured
        venues = {
            "Food": [
                {"name": "The Spice Route", "type": "Indian", "distance": "2.1 km", "price": "₹₹", "rating": 4.5, "cost_estimate": "₹800", "deep_link": "zomato://search?keyword=The+Spice+Route"},
                {"name": "Mama Mia Pizza", "type": "Italian", "distance": "3.4 km", "price": "₹₹₹", "rating": 4.2, "cost_estimate": "₹1200", "deep_link": "zomato://search?keyword=Mama+Mia+Pizza"},
                {"name": "Local Bistro", "type": "Cafe", "distance": "1.0 km", "price": "₹", "rating": 4.7, "cost_estimate": "₹400", "deep_link": "zomato://search?keyword=Local+Bistro"}
            ],
            "Sport": [
                {"name": "Greenfield Turf", "type": "Outdoor Turf", "distance": "4.5 km", "price": "₹₹", "rating": 4.6, "cost_estimate": "₹300", "deep_link": "comgooglemaps://?q=Greenfield+Turf"},
                {"name": "Downtown Sports Club", "type": "Indoor Court", "distance": "5.2 km", "price": "₹₹₹", "rating": 4.8, "cost_estimate": "₹500", "deep_link": "comgooglemaps://?q=Downtown+Sports+Club"}
            ],
            "Movie": [
                {"name": "PVR Cinemas, Mall", "type": "Multiplex", "distance": "6.0 km", "price": "₹₹", "rating": 4.3, "cost_estimate": "₹450", "deep_link": "bookmyshow://"}
            ]
        }
        return venues.get(event_type, venues["Food"])

    # Map generic event types to Google Places search queries
    query = f"{event_type} venues near me"
    if event_type == "Food":
        query = "restaurants near me"
    elif event_type == "Sport":
        query = "sports turf court near me"
    elif event_type == "Movie":
        query = "movie theaters near me"

    # In a real app we'd use the provided location (lat, lng), but we'll use text search here
    # or nearby search if we extract lat/lng from location dict.
    lat = location.get('lat') if isinstance(location, dict) else None
    lng = location.get('lng') if isinstance(location, dict) else None
    
    url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
    params = {
        "query": query,
        "key": api_key,
    }
    
    if lat and lng:
        params["location"] = f"{lat},{lng}"
        params["radius"] = "5000"

    try:
        response = requests.get(url, params=params, timeout=5)
        if response.status_code == 200:
            results = response.json().get('results', [])
            shortlist = []
            for place in results[:3]:
                name = place.get('name', 'Venue')
                rating = place.get('rating', 4.0)
                price_level = place.get('price_level', 2)
                price_str = "₹" * price_level if price_level > 0 else "₹₹"
                cost_est = price_level * 400 if price_level > 0 else 800
                
                shortlist.append({
                    "name": name,
                    "type": event_type,
                    "distance": "Near you",  # Calculating true distance requires distance matrix API
                    "price": price_str,
                    "rating": rating,
                    "cost_estimate": f"₹{cost_est}",
                    "deep_link": f"comgooglemaps://?q={name.replace(' ', '+')}"
                })
            
            if shortlist:
                return shortlist
    except Exception as e:
        print(f"Error calling Google Places API: {e}")

    # Fallback to empty if it fails completely
    return [{"name": f"Mock {event_type} Venue", "type": event_type, "distance": "N/A", "price": "₹₹", "rating": 4.0, "cost_estimate": "₹500", "deep_link": ""}]

import json
from config import Config
from redis_client import redis_client

def generate_plan(event_type: str, group_size: int, location: dict, budget: str):
    # Try cache first
    cache_key = f"plan:{event_type}:{group_size}:{location.get('lat')}:{location.get('lng')}:{budget}"
    cached_plan = redis_client.get(cache_key)
    if cached_plan:
        print("[Venue Worker] Serving plan from Redis Cache!")
        return json.loads(cached_plan)

    shortlist = get_venue_shortlist(event_type, location, budget)
    
    try:
        cost_str = str(shortlist[0].get("cost_estimate", "₹500")).replace('₹', '').replace(',', '').strip()
        base_cost = int(cost_str)
    except:
        base_cost = 500
        
    total_cost = base_cost * group_size

    plan = {
        "venues": shortlist,
        "suggested_timing": "7:00 PM - 9:00 PM",
        "transport": {"option": "UberXL" if group_size > 4 else "UberGo", "estimate": f"₹{random.randint(150, 400)}", "deep_link": "uber://?action=setPickup&pickup=my_location"},
        "split_estimate": {"total": f"₹{total_cost}", "per_person": f"₹{total_cost // group_size}"},
        "playlist_mood": "Chill" if event_type == "Food" else "Hype"
    }

    # Use HuggingFace to enrich the plan if API key is present
    hf_key = Config.HUGGINGFACE_API_KEY
    if hf_key:
        print("[Venue Worker] Enriching plan with HuggingFace Mixtral...")
        try:
            url = "https://api-inference.huggingface.co/models/mistralai/Mixtral-8x7B-Instruct-v0.1"
            headers = {"Authorization": f"Bearer {hf_key}", "Content-Type": "application/json"}
            
            prompt = f"[INST] You are an expert event planner. Given an event of type '{event_type}' for {group_size} people, with venues like '{shortlist[0]['name']}', suggest a concise timing, transport option name (e.g. UberXL), transport cost estimate in INR, and a 1-word playlist mood. Return ONLY a valid JSON object with keys: suggested_timing, transport_option, transport_estimate, playlist_mood. [/INST]"
            
            response = requests.post(url, headers=headers, json={"inputs": prompt, "parameters": {"max_new_tokens": 100, "temperature": 0.3}}, timeout=10)
            
            if response.status_code == 200:
                result_text = response.json()[0]['generated_text'].split('[/INST]')[-1].strip()
                # Extremely naive json parsing just in case it added markdown blocks
                if "```json" in result_text:
                    result_text = result_text.split("```json")[1].split("```")[0].strip()
                elif "```" in result_text:
                    result_text = result_text.split("```")[1].split("```")[0].strip()

                enriched_data = json.loads(result_text)
                
                plan["suggested_timing"] = enriched_data.get("suggested_timing", plan["suggested_timing"])
                plan["transport"]["option"] = enriched_data.get("transport_option", plan["transport"]["option"])
                plan["transport"]["estimate"] = enriched_data.get("transport_estimate", plan["transport"]["estimate"])
                plan["playlist_mood"] = enriched_data.get("playlist_mood", plan["playlist_mood"])
        except Exception as e:
            print(f"[Venue Worker] HuggingFace enrichment failed: {e}")

    # Cache for 1 hour to ensure speed on repeat requests
    redis_client.setex(cache_key, 3600, json.dumps(plan))
    
    return plan
