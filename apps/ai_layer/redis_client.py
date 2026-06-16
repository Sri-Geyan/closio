import json
import redis
from config import Config

class RedisClient:
    def __init__(self):
        if Config.REDIS_URL:
            self.client = redis.Redis.from_url(Config.REDIS_URL, decode_responses=True)
            self.group_name = "closio_ai_group"
            self.consumer_name = "ai_worker_1"
        else:
            self.client = None

    def publish(self, stream_name, value):
        if not self.client:
            return
        try:
            # XADD: We convert value dictionary into string fields as required by Redis Streams
            self.client.xadd(stream_name, {"payload": json.dumps(value)})
        except Exception as e:
            print(f"Error publishing to redis stream: {e}")

    def get(self, key):
        if not self.client:
            return None
        try:
            return self.client.get(key)
        except Exception as e:
            print(f"Error getting from redis: {e}")
            return None

    def setex(self, key, time, value):
        if not self.client:
            return
        try:
            self.client.setex(key, time, value)
        except Exception as e:
            print(f"Error setting in redis: {e}")

    def listen_streams(self, streams, callback):
        """
        Polls from multiple streams and calls callback(stream_name, payload)
        Uses XREADGROUP for persistent tracking or just XREAD for simplicity.
        We'll use XREAD block for simplicity here.
        """
        if not self.client:
            print("No REDIS_URL configured, skipping listen")
            return

        # Setup stream dictionary for xread (start from end '$' initially)
        # Note: If we want to guarantee no message loss, we should use consumer groups.
        # But for MVP, simple XREAD from last id is fine.
        stream_ids = {stream: '$' for stream in streams}
        
        while True:
            try:
                # Block for 1 second waiting for messages
                messages = self.client.xread(stream_ids, block=1000)
                if not messages:
                    continue
                    
                for stream_name, msg_list in messages:
                    for msg_id, msg_data in msg_list:
                        # Update the ID so we only read new messages next time
                        stream_ids[stream_name] = msg_id
                        
                        if 'payload' in msg_data:
                            payload = json.loads(msg_data['payload'])
                            callback(stream_name, payload)
                            
            except Exception as e:
                print(f"Error listening to redis streams: {e}")
                import time
                time.sleep(2) # Backoff

redis_client = RedisClient()
