/*
 * migratePropertyVideos.js
 *
 * Migration script to update properties with correct videoIds array.
 *
 * This script queries all property documents in the "properties" collection.
 * For each property, it fetches the videos from the "videos" collection where 
 * video.propertyId matches the property's document ID, and then updates the property 
 * document's videoIds field with the fetched video IDs.
 *
 * Usage:
 *   node migratePropertyVideos.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Using same path as in migrateVideos.js

// Initialize the Firebase Admin SDK using the credentials from the service account key.
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
  // Removed explicit projectId to use project id from serviceAccountKey.json
});

const db = admin.firestore();

async function migratePropertyVideos() {
  try {
    console.log('Starting migration to update properties with correct videoIds...');
    const propertiesSnapshot = await db.collection('properties').get();
    const updatePromises = [];

    for (const propertyDoc of propertiesSnapshot.docs) {
      const propertyId = propertyDoc.id;
      // Query videos with propertyId equal to the current property's ID
      const videosSnapshot = await db.collection('videos')
        .where('propertyId', '==', propertyId)
        .get();
      
      const videoIds = videosSnapshot.docs.map(doc => doc.id);
      console.log(`Property ${propertyId} will be updated with ${videoIds.length} video(s).`);
      
      // Update the property document's videoIds field
      const updatePromise = db.collection('properties').doc(propertyId).update({
        videoIds: videoIds
      });
      
      updatePromises.push(updatePromise);
    }

    // Wait for all update operations to finish
    await Promise.all(updatePromises);
    console.log('Migration complete. All properties have been updated with correct videoIds.');
  } catch (err) {
    console.error('Error during migration:', err);
    process.exit(1);
  }
}

migratePropertyVideos(); 