import asyncio
import json
import logging
import random
import time
import uuid
from math import radians, cos, sin, asin, sqrt

import aiohttp

# Configure Python logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("mesh_sim")

# --- Configuration ---
NUM_NODES = 50
PERCENT_ONLINE = 0.05  # 5% of nodes have internet (uplinks) to force long multi-hop chains
TICK_INTERVAL = 0.5   # faster ticks for smoother animations
COMM_RANGE_KM = 0.2   # reduced range to force long multi-hop chains
BACKEND_URL = "http://localhost:8000/api/reports"

# Tehran Bounding Box (approx central)
LAT_MIN, LAT_MAX = 35.6800, 35.7300
LNG_MIN, LNG_MAX = 51.3600, 51.4200

# Emergency Templates
EMERGENCIES = [
    ("fire", 5, "Building engulfed in flames, need immediate ladder access."),
    ("medical", 4, "Multiple casualties with shrapnel wounds, bleeding control needed."),
    ("structural", 5, "Multi-story residential collapse. Voices heard under rubble."),
    ("hazmat", 4, "Strong smell of gas from ruptured main line."),
    ("medical", 3, "Elderly patient trapped, requires oxygen support."),
    ("structural", 4, "Road completely blocked by debris, clearing equipment needed."),
    ("fire", 4, "Secondary vehicle fire spreading to nearby structure."),
]

