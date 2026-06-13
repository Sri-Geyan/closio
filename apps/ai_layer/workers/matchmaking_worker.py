import json
from collections import defaultdict
from redis_client import redis_client
from config import Config

# Simple affinity graph: userId -> { targetId: interaction_weight }
affinity_graph = defaultdict(lambda: defaultdict(int))

def process_user_activity(event_data):
    """
    Updates the real-time affinity graph based on user activities (views, joins, messages).
    Publishes smart match recommendations when a threshold is met.
    """
    try:
        user_id = event_data.get('userId')
        action_type = event_data.get('actionType') # e.g. 'join_event', 'view_hub', 'send_message'
        target_id = event_data.get('targetId')
        
        if not user_id or not action_type or not target_id:
            return
            
        # Assign weights based on action type
        weight = 1
        if action_type == 'join_event':
            weight = 5
        elif action_type == 'send_message':
            weight = 3
        elif action_type == 'view_hub':
            weight = 1
            
        affinity_graph[user_id][target_id] += weight
        
        # If the affinity crosses a threshold, trigger a "Smart Match" recommendation
        if affinity_graph[user_id][target_id] >= 10:
            print(f"[Matchmaking] High affinity detected: User {user_id} -> Target {target_id}")
            
            redis_client.publish(
                Config.STREAM_AI_RESULTS,
                {
                    "type": "smart_match",
                    "userId": user_id,
                    "recommendedTargetId": target_id,
                    "score": affinity_graph[user_id][target_id],
                    "reason": "high_interaction"
                }
            )
            
            # Reset slightly so we don't spam
            affinity_graph[user_id][target_id] = 5

    except Exception as e:
        print(f"Error in matchmaking worker: {e}")
