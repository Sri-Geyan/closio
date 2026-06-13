import { PrismaClient, Event } from '@prisma/client';

const prisma = new PrismaClient();

export interface ActionLink {
  type: string;
  title: string;
  subtitle: string;
  icon: string;
  url: string;
  internal: boolean;
}

// Deep Link Catalog
const CATALOG: ActionLink[] = [
  { type: 'Google Maps', title: 'Google Maps', subtitle: 'Directions', icon: 'map', url: 'https://maps.google.com/?q=', internal: false },
  { type: 'Apple Maps', title: 'Apple Maps', subtitle: 'Directions', icon: 'map', url: 'http://maps.apple.com/?q=', internal: false },
  { type: 'Uber', title: 'Uber', subtitle: 'Book a ride', icon: 'directions_car', url: 'uber://?action=setPickup', internal: false },
  { type: 'Zomato', title: 'Zomato', subtitle: 'Book table / Order', icon: 'restaurant', url: 'zomato://', internal: false },
  { type: 'BookMyShow', title: 'BookMyShow', subtitle: 'Movies & Events', icon: 'movie', url: 'bookmyshow://', internal: false },
  { type: 'Strava', title: 'Strava', subtitle: 'Log run', icon: 'directions_run', url: 'strava://', internal: false },
  { type: 'Closio Recap', title: 'Closio Recap', subtitle: 'Sport logging', icon: 'fitness_center', url: '/recap', internal: true },
  { type: 'Split', title: 'Split', subtitle: 'Share costs', icon: 'receipt_long', url: '/split', internal: true },
  { type: 'Weather', title: 'Weather', subtitle: 'Check forecast', icon: 'cloud', url: '/weather', internal: true },
  { type: 'Spotify', title: 'Spotify', subtitle: 'Jukebox', icon: 'music_note', url: 'spotify://', internal: false },
];

export class DeepLinkOrchestrator {
  /**
   * Ranks deep links based on Event Type, Time, Location, and Hub Behavior.
   * Score = (EventTypeWeight * 0.40) + (LocationWeight * 0.20) + (TimeWeight * 0.20) + (GroupBehaviorWeight * 0.20)
   */
  static async getRankedLinks(event: Event): Promise<ActionLink[]> {
    // 1. Fetch Hub's past behavior
    const interactions = await prisma.deepLinkInteraction.findMany({
      where: { hubId: event.hubId }
    });

    const totalTaps = interactions.reduce((sum, i) => sum + i.taps, 0);
    const tapFrequencies: Record<string, number> = {};
    interactions.forEach(i => {
      tapFrequencies[i.linkType] = totalTaps > 0 ? (i.taps / totalTaps) : 0;
    });

    // 2. Score each link in the catalog
    const scoredLinks = CATALOG.map(link => {
      let eventTypeScore = 0;
      let locationScore = 0;
      let timeScore = 0;
      let groupBehaviorScore = tapFrequencies[link.type] || 0;

      // Event Type logic (40% weight)
      if (event.type === 'Food') {
        if (link.type === 'Zomato') eventTypeScore = 1.0;
        if (link.type === 'Split') eventTypeScore = 0.8;
      } else if (event.type === 'Movie') {
        if (link.type === 'BookMyShow') eventTypeScore = 1.0;
        if (link.type === 'Split') eventTypeScore = 0.8;
      } else if (event.type === 'Sport' || event.type === 'Running') {
        if (link.type === 'Strava') eventTypeScore = 1.0;
        if (link.type === 'Closio Recap') eventTypeScore = 1.0;
        if (link.type === 'Weather') eventTypeScore = 0.8;
      } else if (event.type === 'Hangout') {
        if (link.type === 'Spotify') eventTypeScore = 0.8;
        if (link.type === 'Split') eventTypeScore = 0.5;
      }

      // Default high score for navigation/transport if location exists
      if (event.location && event.location.trim().length > 0) {
        if (link.type === 'Uber') locationScore = 1.0;
        if (link.type === 'Google Maps' || link.type === 'Apple Maps') locationScore = 1.0;
      }

      // Time logic (20% weight)
      // e.g., Weather matters more for upcoming events
      try {
        const eventDate = new Date(event.date);
        const now = new Date();
        const diffDays = (eventDate.getTime() - now.getTime()) / (1000 * 3600 * 24);
        
        if (diffDays >= 0 && diffDays <= 3) {
           if (link.type === 'Weather') timeScore = 1.0;
           if (link.type === 'Uber') timeScore = 0.8;
        }
      } catch (e) {
        // Ignore date parsing errors
      }

      // Cold start handling: If total taps < 5, rely more on event type defaults
      const effectiveGroupBehaviorScore = totalTaps < 5 ? eventTypeScore : groupBehaviorScore;

      const totalScore = 
        (eventTypeScore * 0.40) + 
        (locationScore * 0.20) + 
        (timeScore * 0.20) + 
        (effectiveGroupBehaviorScore * 0.20);

      // Customize the URL or subtitle based on event context
      const contextualLink = { ...link };
      if (link.type === 'Google Maps' && event.location) {
        contextualLink.url = `https://maps.google.com/?q=${encodeURIComponent(event.location)}`;
      }

      return { link: contextualLink, score: totalScore };
    });

    // 3. Sort by score descending and return top 4
    scoredLinks.sort((a, b) => b.score - a.score);
    
    // Filter out links with score 0 (irrelevant links)
    const topLinks = scoredLinks.filter(sl => sl.score > 0).slice(0, 4);

    return topLinks.map(sl => sl.link);
  }

  /**
   * Record a deep link tap for a hub to update the orchestration weights.
   */
  static async recordTap(hubId: string, linkType: string) {
    await prisma.deepLinkInteraction.upsert({
      where: {
        hubId_linkType: {
          hubId,
          linkType
        }
      },
      update: { taps: { increment: 1 } },
      create: { hubId, linkType, taps: 1 }
    });
  }
}
