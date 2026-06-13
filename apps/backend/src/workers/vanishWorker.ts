import cron from 'node-cron';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export function startVanishWorker() {
  console.log('Starting Vanish Mode worker...');

  // Run every minute
  cron.schedule('* * * * *', async () => {
    try {
      // Postgres raw query to delete messages where vanishTtl has expired
      const deleted = await prisma.$executeRaw`
        DELETE FROM "Message"
        WHERE "vanishTtl" IS NOT NULL
        AND "createdAt" + ("vanishTtl" * interval '1 second') < NOW()
      `;

      if (deleted > 0) {
        console.log(`[VanishWorker] Permanently deleted ${deleted} expired messages.`);
      }
    } catch (error) {
      console.error('[VanishWorker] Error deleting expired messages:', error);
    }
  });
}
