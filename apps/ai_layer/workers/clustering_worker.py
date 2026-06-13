import json
import numpy as np
from sklearn.cluster import DBSCAN
from redis_client import redis_client
from config import Config

# In-memory store for recent locations. In production, this should be Redis or similar.
recent_locations = {}

def process_location_update(event_data):
    """
    Processes a location update, runs DBSCAN clustering, and if clusters form, 
    identifies them as 'Discovery Nodes' and publishes the result.
    """
    try:
        user_id = event_data.get('userId')
        lat = event_data.get('latitude')
        lng = event_data.get('longitude')
        
        if not user_id or lat is None or lng is None:
            return
            
        recent_locations[user_id] = [lat, lng]
        
        # Only run clustering if we have enough points to form a cluster
        if len(recent_locations) >= 3:
            coords = np.array(list(recent_locations.values()))
            user_ids = list(recent_locations.keys())
            
            # DBSCAN parameters: epsilon (distance in degrees roughly), min_samples
            # 0.01 degrees is roughly 1km
            db = DBSCAN(eps=0.01, min_samples=3).fit(coords)
            labels = db.labels_
            
            n_clusters = len(set(labels)) - (1 if -1 in labels else 0)
            
            clusters = {}
            for idx, label in enumerate(labels):
                if label != -1: # -1 is noise
                    if label not in clusters:
                        clusters[label] = []
                    clusters[label].append(user_ids[idx])
            
            # Publish active discovery nodes back to Kafka or a DB
            if len(clusters) > 0:
                discovery_nodes = []
                for label, uids in clusters.items():
                    cluster_coords = coords[labels == label]
                    center = np.mean(cluster_coords, axis=0)
                    discovery_nodes.append({
                        "nodeId": f"node_{label}",
                        "centerLat": float(center[0]),
                        "centerLng": float(center[1]),
                        "userCount": len(uids)
                    })
                    
                print(f"[Clustering] Found {len(discovery_nodes)} discovery nodes")
                
                redis_client.publish(
                    Config.STREAM_AI_RESULTS,
                    {
                        "type": "discovery_nodes",
                        "data": discovery_nodes
                    }
                )
    except Exception as e:
        print(f"Error in clustering worker: {e}")
