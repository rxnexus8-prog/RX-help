# GhostCall 👻

Privacy-focused ephemeral VoIP calling app. No history, no recording, no real identity.

## Features
- 🔒 No call history saved (ever)
- 🎙️ No recording (P2P WebRTC — nothing touches a server)
- 👤 Custom 20-digit virtual call number (not your real phone number)
- 🎲 Random number per call option
- ❓ Show as "Unknown" option
- 🔑 Room code calling (6-char code → request → accept)
- 🎨 Custom app name + accent color
- 💀 Room auto-deleted after call ends

---

## Setup (15 minutes)

### Step 1: Supabase Setup

1. Go to [supabase.com](https://supabase.com) → Create free account
2. Create new project (remember the password)
3. Go to **SQL Editor** → **New Query**
4. Paste the entire contents of `supabase_schema.sql` → Run
5. Go to **Database** → **Replication** → Enable realtime for:
   - `rooms`
   - `ice_candidates`
6. Go to **Project Settings** → **API** → Copy:
   - `Project URL`
   - `anon public` key

### Step 2: Add Credentials

Open `lib/config/app_config.dart`:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
```

### Step 3: Push to GitHub

```bash
# In Termux:
git init
git add .
git commit -m "initial"
git remote add origin https://github.com/YOURUSERNAME/ghostcall.git
git push -u origin main
```

### Step 4: Get APK

1. Go to your GitHub repo → **Actions** tab
2. Wait for build to finish (~5 min)
3. Download APK from **Artifacts**
4. Install on your phone

---

## How to Use

### Make a Call
1. Register with any 20-digit number you choose
2. Tap **Create Room** → share the 6-char code
3. The other person taps **Join Room** → enters code → sends request
4. You see the request → tap **Accept** → call starts

### Privacy Settings
- **Random Number**: Different number shown on each call
- **Show as Unknown**: Callers see "Unknown" instead of your number
- **Change Number**: Update your 20-digit number anytime

### App Customization
- Change the app's display name (shown in the app bar)
- Pick an accent color theme

---

## Tech Stack

| Layer | Tech |
|-------|------|
| Frontend | Flutter (Dart) |
| Calling | WebRTC P2P (flutter_webrtc) |
| Signaling | Supabase Realtime |
| Auth/DB | Supabase (PostgreSQL) |
| Build | GitHub Actions |

---

## Privacy Notes

- No phone number collected
- No email collected  
- Password is SHA-256 hashed
- Calls are peer-to-peer (WebRTC) — no audio touches Supabase
- Room + ICE candidates deleted immediately after call ends
- No call logs stored anywhere