def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance between two points on Earth in km."""
    R = 6372.8 # Earth radius in kilometers
    dLat = radians(lat2 - lat1)
    dLon = radians(lon2 - lon1)
    lat1 = radians(lat1)
    lat2 = radians(lat2)
    a = sin(dLat/2)**2 + cos(lat1)*cos(lat2)*sin(dLon/2)**2
    c = 2*asin(sqrt(a))
    return R * c

class MeshNode:
    def __init__(self, node_id, lat, lng, is_online):
        self.node_id = node_id
        self.lat = lat
        self.lng = lng
        self.is_online = is_online
        
        # Packet Store: packet_id -> packet dict
        self.store = {}
        # Track what we've successfully uploaded so we don't spam the server
        self.uploaded = set()

    def receive_packet(self, packet):
        """Returns True if the packet was new to this node."""
        pid = packet["id"]
        if pid not in self.store:
            # Deep copy to maintain isolated hop counts
            new_packet = packet.copy()
            self.store[pid] = new_packet
            return True
        return False

class MeshSimulator:
    def __init__(self):
        self.nodes = []
        # Start at a random location
        lat = random.uniform(LAT_MIN, LAT_MAX)
        lng = random.uniform(LNG_MIN, LNG_MAX)
        
        for i in range(NUM_NODES):
            # Force at least the first node to be an uplink, then 5% chance
            is_online = (i == 0) or (random.random() < PERCENT_ONLINE)
            self.nodes.append(MeshNode(f"node_{i}", lat, lng, is_online))
            
            # Random walk step (100m to 180m) to guarantee chain connectivity and prevent bubbles
            angle = random.uniform(0, 2 * 3.14159)
            dist_km = random.uniform(0.1, 0.18)
            lat += (dist_km * 0.009) * cos(angle)
            lng += (dist_km * 0.009 / cos(radians(lat))) * sin(angle)
            
            # Bounce off bounding box to keep nodes in Tehran
            lat = max(LAT_MIN, min(LAT_MAX, lat))
            lng = max(LNG_MIN, min(LNG_MAX, lng))
            
        self.online_nodes = [n for n in self.nodes if n.is_online]
        logger.info(f"Initialized {NUM_NODES} connected nodes (Random Walk) in Tehran ({len(self.online_nodes)} have uplink).")

    def generate_incident(self):
        """Randomly pick an offline node and generate a new emergency report."""
        offline_nodes = [n for n in self.nodes if not n.is_online]
        if not offline_nodes:
            return
            
        node = random.choice(offline_nodes)
        etype, urg, desc = random.choice(EMERGENCIES)
        
        # Add slight jitter to the incident location compared to the node reporting it
        ilat = node.lat + random.uniform(-0.001, 0.001)
        ilng = node.lng + random.uniform(-0.001, 0.001)
        
        packet_id = str(uuid.uuid4())
        packet = {
            "kind": "report",
            "id": packet_id,
            "ts": int(time.time()),
            "loc": {"lat": ilat, "lng": ilng, "acc": 10},
            "type": etype,
            "urg": urg,
            "haz": [],
            "desc": desc,
            "src": node.node_id,
            "hops": 0,
            "ttl": 15,
            "relay_path": [{"lat": ilat, "lng": ilng, "device": node.node_id}]
        }
        
        node.receive_packet(packet)
        logger.warning(f"🚨 New Incident at [{ilat:.4f}, {ilng:.4f}]: {desc} (from {node.node_id})")

    async def simulate_gossip(self):
        """Simulate one tick of mesh routing."""
        transmissions = 0
        hop_updates = 0
        
        # O(N^2) comparison for simplicity, N=50 is fine
        for node_a in self.nodes:
            if not node_a.store:
                continue
                
            for node_b in self.nodes:
                if node_a == node_b:
                    continue
                    
                dist = haversine(node_a.lat, node_a.lng, node_b.lat, node_b.lng)
                if dist <= COMM_RANGE_KM:
                    # They are in range, node_a sends all its packets to node_b
                    for pid, packet in node_a.store.items():
                        # Only propagate if TTL allows
                        if packet["hops"] < packet["ttl"]:
                            if node_b.receive_packet(packet):
                                # Increment hops *on the receiver's copy*
                                node_b.store[pid]["hops"] += 1
                                # Append node_b's location to the path
                                node_b.store[pid]["relay_path"].append({
                                    "lat": node_b.lat,
                                    "lng": node_b.lng,
                                    "device": node_b.node_id
                                })
                                transmissions += 1
                                hop_updates += 1
                                
        if transmissions > 0:
            logger.info(f"📡 Mesh Tick: {transmissions} packets hopped between peers.")

    async def uplink_data(self, session):
        """Any node can magically connect and push data probablistically or if hops >= 3."""
        total_uploaded = 0
        for node in self.nodes:
            to_upload = []
            for pid, packet in node.store.items():
                if pid not in node.uploaded:
                    # 3-sided die roll, OR forced if hops >= 3
                    if packet["hops"] >= 3 or random.randint(1, 3) == 1:
                        to_upload.append(packet)
            
            if not to_upload:
                continue
                
            payload = {"packets": to_upload}
            try:
                async with session.post(BACKEND_URL, json=payload, timeout=5) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        reps = data.get("inserted_reports", 0)
                        
                        for packet in to_upload:
                            node.uploaded.add(packet["id"])
                            
                        # Only log if the backend actually inserted them (not duplicates)
                        if reps > 0:
                            hop_avg = sum(p["hops"] for p in to_upload) / len(to_upload)
                            logger.info(f"🟢 UPLINK ({node.node_id}): Pushed {len(to_upload)} packets. Backend accepted {reps} new. Avg Hops: {hop_avg:.1f}")
                        total_uploaded += len(to_upload)
            except Exception as e:
                logger.error(f"❌ Uplink failed for {node.node_id}: {str(e)}")

    async def run(self):
        logger.info("Starting Mesh Simulator. Press Ctrl+C to exit.")
        async with aiohttp.ClientSession() as session:
            tick_count = 0
            while True:
                try:
                    # Every 5 ticks (~5 seconds), generate a new incident
                    if tick_count % 5 == 0:
                        self.generate_incident()

                    # Gossip and Uplink
                    await self.simulate_gossip()
                    await self.uplink_data(session)
                    
                    tick_count += 1
                    await asyncio.sleep(TICK_INTERVAL)
                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.exception(f"Error in simulation loop: {e}")
                    await asyncio.sleep(1)

if __name__ == "__main__":
    sim = MeshSimulator()
    try:
        asyncio.run(sim.run())
    except KeyboardInterrupt:
        logger.info("Simulation stopped by user.")
