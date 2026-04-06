const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const programs = [
  // MAANDAG
  { day: 'Maandag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '' },
  { day: 'Maandag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '' },
  { day: 'Maandag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Jo', special: '' },
  { day: 'Maandag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '' },
  { day: 'Maandag', startTime: '12:00', endTime: '14:00', title: 'Werken met muziek', presenter: 'Harry van Lint', special: '' },
  { day: 'Maandag', startTime: '14:00', endTime: '16:00', title: 'Muziekmozaiek', presenter: 'Peter Hoffman', special: '' },
  { day: 'Maandag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '' },
  { day: 'Maandag', startTime: '17:00', endTime: '18:00', title: 'De Hitmolen', presenter: 'Marco de Bruyn', special: '' },
  { day: 'Maandag', startTime: '18:00', endTime: '20:00', title: 'De Platenkast', presenter: 'Luc van Turnhout', special: '' },
  { day: 'Maandag', startTime: '20:00', endTime: '22:00', title: 'Hitarchief', presenter: 'Ronny v.d. Broeck', special: '' },
  { day: 'Maandag', startTime: '22:00', endTime: '24:00', title: '80 is prachtig', presenter: '', special: '' },
  { day: 'Maandag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },

  // DINSDAG
  { day: 'Dinsdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '' },
  { day: 'Dinsdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '' },
  { day: 'Dinsdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Gert van Eeden', special: '' },
  { day: 'Dinsdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '' },
  { day: 'Dinsdag', startTime: '12:00', endTime: '14:00', title: 'Door de jaren heen', presenter: 'Remi Beelaert', special: '' },
  { day: 'Dinsdag', startTime: '14:00', endTime: '15:00', title: 'Nooit vervelende hits', presenter: 'Bart Mottart', special: '' },
  { day: 'Dinsdag', startTime: '15:00', endTime: '16:00', title: 'Verhoeven op de radio', presenter: '', special: '' },
  { day: 'Dinsdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '' },
  { day: 'Dinsdag', startTime: '17:00', endTime: '18:00', title: 'Belpop', presenter: 'Johan Dhondt', special: '' },
  { day: 'Dinsdag', startTime: '18:00', endTime: '20:00', title: 'Thematoppers', presenter: 'Moniek & Alain', special: '' },
  { day: 'Dinsdag', startTime: '20:00', endTime: '22:00', title: 'Generation X', presenter: 'Wim Verwerft', special: '' },
  { day: 'Dinsdag', startTime: '22:00', endTime: '24:00', title: "70's are besties", presenter: '', special: '' },
  { day: 'Dinsdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },

  // WOENSDAG
  { day: 'Woensdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '' },
  { day: 'Woensdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '' },
  { day: 'Woensdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Roger Van Dosselaer', special: '' },
  { day: 'Woensdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '' },
  { day: 'Woensdag', startTime: '12:00', endTime: '14:00', title: 'Vrienden van de radio', presenter: 'Hans van Dam', special: '' },
  { day: 'Woensdag', startTime: '14:00', endTime: '16:00', title: '98% Vinyl', presenter: 'Piet de Schrijver', special: '' },
  { day: 'Woensdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '' },
  { day: 'Woensdag', startTime: '17:00', endTime: '18:00', title: 'Radiorama', presenter: 'Benny de Wit', special: '' },
  { day: 'Woensdag', startTime: '18:00', endTime: '20:00', title: 'Dubbel Genot', presenter: 'Ben en Sven', special: '' },
  { day: 'Woensdag', startTime: '20:00', endTime: '22:00', title: 'Electric Café Patje Fox', presenter: 'De Catacomben Steph', special: '' },
  { day: 'Woensdag', startTime: '20:00', endTime: '22:00', title: 'Electric Café Patje Fox', presenter: 'De Catacomben Steph', special: 'last_wednesday_of_month' },
  { day: 'Woensdag', startTime: '22:00', endTime: '24:00', title: "90's", presenter: '', special: '' },
  { day: 'Woensdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },

  // DONDERDAG
  { day: 'Donderdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '' },
  { day: 'Donderdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '' },
  { day: 'Donderdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Roger Van Dosselaer', special: '' },
  { day: 'Donderdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '' },
  { day: 'Donderdag', startTime: '12:00', endTime: '14:00', title: 'Patsie Time', presenter: 'Patsie', special: '' },
  { day: 'Donderdag', startTime: '14:00', endTime: '16:00', title: 'Jukebox', presenter: 'Pieter', special: '' },
  { day: 'Donderdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '' },
  { day: 'Donderdag', startTime: '17:00', endTime: '18:00', title: 'Radiorama', presenter: 'Benny de Wit', special: '' },
  { day: 'Donderdag', startTime: '18:00', endTime: '20:00', title: "Nipper's Greatest Hits", presenter: 'Jempie Vanhorenbeek', special: '' },
  { day: 'Donderdag', startTime: '20:00', endTime: '22:00', title: 'Country Club', presenter: 'Peter Briers en Serge', special: '' },
  { day: 'Donderdag', startTime: '22:00', endTime: '24:00', title: "70's are besties", presenter: '', special: '' },
  { day: 'Donderdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },

  // VRIJDAG
  { day: 'Vrijdag', startTime: '07:00', endTime: '08:00', title: 'De ochtendkroeg', presenter: 'Peter Babbelaer', special: '' },
  { day: 'Vrijdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '' },
  { day: 'Vrijdag', startTime: '09:00', endTime: '11:00', title: 'De Muziekfabriek', presenter: 'Serge', special: '' },
  { day: 'Vrijdag', startTime: '11:00', endTime: '12:00', title: 'Weer of geen weer', presenter: 'Jos van Meer', special: '' },
  { day: 'Vrijdag', startTime: '12:00', endTime: '14:00', title: 'Muziekvarieté', presenter: 'Luc Van Meerbeek', special: '' },
  { day: 'Vrijdag', startTime: '14:00', endTime: '15:00', title: 'Musicmachine', presenter: 'Danny de Groot', special: '' },
  { day: 'Vrijdag', startTime: '15:00', endTime: '16:00', title: 'Showtime', presenter: 'Marc Huylebroeck', special: '' },
  { day: 'Vrijdag', startTime: '16:00', endTime: '17:00', title: 'Muziekland', presenter: 'Rudy van Hove', special: '' },
  { day: 'Vrijdag', startTime: '17:00', endTime: '18:00', title: 'Discoclub', presenter: 'Peter Babbelaer', special: '' },
  { day: 'Vrijdag', startTime: '18:00', endTime: '19:00', title: 'Fridaynight dance', presenter: '', special: '' },
  { day: 'Vrijdag', startTime: '19:00', endTime: '20:00', title: 'Hitfornuis', presenter: '', special: '' },
  { day: 'Vrijdag', startTime: '20:00', endTime: '22:00', title: 'Hitrevue', presenter: 'Jan Van Antwerpen', special: '' },
  { day: 'Vrijdag', startTime: '22:00', endTime: '24:00', title: 'Nillies', presenter: '', special: '' },
  { day: 'Vrijdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },

  // ZATERDAG
  { day: 'Zaterdag', startTime: '07:00', endTime: '08:00', title: 'Ochtendgloren', presenter: '', special: '' },
  { day: 'Zaterdag', startTime: '08:00', endTime: '09:00', title: 'Plaatjes zonder praatjes', presenter: 'Frank', special: '' },
  { day: 'Zaterdag', startTime: '09:00', endTime: '10:00', title: 'Gouden herstartuur', presenter: '', special: '' },
  { day: 'Zaterdag', startTime: '10:00', endTime: '12:00', title: 'Het Vragen Waard', presenter: 'Bende', special: '' },
  { day: 'Zaterdag', startTime: '12:00', endTime: '14:00', title: 'Hitrevue Retro', presenter: 'Jan Van Antwerpen', special: '' },
  { day: 'Zaterdag', startTime: '14:00', endTime: '16:00', title: 'De Notenbalk', presenter: 'Walter Van Balen', special: '' },
  { day: 'Zaterdag', startTime: '16:00', endTime: '17:00', title: 'Terug naar toen', presenter: 'Rudolf Stevens', special: '' },
  { day: 'Zaterdag', startTime: '17:00', endTime: '20:00', title: 'De oude doos', presenter: 'Willy', special: '' },
  { day: 'Zaterdag', startTime: '20:00', endTime: '22:00', title: 'Golden Hits Gommaar', presenter: '', special: '' },
  { day: 'Zaterdag', startTime: '22:00', endTime: '24:00', title: '60 was heftig', presenter: '', special: '' },
  { day: 'Zaterdag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },

  // ZONDAG
  { day: 'Zondag', startTime: '07:00', endTime: '08:00', title: 'Ochtendgloren', presenter: '', special: '' },
  { day: 'Zondag', startTime: '08:00', endTime: '09:00', title: 'Kruiemls in bed', presenter: 'Hendrik', special: '' },
  { day: 'Zondag', startTime: '09:00', endTime: '11:00', title: 'De Zotte Doos', presenter: 'Kristel', special: '' },
  { day: 'Zondag', startTime: '11:00', endTime: '12:00', title: 'Uur van Oranje', presenter: 'Michel', special: '' },
  { day: 'Zondag', startTime: '12:00', endTime: '14:00', title: 'Grasduinen', presenter: 'Wim Donckers', special: '' },
  { day: 'Zondag', startTime: '14:00', endTime: '15:00', title: 'Helden van de popmuziek', presenter: 'Rob van Daele', special: '' },
  { day: 'Zondag', startTime: '15:00', endTime: '17:00', title: 'De Uitnodiging', presenter: 'Alain en Moniek', special: '' },
  { day: 'Zondag', startTime: '17:00', endTime: '19:00', title: 'Solid Gold', presenter: 'Dirk de Bruyn', special: '' },
  { day: 'Zondag', startTime: '19:00', endTime: '20:00', title: '60min muziekgeschiedenis', presenter: 'Luck', special: '' },
  { day: 'Zondag', startTime: '20:00', endTime: '21:00', title: '60min vreemdgaan', presenter: 'Hendrik', special: '' },
  { day: 'Zondag', startTime: '21:00', endTime: '24:00', title: 'Romantica', presenter: 'Lenna DuFin', special: '' },
  { day: 'Zondag', startTime: '24:00', endTime: '07:00', title: 'Nachtwacht', presenter: '', special: '' },
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

async function deleteAll() {
  const snapshot = await db.collection('programmatie').get();
  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Deleted ${snapshot.docs.length} existing documents.`);
}

async function uploadPrograms() {
  const batch = db.batch();
  const collection = db.collection('programmatie');

  programs.forEach((program) => {
    const id = generateId(program);
    const ref = collection.doc(id);
    batch.set(ref, program);
  });

  await batch.commit();
  console.log(`Successfully uploaded ${programs.length} programs!`);
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