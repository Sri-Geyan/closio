import json
import requests
from redis_client import redis_client
from config import Config

# We no longer initialize heavy local models!
print("[NLP Worker] Booting up... Using HuggingFace API instead of local models.")

hub_message_buffer = {}

def process_chat_message(event_data):
    """
    1. Moderates incoming chat messages using HuggingFace toxic-bert.
    2. Buffers messages and generates summaries using HuggingFace bart-large-cnn.
    """
    try:
        user_id = event_data.get('userId')
        hub_id = event_data.get('hubId')
        text = event_data.get('content')
        
        if not text or not hub_id:
            return

        hf_key = Config.HUGGINGFACE_API_KEY
        headers = {"Authorization": f"Bearer {hf_key}", "Content-Type": "application/json"} if hf_key else None

        # 1. Moderation (Toxicity Check via HF API)
        if hf_key:
            try:
                mod_url = "https://api-inference.huggingface.co/models/unitary/toxic-bert"
                res = requests.post(mod_url, headers=headers, json={"inputs": text[:512]}, timeout=3)
                if res.status_code == 200:
                    results = res.json()
                    if isinstance(results, list) and len(results) > 0 and isinstance(results[0], list):
                        # Find toxic score
                        toxic_score = next((item['score'] for item in results[0] if item['label'] == 'toxic'), 0)
                        if toxic_score > 0.8:
                            print(f"[NLP Worker] Moderation alert: toxic message detected from {user_id}")
                            redis_client.publish(
                                Config.STREAM_AI_RESULTS,
                                json.dumps({
                                    "type": "moderation_alert",
                                    "userId": user_id,
                                    "hubId": hub_id,
                                    "reason": "high_toxicity"
                                })
                            )
            except Exception as e:
                print(f"[NLP Worker] Moderation API failed: {e}")
        
        # 2. Summarization buffering
        if hub_id not in hub_message_buffer:
            hub_message_buffer[hub_id] = []
            
        hub_message_buffer[hub_id].append(text)
        
        # If we reach 20 messages, summarize them via HF API and clear buffer
        if len(hub_message_buffer[hub_id]) >= 20 and hf_key:
            combined_text = " ".join(hub_message_buffer[hub_id])
            
            if len(combined_text.split()) > 50:
                print(f"[NLP Worker] Generating summary for hub {hub_id} via HuggingFace...")
                try:
                    sum_url = "https://api-inference.huggingface.co/models/facebook/bart-large-cnn"
                    sum_res = requests.post(sum_url, headers=headers, json={"inputs": combined_text[:1024]}, timeout=10)
                    
                    if sum_res.status_code == 200:
                        summary_data = sum_res.json()
                        if isinstance(summary_data, list) and len(summary_data) > 0:
                            summary_text = summary_data[0].get('summary_text')
                            if summary_text:
                                redis_client.publish(
                                    Config.STREAM_AI_RESULTS,
                                    json.dumps({
                                        "type": "hub_summary",
                                        "hubId": hub_id,
                                        "summary": summary_text
                                    })
                                )
                except Exception as e:
                    print(f"[NLP Worker] Summarization API failed: {e}")
            
            # Clear buffer
            hub_message_buffer[hub_id] = []
            
    except Exception as e:
        print(f"Error in NLP worker: {e}")
