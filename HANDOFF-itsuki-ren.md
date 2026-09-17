# HANDOFF — New Persona Member `itsuki.ren` (for the other AI)

Date: 2026-09-17. Previous AI worked from the Windows machine
(`C:\Users\Administrator\Desktop\katsklub-flutter-app`), NOT from the VPS.
Sandbox blocked: outbound SSH (port 22, EACCES), raw TCP to VPS Postgres
(5432, EACCES), writes to `C:\Users\Administrator\AppData` (EPERM — breaks
npm default cache, AWS SDK, git-credential-manager), PowerShell constrained
language mode (no `New-Object`). HTTPS fetch from Node works.

## 1. Task source

User gave Pinterest pin: `https://ph.pinterest.com/pin/720646377921242151/`
Direct image resolved (og:image + HTML scan, verified all 200):
`https://i.pinimg.com/originals/18/75/72/187572be4ce5f39146e91e5bb29f7173.jpg`
(80177 bytes, JPEG `ffd8ffe0`). Fallbacks that also work: `1200x`, `736x`
variants of the same hash. NOTE: naive "prefer originals" regex matched a CSS
garbage URL first — always key on the og:image hash `187572be...`.

Image content (viewed): young man, chinito, black hair, black sunglasses,
black shirt, car selfie in cream-leather back seat, K-pop/ulzzang vibe.
Hence a MALE persona (previous 83-persona batch was anime girls).

## 2. Already DONE (all verified)

- Avatar optimized: 512×512 cover, WebP 85% via sharp → 19924 bytes.
- Uploaded to Cloudflare R2: `avatars/avatar-252fd86e-6209-46e4-a66c-cde2784292af-1789641113635.webp`
  Public URL VERIFIED LIVE (independent fetch): HTTP 200,
  `content-type: image/webp`, 19924 B, magic bytes `52494646` (RIFF/WebP).
  URL: `https://media.katsklub.top/avatars/avatar-252fd86e-6209-46e4-a66c-cde2784292af-1789641113635.webp`
- Username availability checked via public API
  `GET https://katsklub.top/api/users/:username` (optionalAuth, no login needed):
  `yume.aiko` → 200 (control, exists), `itsuki.ren` → 404 (AVAILABLE).
- bcrypt hash (cost 10) of default persona password `katsklub2026` generated:
  `$2a$10$3Urva5tDqnzw5hEe24Wq5uJxaXT7p1.S9LCsY5Td6vQYSmeTlnOO6`
- New reusable script written + syntax-checked (`node --check` exit 0):
  `katsklub-backend/scripts/create_persona.js` (62 lines, mirrors
  `post_single_photo.js` conventions: dotenv, `Pool`, `optimizeImage` /
  `uploadBuffer` from `src/config/r2`, `bcryptjs`). Takes
  `--username --fullName --email --bio --location --imageUrl`, checks
  username/email uniqueness, uploads avatar, INSERTs user
  (`is_persona=TRUE`, `role_title='Member'`) + wallet (500.00).
- Script COMMITTED locally in the backend repo: commit `bcd7822`
  "Add create_persona.js VPS persona creation script", branch `master`,
  exactly 1 file. Nothing else staged/committed.
- Scratch cleaned: `persona_work/` (incl. node_modules), `pin_*.tmp.cjs`
  deleted. `git status` shows only the user's own pre-existing edits.

## 3. Persona record to create (values are FINAL)

- username: `itsuki.ren`
- email: `itsuki.ren@katsklub.top`
- full_name: `Itsuki Ren`
- bio: `lowkey lang 😎 | night drives & city lights 🚗✨`
- location: `BGC, Taguig`
- avatar_url: `https://media.katsklub.top/avatars/avatar-252fd86e-6209-46e4-a66c-cde2784292af-1789641113635.webp`
- password_hash: `$2a$10$3Urva5tDqnzw5hEe24Wq5uJxaXT7p1.S9LCsY5Td6vQYSmeTlnOO6`
- is_persona=TRUE, is_verified=false, role_title='Member'
- wallet: `coins_balance` = 500.00 (table `wallets` columns:
  `user_id UNIQUE`, `coins_balance NUMERIC(14,2)` — see
  `katsklub-backend/src/db/init.sql:174-180`)

## 4. TODO for you (other AI — you have the credentials)

Step A — push the commit (previous sandbox: schannel TLS fail, GCM blocked,
no TTY; should work in a normal terminal):
```powershell
cd C:\Users\Administrator\Desktop\katsklub-flutter-app\katsklub-backend
git push origin master
```

Step B — on the VPS (`ssh ubuntu@43.134.234.140`), pull + insert:
```bash
cd /home/ubuntu/katsklub-backend && git pull
set -a; source .env; set +a; psql "$DATABASE_URL" <<'SQL'
WITH new_user AS (
  INSERT INTO users (username, email, password_hash, full_name, bio, location, avatar_url, is_persona, is_verified, role_title)
  VALUES ('itsuki.ren','itsuki.ren@katsklub.top','$2a$10$3Urva5tDqnzw5hEe24Wq5uJxaXT7p1.S9LCsY5Td6vQYSmeTlnOO6','Itsuki Ren','lowkey lang 😎 | night drives & city lights 🚗✨','BGC, Taguig','https://media.katsklub.top/avatars/avatar-252fd86e-6209-46e4-a66c-cde2784292af-1789641113635.webp',TRUE,false,'Member')
  RETURNING id
)
INSERT INTO wallets (user_id, coins_balance)
SELECT id, 500.00 FROM new_user
RETURNING user_id, coins_balance;
SQL
```

Step C — verify: `GET https://katsklub.top/api/users/itsuki.ren` must be 200,
or `SELECT id, username, avatar_url FROM users WHERE username='itsuki.ren';`

## 5. Standing rules reminder (AGENTS.md)

- NEVER use `@jayriel` (ID 2), `@gemini` (48), `@ronaldo` (89) for bot actions.
  Personas only (`is_persona=TRUE`).
- Zero disk clutter: RAM buffer → R2, never `downloads/`.
- Cloud-only APK builds (GitHub Actions). No `flutter build apk` on VPS.
- Repo layout: this Windows folder's `katsklub-backend/` is a separate git
  repo (gitignored by the Flutter repo, remote
  `github.com/jenrielreyes2023-blip/katsklub-backend.git`). VPS backend lives
  at `/home/ubuntu/katsklub-backend`; VPS creds in `.vps_credentials.json`.
- For future members on the VPS, one command does everything:
  `node scripts/create_persona.js --username … --fullName "…" --email … --bio "…" --location "…" --imageUrl "…"`
  (needs VPS `node_modules` + `.env`; `gallery-dl -g <pin_url>` gives direct URLs there).

## 6. Environment lessons (if you ever work from THIS Windows sandbox)

- `npm install` needs `--cache <workspace-path> --registry=https://registry.npmjs.org/`
  (`package-lock.json` pins a dead Tencent mirror; default npm cache is unwritable).
- `@aws-sdk/client-s3` fails with EACCES here; SigV4-signed `fetch` PUT to
  `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com/<bucket>/<key>` works.
- `git` needs `-c safe.directory=…` (ownership) and `-c http.sslBackend=openssl`
  (schannel fails); push still needs interactive creds.
- `muse.search` does not index `katsklub-backend/`; use `Select-String` or
  `muse.read_file` for backend sources.
