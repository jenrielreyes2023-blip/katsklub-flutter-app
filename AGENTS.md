# KatsKlub Project Guidelines for AI Agents

Welcome, Agent. This repository powers **KatsKlub**, a full-stack social media and community platform (Flutter frontend, Node.js/Express backend, PostgreSQL database, Cloudflare R2 media storage).

---

## 👥 User Account & Persona Rules (CRITICAL)

The `users` table contains both real human accounts and simulated persona accounts. Every account is flagged using the `is_persona` column.

### 1. Real / Admin Accounts (`is_persona = FALSE`)
* **`@jayriel` (User ID: 2)**: The primary owner and human developer of KatsKlub. **NEVER** use this account for automated bot actions, auto-comments, dummy test posts, or random updates unless explicitly instructed by the user.
* **`@gemini` (User ID: 48)**: Main AI system / developer identity.
* Any future real organic users who sign up via the mobile app will have `is_persona = FALSE`.

### 2. Persona Accounts (`is_persona = TRUE`)
* There are currently **54 active persona accounts** in the PostgreSQL `users` table.
* **Purpose**: Used for simulated community engagement, testing, content feeds, stories, comments, reels, and realistic social interaction.
* **How to Query Personas in SQL**:
  ```sql
  SELECT id, username, full_name, avatar_url, bio, location 
  FROM users 
  WHERE is_persona = TRUE 
  ORDER BY id ASC;
  ```
* **Default Password**: All personas use `katsklub2026` as their password hash.
* **Adding New Personas**:
  * Always set `is_persona = TRUE` upon inserting into `users`.
  * Upload avatars directly to Cloudflare R2 (`https://media.katsklub.top/avatars/...`).
  * Set `role_title = 'Member'` (not 'Persona') for normal community personas.

### 3. How This Batch Was Created (2026-08-29 — Anime Board 83 personas)
* **Source Board**: `https://www.pinterest.ph/froxvek/anime-girls/` (29 unique images via `gallery-dl -g`, sorted unique)
* **Existing**: 54 personas → **Created 29 new** (ID 60 `yume.aiko` + IDs 61-88 bulk) → **Total 83 personas** (`is_persona=TRUE`)
* **Direct-to-R2 Flow Used**:
  1. `gallery-dl -g "<board_url>" | sort -u > urls.txt` (29 URLs)
  2. Per image: `fetch(url)` → RAM `Buffer` → `optimizeImage(buf, true)` (sharp 512x512 cover, WebP 85%, ~25-37KB) → `uploadBuffer(buffer, 'avatars/avatar-<uuid>-<ts>.webp', 'image/webp')` → `https://media.katsklub.top/avatars/...`
  3. `password_hash = bcrypt.hash('katsklub2026', 10)` (reused hash for batch)
  4. `INSERT INTO users (username, email, password_hash, full_name, bio, location, avatar_url, is_persona, is_verified, role_title) VALUES ($1,$2,$3,$4,$5,$6,$7, TRUE, false, 'Member')` + `INSERT INTO wallets (user_id, 500.00)`
* **Bio Diversity (no duplicates)**: taglish quotes, text-style `𝒮ℴ𝒻𝓉`, plain no-emoji, cute, mahaba, maikli, bisaya, ilokano, waray, korean `조용한 하루...`, chinese `喜欢安静...`, hindi `सादगी में...`, japanese `静かな毎日...` + variants — total 29 unique bios
* **Example New Personas**: `yume.aiko`, `sakura.miyu`, `mio.tanaka`, `hana.chii`, `rui.nakamura`, `yuki.ayame`, `emi.saito`, `aki.haruka` (bisaya), `nana.yui` (ilokano), `rei.kobayashi` (waray), `sora.mizuki` (korean), `kiko.amane` (chinese), `momo.hoshino` (hindi), `rin.aoi` (japanese), `chika.ume`, `haru.kanade`, `yuna.shiho`, `aiko.rin`, `mika.ayaka`, `eri.natsuki`, `ayaka.luna`, `koharu.mei`, `nozomi.yua`, `shiori.kae`, `nanami.yori`, `himari.suzu`, `kotori.ane`, `tsuki.emi`, `sumire.aoi`
* **Weather Post Example**: Post ID 18 by `yume.aiko` (Manila, feeling `cozy 🌧️`) about bagyo, with 15 varied comments from other new personas covering same language mix

---

## 🎬 Content Creation & Persona Automation Playbook

### 1. Installed CLI & Processing Tools
* **`yt-dlp`** (`/usr/local/bin/yt-dlp`): High-speed video/audio extraction (YouTube, Pinterest, TikTok, Instagram, Twitter/X).
* **`gallery-dl`** (`/usr/local/bin/gallery-dl`): High-speed photo and album/board extraction (Pinterest boards, carousels, image galleries).
* **`sharp`** (in `katsklub-backend/node_modules/sharp`): Image resizing, WebP conversion, and text overlay compositing.
* **`ffmpeg`**: Audio/video muxing and container conversion.

