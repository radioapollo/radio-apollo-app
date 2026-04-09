const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'radio-apollo-90693.firebasestorage.app',
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

const programs = [
  // MAANDAG
  { day: 'Maandag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '', imagePath: 'Programmas/maandag/1 De Ochtendkroeg.png' },
  { day: 'Maandag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '', imagePath: 'Programmas/maandag/2 Plaatjes zonder praatjes.png' },
  { day: 'Maandag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Jo', special: '', imagePath: 'Programmas/maandag/3. De Muziekfabriek.jpeg' },
  { day: 'Maandag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '', imagePath: 'Programmas/maandag/4 Weer-of-geen-weer.jpg' },
  { day: 'Maandag', startTime: '12:00', endTime: '14:00', title: 'Werken met muziek', presenter: 'Harry van Lint', special: '', imagePath: 'Programmas/maandag/5 Werken met muziek.jpg' },
  { day: 'Maandag', startTime: '14:00', endTime: '16:00', title: 'Muziekmozaiek', presenter: 'Peter Hoffman', special: '', imagePath: 'Programmas/maandag/6 Muziekmozaiek.png' },
  { day: 'Maandag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '', imagePath: 'Programmas/maandag/7 Muziekland.jpg' },
  { day: 'Maandag', startTime: '17:00', endTime: '18:00', title: 'De Hitmolen', presenter: 'Marco de Bruyn', special: '', imagePath: 'Programmas/maandag/8 De Hitmolen.png' },
  { day: 'Maandag', startTime: '18:00', endTime: '20:00', title: 'De Platenkast', presenter: 'Luc van Turnhout', special: '', imagePath: 'Programmas/maandag/9 De Platenkast.png' },
  { day: 'Maandag', startTime: '20:00', endTime: '22:00', title: 'Hitarchief', presenter: 'Ronny v.d. Broeck', special: '', imagePath: 'Programmas/maandag/10 Hitarchief.jpeg' },
  { day: 'Maandag', startTime: '22:00', endTime: '24:00', title: '80 is prachtig', presenter: '', special: '', imagePath: "Programmas/maandag/11 80's.jpg" },
  { day: 'Maandag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },

  // DINSDAG
  { day: 'Dinsdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '', imagePath: 'Programmas/dinsdag/1 De Ochtendkroeg.jpeg' },
  { day: 'Dinsdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '', imagePath: 'Programmas/dinsdag/2 Plaatjes zonder praatjes.jpeg' },
  { day: 'Dinsdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Gert van Eeden', special: '', imagePath: 'Programmas/dinsdag/3 De Muziekfabriek.jpg' },
  { day: 'Dinsdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '', imagePath: 'Programmas/dinsdag/4 Weer-of-geen-weer.jpg' },
  { day: 'Dinsdag', startTime: '12:00', endTime: '14:00', title: 'Door de jaren heen', presenter: 'Remi Beelaert', special: '', imagePath: 'Programmas/dinsdag/5 Door de jaren heen.jpeg' },
  { day: 'Dinsdag', startTime: '14:00', endTime: '15:00', title: 'Nooit vervelende hits', presenter: 'Bart Mottart', special: '', imagePath: 'Programmas/dinsdag/6 Nooit vervelende hits.jpeg' },
  { day: 'Dinsdag', startTime: '15:00', endTime: '16:00', title: 'Verhoeven op de radio', presenter: '', special: '', imagePath: 'Programmas/dinsdag/7 Verhoeven op de radio.jpeg' },
  { day: 'Dinsdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '', imagePath: 'Programmas/dinsdag/8 Muziekland.jpg' },
  { day: 'Dinsdag', startTime: '17:00', endTime: '18:00', title: 'Belpop', presenter: 'Johan Dhondt', special: '', imagePath: 'Programmas/dinsdag/9 Belpop.jpeg' },
  { day: 'Dinsdag', startTime: '18:00', endTime: '20:00', title: 'Thematoppers', presenter: 'Moniek & Alain', special: '', imagePath: 'Programmas/dinsdag/10 Uw Thema Toppers.jpg' },
  { day: 'Dinsdag', startTime: '20:00', endTime: '22:00', title: 'Generation X', presenter: 'Wim Verwerft', special: '', imagePath: 'Programmas/dinsdag/11 Generation X.jpeg' },
  { day: 'Dinsdag', startTime: '22:00', endTime: '24:00', title: "70's are besties", presenter: '', special: '', imagePath: "Programmas/dinsdag/12 70's.jpg" },
  { day: 'Dinsdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },

  // WOENSDAG
  { day: 'Woensdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '', imagePath: 'Programmas/woensdag/1 De Ochtendkroeg.jpeg' },
  { day: 'Woensdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '', imagePath: 'Programmas/woensdag/2 Plaatjes zonder praatjes.jpeg' },
  { day: 'Woensdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Roger Van Dosselaer', special: '', imagePath: 'Programmas/woensdag/3. De Muziekfabriek.jpg' },
  { day: 'Woensdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '', imagePath: 'Programmas/woensdag/4 Weer-of-geen-weer.jpg' },
  { day: 'Woensdag', startTime: '12:00', endTime: '14:00', title: 'Vrienden van de radio', presenter: 'Hans van Dam', special: '', imagePath: '' },
  { day: 'Woensdag', startTime: '14:00', endTime: '16:00', title: '98% Vinyl', presenter: 'Piet de Schrijver', special: '', imagePath: '' },
  { day: 'Woensdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '', imagePath: 'Programmas/woensdag/8 Muziekland.jpg' },
  { day: 'Woensdag', startTime: '17:00', endTime: '18:00', title: 'Radiorama', presenter: 'Benny de Wit', special: '', imagePath: 'Programmas/woensdag/9 Radio Rama.jpeg' },
  { day: 'Woensdag', startTime: '18:00', endTime: '20:00', title: 'Dubbel Genot', presenter: 'Ben en Sven', special: '', imagePath: 'Programmas/woensdag/10 Dubbel genof.jpg' },
  { day: 'Woensdag', startTime: '20:00', endTime: '22:00', title: 'Electric Café Patje Fox', presenter: 'De Catacomben Steph', special: '', imagePath: 'Programmas/woensdag/11 Catacomben.jpg' },
  { day: 'Woensdag', startTime: '20:00', endTime: '22:00', title: 'Electric Café Patje Fox', presenter: 'De Catacomben Steph', special: 'last_wednesday_of_month', imagePath: 'Programmas/woensdag/11 Fox and Sounds.jpeg' },
  { day: 'Woensdag', startTime: '22:00', endTime: '24:00', title: "90's", presenter: '', special: '', imagePath: "Programmas/woensdag/12 90's.jpg" },
  { day: 'Woensdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },

  // DONDERDAG
  { day: 'Donderdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '', imagePath: 'Programmas/donderdag/1 De Ochtendkroeg.jpeg' },
  { day: 'Donderdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '', imagePath: 'Programmas/donderdag/2 Plaatjes zonder praatjes.jpeg' },
  { day: 'Donderdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Roger Van Dosselaer', special: '', imagePath: 'Programmas/donderdag/3. De Muziekfabriek.jpg' },
  { day: 'Donderdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '', imagePath: 'Programmas/donderdag/4 Weer-of-geen-weer.jpg' },
  { day: 'Donderdag', startTime: '12:00', endTime: '14:00', title: 'Patsie Time', presenter: 'Patsie', special: '', imagePath: 'Programmas/donderdag/5 Patsie Time.jpeg' },
  { day: 'Donderdag', startTime: '14:00', endTime: '16:00', title: 'Jukebox', presenter: 'Pieter', special: '', imagePath: '' },
  { day: 'Donderdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '', imagePath: 'Programmas/donderdag/7 Muziekland.jpg' },
  { day: 'Donderdag', startTime: '17:00', endTime: '18:00', title: 'Radiorama', presenter: 'Benny de Wit', special: '', imagePath: 'Programmas/donderdag/8 Radio Rama.jpeg' },
  { day: 'Donderdag', startTime: '18:00', endTime: '20:00', title: "Nipper's Greatest Hits", presenter: 'Jempie Vanhorenbeek', special: '', imagePath: "Programmas/donderdag/9 Nipper's Greatest Hits.jpeg" },
  { day: 'Donderdag', startTime: '20:00', endTime: '22:00', title: 'Country Club', presenter: 'Peter Briers en Serge', special: '', imagePath: 'Programmas/donderdag/10 Country Club.jpeg' },
  { day: 'Donderdag', startTime: '22:00', endTime: '24:00', title: "70's are besties", presenter: '', special: '', imagePath: "Programmas/donderdag/11 70's.jpg" },
  { day: 'Donderdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },

  // VRIJDAG
  { day: 'Vrijdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '', imagePath: 'Programmas/vrijdag/1 De Ochtendkroeg.jpeg' },
  { day: 'Vrijdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '', imagePath: 'Programmas/vrijdag/2 Plaatjes zonder praatjes.jpeg' },
  { day: 'Vrijdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Serge', special: '', imagePath: 'Programmas/vrijdag/3. De Muziekfabriek.JPG' },
  { day: 'Vrijdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '', imagePath: 'Programmas/vrijdag/4 Weer-of-geen-weer.jpg' },
  { day: 'Vrijdag', startTime: '12:00', endTime: '14:00', title: 'Muziekvarieté', presenter: 'Luc Van Meerbeek', special: '', imagePath: 'Programmas/vrijdag/5 Muziekvariété.jpg' },
  { day: 'Vrijdag', startTime: '14:00', endTime: '15:00', title: 'Musicmachine', presenter: 'Danny de Groot', special: '', imagePath: 'Programmas/vrijdag/6 Music Machine.jpg' },
  { day: 'Vrijdag', startTime: '15:00', endTime: '16:00', title: 'Showtime', presenter: 'Marc Huylebroeck', special: '', imagePath: 'Programmas/vrijdag/7 Showtime.jpg' },
  { day: 'Vrijdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '', imagePath: 'Programmas/vrijdag/8 Muziekland.jpg' },
  { day: 'Vrijdag', startTime: '17:00', endTime: '18:00', title: 'Discoclub', presenter: 'Peter Babbelaer', special: '', imagePath: 'Programmas/vrijdag/9 Discoclub.jpeg' },
  { day: 'Vrijdag', startTime: '18:00', endTime: '19:00', title: 'Fridaynight dance', presenter: '', special: '', imagePath: 'Programmas/vrijdag/10 Friday night dance.jpeg' },
  { day: 'Vrijdag', startTime: '19:00', endTime: '20:00', title: 'Hitfornuis', presenter: '', special: '', imagePath: 'Programmas/vrijdag/11 Hitfornuis.jpeg' },
  { day: 'Vrijdag', startTime: '20:00', endTime: '22:00', title: 'Hitrevue', presenter: 'Jan Van Antwerpen', special: '', imagePath: 'Programmas/vrijdag/12 Hitrevue Dance.JPG' },
  { day: 'Vrijdag', startTime: '22:00', endTime: '24:00', title: 'Nillies', presenter: '', special: '', imagePath: 'Programmas/vrijdag/13 The Nillies.jpg' },
  { day: 'Vrijdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },

  // ZATERDAG
  { day: 'Zaterdag', startTime: '07:00', endTime: '08:00', title: 'Ochtendgloren', presenter: '', special: '', imagePath: '' },
  { day: 'Zaterdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '', imagePath: 'Programmas/zaterdag/1 Plaatjes zonder praatjes.jpeg' },
  { day: 'Zaterdag', startTime: '09:00', endTime: '10:00', title: 'Gouden herstartuur', presenter: '', special: '', imagePath: 'Programmas/zaterdag/2 Gouden Uren.jpg' },
  { day: 'Zaterdag', startTime: '10:00', endTime: '12:00', title: 'Het Vragen Waard', presenter: 'Bende', special: '', imagePath: 'Programmas/zaterdag/3 Het Vragen Waard.jpg' },
  { day: 'Zaterdag', startTime: '12:00', endTime: '14:00', title: 'Hitrevue Retro', presenter: 'Jan Van Antwerpen', special: '', imagePath: 'Programmas/zaterdag/4 Hitrevue Retro.JPG' },
  { day: 'Zaterdag', startTime: '14:00', endTime: '16:00', title: 'De Notenbalk', presenter: 'Walter Van Balen', special: '', imagePath: 'Programmas/zaterdag/5 De Notenbalk.jpeg' },
  { day: 'Zaterdag', startTime: '16:00', endTime: '17:00', title: 'Terug naar toen', presenter: 'Rudolf Stevens', special: '', imagePath: 'Programmas/zaterdag/6 Terug naar toen.jpg' },
  { day: 'Zaterdag', startTime: '17:00', endTime: '20:00', title: 'De oude doos', presenter: 'Willy', special: '', imagePath: 'Programmas/zaterdag/7 De Oude Doos.jpeg' },
  { day: 'Zaterdag', startTime: '20:00', endTime: '22:00', title: 'Golden Hits Gommaar', presenter: '', special: '', imagePath: 'Programmas/zaterdag/8 Golden Hits.JPG' },
  { day: 'Zaterdag', startTime: '22:00', endTime: '24:00', title: '60 was heftig', presenter: '', special: '', imagePath: "Programmas/zaterdag/9 60's.jpg" },
  { day: 'Zaterdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },

  // ZONDAG
  { day: 'Zondag', startTime: '07:00', endTime: '08:00', title: 'Ochtendgloren', presenter: '', special: '', imagePath: '' },
  { day: 'Zondag', startTime: '08:00', endTime: '09:00', title: 'Kruiemls in bed', presenter: 'Hendrik', special: '', imagePath: 'Programmas/zondag/1. Kruimels in bed.jpeg' },
  { day: 'Zondag', startTime: '09:00', endTime: '11:00', title: 'De Zotte Doos', presenter: 'Kristel', special: '', imagePath: 'Programmas/zondag/2 De Zotte Doos.jpg' },
  { day: 'Zondag', startTime: '11:00', endTime: '12:00', title: 'Uur van Oranje', presenter: 'Michel', special: '', imagePath: 'Programmas/zondag/3 Het uur van Oranje.jpg' },
  { day: 'Zondag', startTime: '12:00', endTime: '14:00', title: 'Grasduinen', presenter: 'Wim Donckers', special: '', imagePath: 'Programmas/zondag/4 Grasduinen.jpeg' },
  { day: 'Zondag', startTime: '14:00', endTime: '15:00', title: 'Helden van de popmuziek', presenter: 'Rob van Daele', special: '', imagePath: 'Programmas/zondag/5 Gouden Uren.jpg' },
  { day: 'Zondag', startTime: '15:00', endTime: '17:00', title: 'De Uitnodiging', presenter: 'Alain en Moniek', special: '', imagePath: 'Programmas/zondag/6 De Uitnodiging.jpg' },
  { day: 'Zondag', startTime: '17:00', endTime: '19:00', title: 'Solid Gold', presenter: 'Dirk de Bruyn', special: '', imagePath: 'Programmas/zondag/7 Solid Gold.jpg' },
  { day: 'Zondag', startTime: '19:00', endTime: '20:00', title: '60min muziekgeschiedenis', presenter: 'Luck', special: '', imagePath: 'Programmas/zondag/8 60 min muziekgeschiedenis.jpg' },
  { day: 'Zondag', startTime: '20:00', endTime: '21:00', title: '60min vreemdgaan', presenter: 'Hendrik', special: '', imagePath: 'Programmas/zondag/9 60 minuten Vreemdgaan.jpg' },
  { day: 'Zondag', startTime: '21:00', endTime: '24:00', title: 'Romantica', presenter: 'Lenna DuFin', special: '', imagePath: 'Programmas/zondag/10 Romantica.jpg' },
  { day: 'Zondag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '', imagePath: '' },
];

// Generate a clean document ID from day and title
function generateId(program) {
  const title = program.title
    .replace(/['']/g, '')        // remove apostrophes
    .replace(/[%]/g, 'procent')  // replace % 
    .replace(/[^a-zA-Z0-9\s]/g, '') // remove other special chars
    .trim()
    .replace(/\s+/g, '_');       // replace spaces with underscores
  
  const suffix = program.special === 'last_wednesday_of_month' ? '_last' : '';
  return `${program.day}_${title}${suffix}`;
}

// Get a public download URL for a Firebase Storage file
async function getDownloadUrl(imagePath) {
  if (!imagePath) return '';
  try {
    const file = bucket.file(imagePath);
    const [exists] = await file.exists();
    if (!exists) {
      console.warn(`  ⚠ File not found in Storage: ${imagePath}`);
      return '';
    }
    // Get or create a download token and build the public URL
    const [metadata] = await file.getMetadata();
    let token = metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens;
    if (!token) {
      // Create a new token
      const { v4: uuidv4 } = require('crypto');
      token = require('crypto').randomUUID();
      await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
    }
    const encodedPath = encodeURIComponent(imagePath);
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${token}`;
  } catch (err) {
    console.warn(`  ⚠ Error getting URL for ${imagePath}: ${err.message}`);
    return '';
  }
}

async function deleteAll() {
  const snapshot = await db.collection('programmatie').get();
  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Deleted ${snapshot.docs.length} existing documents.`);
}

async function uploadPrograms() {
  console.log('Resolving download URLs from Firebase Storage...\n');
  
  for (const program of programs) {
    const url = await getDownloadUrl(program.imagePath);
    program.imageUrl = url;
    if (url) {
      console.log(`  ✓ ${program.day} - ${program.title}`);
    } else if (program.imagePath) {
      console.log(`  ✗ ${program.day} - ${program.title} (NOT FOUND)`);
    }
  }

  console.log('\nUploading programs to Firestore...');
  const batch = db.batch();
  const collection = db.collection('programmatie');

  programs.forEach((program) => {
    const id = generateId(program);
    const ref = collection.doc(id);
    // Store everything except imagePath (that's only used locally by this script)
    const { imagePath, ...firestoreData } = program;
    batch.set(ref, firestoreData);
  });

  await batch.commit();
  console.log(`\n✅ Successfully uploaded ${programs.length} programs with image URLs!`);
  process.exit(0);
}

async function run() {
  await deleteAll();
  await uploadPrograms();
}

run().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});