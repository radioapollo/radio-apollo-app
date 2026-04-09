/**
 * update_sponsor_images.js
 *
 * This script:
 * 1. Lists all files in the "Sponsors/" folder in Firebase Storage
 * 2. Generates a public download URL for each file
 * 3. Reads all sponsor documents from Firestore
 * 4. Matches each Storage file to a Firestore sponsor by comparing
 *    the filename (without extension, underscores → spaces, lowercased)
 *    to the sponsor document's title (lowercased)
 * 5. Updates matched sponsors with an `imageUrl` field
 *
 * Usage:
 *   node update_sponsor_images.js
 *
 * Requirements:
 *   - serviceAccount.json in the same directory
 *   - npm install firebase-admin (already in your project)
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'radio-apollo-90693.firebasestorage.app',
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Get a public download URL for a Firebase Storage file.
 * Reuses the existing token or creates one if missing.
 */
async function getDownloadUrl(filePath) {
  try {
    const file = bucket.file(filePath);
    const [metadata] = await file.getMetadata();

    let token =
      metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens;
    if (!token) {
      token = require('crypto').randomUUID();
      await file.setMetadata({
        metadata: { firebaseStorageDownloadTokens: token },
      });
    }

    const encodedPath = encodeURIComponent(filePath);
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${token}`;
  } catch (err) {
    console.warn(`  ⚠ Error getting URL for ${filePath}: ${err.message}`);
    return null;
  }
}

/**
 * Normalize a name for fuzzy matching:
 *  - lowercase
 *  - replace underscores with spaces
 *  - remove file extension
 *  - collapse multiple spaces
 *  - trim
 */
function normalize(name) {
  return name
    .replace(/\.[^.]+$/, '')   // remove extension
    .replace(/_/g, ' ')        // underscores → spaces
    .replace(/-/g, ' ')        // dashes → spaces
    .replace(/['']/g, '')      // remove apostrophes
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

// ── Main ────────────────────────────────────────────────────────────────────

async function run() {
  // 1. List all files in Sponsors/ folder
  console.log('Listing files in Storage "Sponsors/" folder...\n');
  const [files] = await bucket.getFiles({ prefix: 'Sponsors/' });

  const imageFiles = files.filter(
    (f) => f.name !== 'Sponsors/' && /\.(png|jpe?g|gif|webp|svg)$/i.test(f.name)
  );

  if (imageFiles.length === 0) {
    console.log('No image files found in Sponsors/ folder.');
    process.exit(0);
  }

  console.log(`Found ${imageFiles.length} image(s):\n`);
  for (const f of imageFiles) {
    console.log(`  • ${f.name}`);
  }

  // 2. Resolve download URLs
  console.log('\nResolving download URLs...\n');
  const storageImages = [];
  for (const file of imageFiles) {
    const url = await getDownloadUrl(file.name);
    const filename = file.name.split('/').pop(); // e.g. "Bistro_Eugeen.png"
    storageImages.push({ filePath: file.name, filename, normalizedName: normalize(filename), url });
    console.log(url ? `  ✓ ${filename}` : `  ✗ ${filename} (no URL)`);
  }

  // 3. Read all sponsor documents from Firestore
  console.log('\nReading Firestore "sponsors" collection...\n');
  const snapshot = await db.collection('sponsors').get();

  if (snapshot.empty) {
    console.log('No sponsors found in Firestore. Nothing to update.');
    process.exit(0);
  }

  const sponsors = [];
  snapshot.forEach((doc) => {
    sponsors.push({ id: doc.id, ...doc.data() });
  });
  console.log(`Found ${sponsors.length} sponsor(s):\n`);
  for (const s of sponsors) {
    console.log(`  • [${s.id}] ${s.title}`);
  }

  // 4. Match and update
  console.log('\n── Matching & Updating ─────────────────────────────\n');

  let matched = 0;
  let unmatched = 0;
  const unmatchedImages = [];

  for (const img of storageImages) {
    if (!img.url) continue;

    // Try to find a matching sponsor
    const match = sponsors.find((s) => {
      const normalizedTitle = normalize(s.title);
      return (
        normalizedTitle === img.normalizedName ||
        img.normalizedName.includes(normalizedTitle) ||
        normalizedTitle.includes(img.normalizedName)
      );
    });

    if (match) {
      await db.collection('sponsors').doc(match.id).update({
        imageUrl: img.url,
      });
      console.log(`  ✓ ${img.filename}  →  "${match.title}" [${match.id}]`);
      matched++;
    } else {
      console.log(`  ✗ ${img.filename}  →  NO MATCH FOUND`);
      unmatchedImages.push(img);
      unmatched++;
    }
  }

  // 5. Summary
  console.log('\n── Summary ────────────────────────────────────────\n');
  console.log(`  ✅ Matched & updated: ${matched}`);
  console.log(`  ❌ Unmatched images:  ${unmatched}`);

  if (unmatchedImages.length > 0) {
    console.log('\n  Unmatched images (you may need to match these manually):');
    for (const img of unmatchedImages) {
      console.log(`    • ${img.filename} (normalized: "${img.normalizedName}")`);
    }
    console.log('\n  Available sponsor titles:');
    for (const s of sponsors) {
      console.log(`    • "${s.title}" (normalized: "${normalize(s.title)}")`);
    }
  }

  console.log('\nDone!');
  process.exit(0);
}

run().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});