### 2. Zero Disk Clutter Policy (Direct-to-R2 Flow)
**NEVER save permanent downloads to the local disk (`downloads/`, etc.).**
* **For Images**:
  1. Extract direct URL with `gallery-dl -g "<URL>"`.
  2. Fetch directly to RAM Buffer: `const buf = Buffer.from(await (await fetch(url)).arrayBuffer());`
  3. Optimize via sharp: `const { buffer } = await optimizeImage(buf);`
  4. Upload to R2: `await uploadBuffer(buffer, 'attachments/...webp', 'image/webp');`
* **For Videos**:
  1. Stream/download into RAM disk `/dev/shm/temp.mp4` using `yt-dlp`.
  2. Read buffer into Node.js: `const buf = fs.readFileSync('/dev/shm/temp.mp4');`
  3. Unlink immediately: `fs.unlinkSync('/dev/shm/temp.mp4');`
  4. Upload to R2: `await uploadBuffer(buf, 'attachments/...mp4', 'video/mp4');`

### 3. How to Create Posts & Reels
Insert directly into PostgreSQL `posts` table:
```sql
INSERT INTO posts (
  user_id, content, media_urls, media_type, postcard_url,
  location, feeling, is_reel, visibility
) VALUES (
  $1, -- Persona User ID
  $2, -- Styled Caption / Text
  $3, -- JSON array string of R2 media URLs (e.g. '["https://media.katsklub.top/..."]')
  $4, -- 'image', 'multi_image', or 'video'
  $5, -- Poster/thumbnail URL (for video reels)
  $6, -- Location
  $7, -- Feeling (e.g. 'vibing 🎧')
  $8, -- TRUE if video reel, FALSE if regular post
  'public'
);
```

### 4. How to Create Stories (With Music & Text Overlays)
* **Cute Music Selection via Apple Music / iTunes API**:
  Search for 30s preview tracks using:
  `https://itunes.apple.com/search?term=<query>&media=music&entity=song&limit=1`
* **Insert Story into `stories` table**:
```sql
INSERT INTO stories (
  user_id, media_url, media_type, caption,
  music_title, music_artist, music_artwork_url, music_preview_url, music_source
) VALUES (
  $1, -- Persona User ID
  $2, -- R2 Story WebP URL (composited with cute text if applicable)
  'image',
  $3, -- Caption
  $4, -- Music Title (e.g. 'seasons')
  $5, -- Artist (e.g. 'wave to earth')
  $6, -- 600x600 artwork URL
  $7, -- AAC preview audio URL
  'apple'
);
```

### 5. How to Add Comments & Likes
* **Comments**:
  ```sql
  INSERT INTO post_comments (post_id, user_id, content) VALUES ($1, $2, $3);
  ```
* **Likes**:
  ```sql
  INSERT INTO post_likes (post_id, user_id, reaction_type) VALUES ($1, $2, 'like') ON CONFLICT DO NOTHING;
  ```

---

## 🚀 Flutter Build & CI/CD Rules (CLOUD-ONLY)

### 1. Build Strategy — Cloud Only (No Local APK Build)
* **NEVER run `flutter build apk` on this local VPS.** Local builds waste VPS CPU and memory.
* All APK builds are handled strictly via **GitHub Actions** (`Build Flutter Android APK`).
* **Workflow File**: `.github/workflows/build-android.yml`
* **Trigger**: `git push` to `main` or manual trigger (`workflow_dispatch`).
* **Cloud Build Command**:
  ```bash
  flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
  ```
* **Auto-Deployment**: Built APK is automatically deployed to `https://katsklub.top/katsklub-latest.apk` (located at `/var/www/katsklub/katsklub-latest.apk`).

### 2. Code Analyze — Cloud CI
* **No local `flutter analyze` required.**
* Analysis runs automatically inside the GitHub Actions pipeline right after `flutter pub get`.
* If there is an analyze error, GitHub Actions automatically halts before compiling.

### 3. Local Flutter SDK on VPS (`/home/ubuntu/flutter`)
* Flutter SDK is available at `/home/ubuntu/flutter` for local syntax checks or code reading only.
* Do not use it for building production release artifacts.

### 4. Git Workflow for Developers & Agents
1. Make your Flutter changes in `/home/ubuntu/katsklub-flutter-app`.
2. Commit and `git push origin main`.
3. GitHub Actions builds and auto-deploys the APK in ~4-5 minutes.

---

## 🛠️ Stack Overview
* **Backend**: Express.js (`katsklub-backend/src/server.js`) running under PM2 (`pm2 list`).
* **Database**: PostgreSQL (`katsklub` DB on localhost:5432).
* **Storage**: Cloudflare R2 S3-compatible bucket (`https://media.katsklub.top`).
* **Frontend**: Flutter Mobile App (`katsklub-flutter-app`).
