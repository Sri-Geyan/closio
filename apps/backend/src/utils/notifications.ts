import { PrismaClient } from '@prisma/client';
import { getMessaging } from 'firebase-admin/messaging';

const prisma = new PrismaClient();

export async function sendHubNotification(hubId: string, senderId: string, title: string, body: string) {
  try {
    // Get all members of the hub except the sender
    const hubMembers = await prisma.hubMember.findMany({
      where: { hubId, userId: { not: senderId } },
      include: { user: true }
    });

    const tokens = hubMembers
      .map(m => m.user.fcmToken)
      .filter((token): token is string => token !== null && token !== undefined && token.trim() !== '');

    if (tokens.length === 0) return;

    // Send notifications via Firebase Admin
    const message = {
      notification: { title, body },
      tokens,
    };

    const response = await getMessaging().sendEachForMulticast(message);
    console.log(`Successfully sent ${response.successCount} messages; Failed ${response.failureCount}`);
  } catch (error) {
    console.error('Error sending push notifications:', error);
  }
}
