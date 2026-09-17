# 01 — "Suggested for you" ginawang random (PINAKABAGO)

## Reklamo ng user

Sa home feed, ang "Suggested for you" rail laging pareho ang laman —
nasa unahan lagi ang unang ginawang profiles. Dapat random bawat refresh.

## Root cause

Backend endpoint `GET /api/users/suggestions`, file:
`katsklub-backend/src/routes/users.js` line 429-444. Ang query:

```sql
SELECT * FROM users
WHERE id != COALESCE($1, 0)
ORDER BY id DESC LIMIT 10
```

Dalawang problema:
1. `ORDER BY id DESC` — deterministic, laging pinakabagong 10. Walang randomness.
2. Hardcoded `LIMIT 10` — dine-deadma ang `?limit=` param. Ang Flutter
   (`lib/services/feed_service.dart:2621-2622`,
   `_feedService.loadFollowSuggestions()` default limit 15, at
   `lib/screens/home_screen.dart:256-266` `_loadSuggestions()`) humihingi ng
   `limit=15` pero 10 lang ang bumabalik. Ang Flutter side nagre-render lang
   kung anong order ang ibigay ng backend (`home_screen.dart:1414-1430`,
   rail UI `1895-1972`) — walang client-side shuffle, kaya backend ang fix.

## Ginawang fix (working tree pa lang, HINDI naka-commit)

File: `katsklub-backend/src/routes/users.js`, lines 431-435. Buong handler ngayon:

```js
router.get('/users/suggestions', optionalAuth, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT * FROM users 
      WHERE id != COALESCE($1, 0)
      ORDER BY RANDOM() LIMIT $2
    `, [req.user?.id || 0, Math.min(Math.max(parseInt(req.query.limit || '10', 10) || 10, 1), 50)]);
```

Ibig sabihin:
- `ORDER BY RANDOM()` — ibang order bawat refresh (Postgres built-in, sapat na
  sa ~100 rows ng `users` table).
- `$2` = limit param: default 10 kapag wala, nirerespeto ang `limit=15`,
  naka-cap sa 50 kapag sobra (over-max safe), naka-clamp sa minimum 1
  (negative/garbage input hindi mag-500).
- `LIMIT $2` bilang query parameter ay valid sa `pg` driver (integer).
- Tandaan: `src/routes/users.js` ay CRLF line endings — kapag mag-eedit gamit
  ang file-edit tool, single-line edits lang ang reliable; multi-line match
  bumabagsak dahil sa `\r\n`.

## Verification na ginawa

- `node --check src/routes/users.js` → exit 0 (syntax OK).
- Backend WALANG test harness (walang test dir/script sa `package.json`),
  kaya live-API probe ang ginamit (scratch script, binura pagkatapos).
- One-pass probe sa prod (`https://katsklub.top/api/users/suggestions`,
  real DB) BAGO mag-deploy — baseline ng bug:
  - default call 1: 10 users, `itsuki.ren,jhay,katsklub,ronaldo,sumire.aoi,tsuki.emi,kotori.ane,himari.suzu,nanami.yori,shiori.kae`
  - default call 2: IDENTICAL order (SAME)
  - `?limit=15` call 1/2: 10 users pa rin (param ignored), IDENTICAL order (SAME)
  - `?limit=200`: 10 users, IDENTICAL order (SAME)
- Inaasahan PAGKATAPOS mag-deploy: default → 10 random; `?limit=15` → 15
  random; `?limit=200` → 50 random; magkasunod na calls → DIFFERENT order.

## Kailangang gawin (hindi kaya ng sandboxed AI — ikaw ang gumawa)

1. I-commit + push ang `katsklub-backend/src/routes/users.js`:
   ```powershell
   cd C:\Users\Administrator\Desktop\katsklub-flutter-app\katsklub-backend
   git add src/routes/users.js
   git commit -m "Randomize follow suggestions and honor limit param"
   git push origin master
   ```
2. Sa VPS (`ssh ubuntu@43.134.234.140`):
   ```bash
   cd /home/ubuntu/katsklub-backend && git pull
   pm2 list            # alamin ang backend process name
   pm2 restart <name>  # backend ito — HINDI sapat ang Flutter hot reload
   ```
3. Verify: `GET https://katsklub.top/api/users/suggestions?limit=15` nang
   dalawang beses — dapat 15 users at magkaibang order. O sa app: pull-to-refresh
   sa home feed, walang rebuild kailangan.

## Side observation (hindi ginalaw — desisyon ng user kailangan)

Kasama sa suggestions pati real accounts (`ronaldo`, `katsklub`, `jhay`),
hindi lang personas. Kung gusto ng user na personas lang, idagdag sa WHERE:
`AND is_persona = TRUE` — pero itanong muna sa user bago baguhin.
