import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

const prisma = new PrismaClient();

// In a real application, this would be a secure master key loaded from KMS or Vault
const MASTER_KEY = process.env.MASTER_ENCRYPTION_KEY || crypto.randomBytes(32).toString('hex');

function generateSymmetricKey() {
  return crypto.randomBytes(32).toString('hex');
}

function encryptKey(key: string, masterKeyHex: string) {
  const iv = crypto.randomBytes(16);
  const masterKey = Buffer.from(masterKeyHex, 'hex');
  const cipher = crypto.createCipheriv('aes-256-gcm', masterKey, iv);
  
  let encrypted = cipher.update(key, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  
  return `${iv.toString('hex')}:${encrypted}:${authTag}`;
}

export async function rotateHubKeys() {
  console.log('Starting Hub Key Rotation Job...');
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  try {
    // Find keys that haven't been rotated in 30 days
    const staleKeys = await prisma.hubEncryptionKey.findMany({
      where: {
        rotatedAt: {
          lte: thirtyDaysAgo
        }
      }
    });

    console.log(`Found ${staleKeys.length} keys needing rotation.`);

    for (const staleKey of staleKeys) {
      const newRawKey = generateSymmetricKey();
      const encryptedKey = encryptKey(newRawKey, MASTER_KEY);

      // Rotate the key
      await prisma.hubEncryptionKey.update({
        where: { id: staleKey.id },
        data: {
          key: encryptedKey,
          rotatedAt: new Date(),
        }
      });

      console.log(`Rotated key for Hub ID: ${staleKey.hubId}`);
      // NOTE: In a full E2E setup, we would re-encrypt recent messages with the new key here,
      // or issue a new key to the clients securely.
    }

    console.log('Hub Key Rotation Job complete.');
  } catch (error) {
    console.error('Error during key rotation:', error);
  } finally {
    await prisma.$disconnect();
  }
}

// If run directly via node
if (require.main === module) {
  rotateHubKeys();
}
