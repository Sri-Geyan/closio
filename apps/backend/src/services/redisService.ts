import { createClient } from 'redis';
import dotenv from 'dotenv';
dotenv.config();

class RedisService {
  private client;
  private isConnected = false;

  constructor() {
    const redisUrl = process.env.REDIS_URL;
    if (redisUrl) {
      this.client = createClient({
        url: redisUrl
      });
      
      this.client.on('error', (err) => console.log('Redis Client Error', err));
    }
  }

  async connect() {
    if (this.client) {
      try {
        await this.client.connect();
        this.isConnected = true;
        console.log('Connected to Redis Streams producer successfully');
      } catch (error) {
        console.error('Failed to connect to Redis', error);
      }
    } else {
      console.log('REDIS_URL not set, skipping Redis connection');
    }
  }

  async publishStream(streamName: string, message: Record<string, string>) {
    if (!this.isConnected || !this.client) return;
    try {
      // Using XADD for Redis Streams. '*' means auto-generate ID
      await this.client.xAdd(streamName, '*', message);
    } catch (error) {
      console.error(`Error publishing to stream ${streamName}`, error);
    }
  }

  // Domain specific helpers
  async publishLocationUpdate(userId: string, latitude: number, longitude: number) {
    await this.publishStream('location_update', {
      userId,
      latitude: latitude.toString(),
      longitude: longitude.toString(),
      timestamp: new Date().toISOString()
    });
  }

  async publishChatMessage(userId: string, hubId: string, content: string) {
    await this.publishStream('chat_messages', {
      userId,
      hubId,
      content,
      timestamp: new Date().toISOString()
    });
  }

  async publishUserActivity(userId: string, actionType: string, targetId: string) {
    await this.publishStream('user_activity', {
      userId,
      actionType,
      targetId,
      timestamp: new Date().toISOString()
    });
  }
}

export const redisService = new RedisService();
