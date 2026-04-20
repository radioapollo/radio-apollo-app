# Radio Apollo

De officiële mobiele app voor **Radio Apollo** — de lokale radiozender uit
Wiekevorst. Luister live, bekijk programma's, stuur berichten naar de
studio, en ontdek lokale evenementen.

Gebouwd met Flutter. Beschikbaar voor Android en iOS.

---

## Functies

- **Livestream**: altijd en overal Radio Apollo afspelen, met achtergrond-
  audio en afspeelcontroles in de systeemmeldingen.
- **Huidig programma in beeld**: zie wie er aan het werk is, welk
  tijdslot loopt en welk nummer nu speelt.
- **Weekschema**: blader per dag door alle programma's van de week.
- **Livechat met de studio**: stuur berichten tijdens de uitzending,
  de studio kan rechtstreeks antwoorden.
- **Evenementenoverzicht**: blijf op de hoogte van lokale fuiven,
  acties en andere happenings.
- **Chromecast-ondersteuning**: cast de stream naar je luidsprekers of tv.
- **Sponsors en partners**: ontdek de lokale ondernemers die Radio
  Apollo mogelijk maken.

---

## 🏗️ Technische stack

| Onderdeel | Technologie |
|-----------|-------------|
| App | Flutter (Dart) |
| Audio | `just_audio` + `audio_service` |
| Chat / database | Cloud Firestore (Firebase) |
| Cloud Functions | Firebase Functions (Node.js) |
| Chromecast | `flutter_chrome_cast` |
| Beeldcache | `cached_network_image` |
| Lokale opslag | `shared_preferences` |
| CI/CD | GitHub Actions |

**Bundle ID:** `be.radioapollo.app`
**Firebase regio:** `europe-west1` (EU-datahouding voor GDPR)
**Minimum Android SDK:** 21 (Android 5.0 Lollipop)
**Minimum iOS versie:** 13.0

---

## 📁 Projectstructuur

```
lib/
├── constants/          # Centrale constanten (URLs, Firestore collecties)
├── models/             # Datamodellen (Message, Sponsor, Program, Event)
├── navigation/         # Root navigatie met bottom nav bar
├── screens/            # Eén scherm per tab
├── services/           # Firestore, audio, chat, auth, programma's
├── theme/              # Kleuren, tekststijlen, dimensies, decoraties
├── utils/              # Datumhelpers, URL-launcher wrappers
└── widgets/            # Herbruikbare UI-componenten per scherm

android/                # Android-specifieke configuratie
ios/                    # iOS-specifieke configuratie
docs/                   # Privacybeleid, store-listing-copy, GitHub Pages
store-assets/           # Feature graphic, screenshots, generator script
.github/workflows/      # CI + release pipelines
```

---

## 🔄 CI/CD

Dit project gebruikt **tag-triggered releases** via GitHub Actions.

| Trigger | Workflow | Resultaat |
|---------|----------|-----------|
| Push naar `main` of PR | `ci.yml` | Format-check + analyze + tests |
| Tag `v*` | `release-android.yml` | Signed `.aab` naar Play internal |
| Tag `v*` | `release-ios.yml` | Signed `.ipa` naar TestFlight |

Een nieuwe versie uitbrengen:

```bash
# Bump version in pubspec.yaml EN lib/constants/app_constants.dart
git commit -am "release: 1.0.1"
git tag v1.0.1
git push --tags
```

## 🔒 Privacy en gegevensbescherming

Radio Apollo verzamelt minimale gegevens, uitsluitend voor het functioneren
van de app. We verkopen geen data en gebruiken geen advertentietrackers.

Volledig privacybeleid: [https://radioapollo.github.io/Apollo_Radio/](https://radioapollo.github.io/Apollo_Radio/)

Voor privacygerelateerde vragen: [bestuur@radioapollo.be](mailto:bestuur@radioapollo.be)

---

## 📄 Licentie

© Radio Apollo. Alle rechten voorbehouden.

De broncode is niet open-source. Gebruik, kopie of redistributie is niet
toegestaan zonder uitdrukkelijke schriftelijke toestemming.

---

## 📞 Contact

**Radio Apollo**
Lindestraat 7a, 2222 Wiekevorst
📧 [bestuur@radioapollo.be](mailto:bestuur@radioapollo.be)
📞 014/26.16.16
🌐 [www.radioapollo.be](https://www.radioapollo.be)
