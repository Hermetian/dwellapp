const admin = require("firebase-admin");
// Path to your service account key file
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();
async function migrateVideos() {
const videosRef = db.collection("videos");
const snapshot = await videosRef.get();
// Start a batch write for efficiency.
const batch = db.batch();
let updatedCount = 0;
snapshot.docs.forEach(function(doc) {
    const data = doc.data();
    const updateData = {};
    // If the document doesn't have a likeCount field, set it to 0.
    if (data.likeCount === undefined) {
    updateData.likeCount = 0;
    }
    // If the document doesn't have a likedBy field, set it to an empty array.
    if (data.likedBy === undefined) {
    updateData.likedBy = [];
    }
    // If there are updates to be made, add it to the batch.
    if (Object.keys(updateData).length > 0) {
    batch.update(doc.ref, updateData);
    updatedCount++;
    }
    });
    if (updatedCount > 0) {
    await batch.commit();
    console.log("Migration complete. Updated " + updatedCount + " video documents.");
    } else {
    console.log("Migration complete. All video documents were already up to date.");
    }
}

migrateVideos()
.then(() => process.exit(0))
.catch(function(error) {
console.error("Migration failed:", error);
process.exit(1);
});