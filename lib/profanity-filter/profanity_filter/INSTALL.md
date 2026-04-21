# Profanity Filter — Installation Guide

Two-layer content moderation for Radio Apollo chat:

1. **Client-side** (Flutter) — instant feedback, no round-trip
2. **Server-side** (Cloud Functions) — real enforcement, can't be bypassed

## Files included

```
profanity_filter/
├── INSTALL.md                    ← this file
├── profanity_config.dart         ← word lists (Dutch + English)
├── profanity_filter.dart         ← filter logic
├── chat_service.dart             ← updated ChatService with filtering
└── cloud_function_profanity.js   ← server-side enforcement snippet
```

---

## Part 1 — Client-side (Flutter)

### Step 1: Create the filter folder

```powershell
cd C:\Users\Raf\Documents\Zelfstandig\ApolloRadio\Apollo_Radio
New-Item -ItemType Directory -Path "lib\utils\profanity" -Force
```

### Step 2: Install the filter files

Copy the two config files:

```powershell
Copy-Item "$env:USERPROFILE\Downloads\profanity_config.dart" "lib\utils\profanity\profanity_config.dart"
Copy-Item "$env:USERPROFILE\Downloads\profanity_filter.dart" "lib\utils\profanity\profanity_filter.dart"
```

### Step 3: Replace ChatService

Backup your existing ChatService first:

```powershell
Copy-Item "lib\services\chat\chat_service.dart" "lib\services\chat\chat_service.dart.backup"
```

Then replace it with the new one:

```powershell
Copy-Item "$env:USERPROFILE\Downloads\chat_service.dart" "lib\services\chat\chat_service.dart"
```

### Step 4: Test the client-side filter

```powershell
flutter clean
flutter pub get
flutter run
```

Open the chat, try sending:
- `"Dit is kut"` → auto-censored to `"Dit is k*t"`
- `"fuck off"` → auto-censored to `"f**k off"`
- Severe words (I won't type examples) → blocked with error message

The client should reject severe words instantly and auto-censor mild ones.

---

## Part 2 — Server-side (Cloud Functions)

This is the REAL enforcement. Without this, tech-savvy users could bypass
the client-side filter by modifying the app.

### Step 5: Add the profanity logic to Cloud Functions

Open your existing `lib/functions/index.js` in an editor.

At the **top** of the file (after the `admin.initializeApp()` call),
paste the entire contents of `cloud_function_profanity.js`.

This adds:
- The word lists (same as client-side)
- `normalize()`, `containsWord()`, `censorWord()` functions
- `checkProfanity()` main function

### Step 6: Integrate into userSendMessage

Find your `exports.userSendMessage` function in `index.js`.

Locate the section that writes to Firestore (looks like this):

```javascript
await db.collection('chat_messages').add({
  username: trimmedUsername,
  text: trimmed,
  role: 'user',
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Replace** that entire block with:

```javascript
// ── Profanity check ─────────────────────────────────────────────────
const filterResult = checkProfanity(trimmed);

if (filterResult.isSevere) {
  res.status(400).json({
    error: 'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
  });
  return;
}

// Use censored text if mild profanity was detected
const textToStore = filterResult.cleanedText;

// ── Write message ───────────────────────────────────────────────────
await db.collection('chat_messages').add({
  username: trimmedUsername,
  text: textToStore,
  role: 'user',
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
});
```

### Step 7: Deploy the updated Cloud Function

```powershell
cd lib\functions
firebase deploy --only functions:userSendMessage
```

Wait for the deployment to complete (~1-2 minutes).

### Step 8: Test the server-side filter

Even if someone hacked the client to skip the filter, the server will
still enforce. You can test this manually:

```powershell
curl -X POST https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/userSendMessage `
  -H "Content-Type: application/json" `
  -d '{"username":"TestUser","text":"This is a severe word test"}'
```

Should return:
```json
{
  "error": "Dit bericht kan niet worden verzonden. Blijf vriendelijk."
}
```

---

## Customizing the word lists

Both client and server use the same word lists. To add/remove words:

### Client-side
Edit `lib/utils/profanity/profanity_config.dart`:
- Add to `severeWordsDutch` or `severeWordsEnglish` for hard blocks
- Add to `mildWordsDutch` or `mildWordsEnglish` for auto-censoring

### Server-side
Edit the arrays at the top of `lib/functions/index.js`:
- `SEVERE_WORDS_DUTCH`, `SEVERE_WORDS_ENGLISH`
- `MILD_WORDS_DUTCH`, `MILD_WORDS_ENGLISH`

**Important:** Keep both lists in sync. If you add a word client-side,
add it server-side too — otherwise the server might allow what the
client blocks (confusing UX).

After changing server-side lists:
```powershell
cd lib\functions
firebase deploy --only functions:userSendMessage
```

---

## How it works

### Two-tier severity

**Severe words** (slurs, hate speech, extreme vulgarity):
- Blocked entirely
- User sees: "Dit bericht kan niet worden verzonden. Blijf vriendelijk."
- Message never reaches Firestore

**Mild words** (common profanity):
- Auto-censored to asterisks: `fuck` → `f**k`
- Message goes through with censored text
- Keeps chat flowing while removing toxicity

### Evasion detection

The filter catches common bypass attempts:
- **Leetspeak:** `f*ck`, `sh1t`, `n1gger` → detected and blocked/censored
- **Spacing:** `f u c k`, `n i g g e r` → detected
- **Repeated letters:** `fuuuuck`, `shiiiit` → detected
- **Mixed case:** `FuCk`, `ShIt` → detected

### Word boundaries

The filter uses word boundaries so legitimate words aren't flagged:
- `"class"` does NOT match `"ass"`
- `"assassin"` does NOT match `"ass"`
- `"hassle"` does NOT match `"ass"`

But:
- `"You're an ass"` DOES match and gets censored to `"You're an a*s"`

---

## Testing checklist

After installation, verify:

- [ ] Clean message sends normally: `"Hallo allemaal"`
- [ ] Mild Dutch profanity censored: `"Dit is kut"` → `"Dit is k*t"`
- [ ] Mild English profanity censored: `"This is shit"` → `"This is s**t"`
- [ ] Severe words blocked (test with a throwaway username)
- [ ] Leetspeak caught: `"f*ck"` → censored or blocked
- [ ] Spacing caught: `"f u c k"` → censored or blocked
- [ ] Word boundaries work: `"class"` sends clean

---

## Commit

Once everything works:

```powershell
git add lib/utils/profanity/ lib/services/chat/chat_service.dart lib/functions/index.js
git commit -m "feat: add profanity filter (client + server enforcement)"
git push
```

CI will run and pass (no breaking changes, just new logic).

---

## Support

If you encounter issues:

1. **Client blocks but server allows:** word lists out of sync — check both
2. **Legitimate words flagged:** word boundary issue — check the pattern
3. **Filter not working:** verify both client + server are deployed
4. **Evasion getting through:** add the pattern to normalize() function

To add a new evasion pattern, edit the `normalize()` function in both:
- `lib/utils/profanity/profanity_filter.dart` (client)
- `lib/functions/index.js` (server)

Keep them in sync.
