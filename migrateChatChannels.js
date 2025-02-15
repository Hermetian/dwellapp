const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateChatChannels() {
  console.log('🔄 Starting chat channels migration...');
  
  try {
    const snapshot = await db.collection('chatChannels').get();
    const batch = db.batch();
    let updateCount = 0;
    let batchCount = 0;
    
    for (const doc of snapshot.docs) {
      const channel = doc.data();
      
      // Update the document with new fields
      batch.update(doc.ref, {
        lastSenderId: channel.sellerId, // Set lastSenderId to sellerId
        isRead: true // Set initial read state to true
      });
      
      updateCount++;
      batchCount++;
      
      // Commit batch every 500 documents (Firestore limit)
      if (batchCount >= 500) {
        console.log(`💾 Committing batch of ${batchCount} updates...`);
        await batch.commit();
        batchCount = 0;
      }
    }
    
    // Commit any remaining updates
    if (batchCount > 0) {
      console.log(`💾 Committing final batch of ${batchCount} updates...`);
      await batch.commit();
    }
    
    console.log(`✅ Migration complete! Updated ${updateCount} chat channels.`);
    
  } catch (error) {
    console.error('❌ Error during migration:', error);
  } finally {
    process.exit();
  }
}

migrateChatChannels(); 