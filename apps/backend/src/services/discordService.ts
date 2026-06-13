import { Client, GatewayIntentBits, ActivityType } from 'discord.js';

class DiscordService {
  public client: Client;

  constructor() {
    this.client = new Client({
      intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildPresences
      ]
    });

    this.client.on('ready', () => {
      console.log(`Discord Bot connected as ${this.client.user?.tag}`);
    });
  }

  public async login(token: string) {
    if (!token) {
      console.warn('No DISCORD_BOT_TOKEN provided. Skipping Discord login.');
      return;
    }
    try {
      await this.client.login(token);
    } catch (error) {
      console.error('Failed to log in to Discord:', error);
    }
  }

  public getUserPresence(userId: string) {
    // We search across all guilds the bot is in
    for (const [_, guild] of this.client.guilds.cache) {
      const member = guild.members.cache.get(userId);
      if (member) {
        let gameName = null;
        let activityStatus = member.presence?.status || 'offline';

        if (member.presence?.activities) {
          const gameActivity = member.presence.activities.find(
            activity => activity.type === ActivityType.Playing
          );
          if (gameActivity) {
            gameName = gameActivity.name;
          }
        }

        return {
          username: member.user.username,
          globalName: member.user.globalName || member.user.displayName,
          avatarUrl: member.user.displayAvatarURL(),
          status: activityStatus,
          gameName: gameName
        };
      }
    }
    return null;
  }
}

export const discordService = new DiscordService();
