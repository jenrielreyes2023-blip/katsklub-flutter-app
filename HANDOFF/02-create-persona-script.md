# 02 — `scripts/create_persona.js` (bagong reusable script)

## Ano ito

62-line Node script pang-gawa ng isang persona member mula sa direct image URL,
para takbuhin SA VPS (isang command lang: fetch → optimize → R2 → DB insert).
Sinulat kasabay ng `itsuki.ren` task. Style = gaya ng ibang backend scripts
(`post_single_photo.js`): dotenv, `Pool`, `optimizeImage`/`uploadBuffer` mula
`src/config/r2`, `bcryptjs`. `node --check` pasado.

File: `katsklub-backend/scripts/create_persona.js`

Gamit sa VPS:
```bash
cd /home/ubuntu/katsklub-backend
node scripts/create_persona.js --username <u> --fullName "<N>" --email <e> --bio "<b>" --location "<l>" --imageUrl "<pinimg url>"
```

## Status: NAKA-COMMIT NA locally, HINDI pa na-push

- Commit `bcd7822` "Add create_persona.js VPS persona creation script",
  branch `master`, exactly 1 file.
- Kailangan: `git push origin master` (Windows terminal ng user —
  hindi kaya ng sandboxed AI: schannel TLS fail + walang credentials),
  tapos `git pull` sa VPS.

## Kaugnay na tapos na gawain (konteksto lang)

- `itsuki.ren` member: avatar uploaded + VERIFIED LIVE sa R2
  (`https://media.katsklub.top/avatars/avatar-252fd86e-6209-46e4-a66c-cde2784292af-1789641113635.webp`,
  HTTP 200 / image/webp / 19924 B). Ang DB INSERT na lang ang kulang —
  eksaktong SQL + values nasa `../HANDOFF-itsuki-ren.md` (project root).
  Sa pinakahuling live check, si `itsuki.ren` lumalabas na sa suggestions API,
  kaya mukhang na-insert na ng isang AI — i-verify na lang
  (`GET https://katsklub.top/api/users/itsuki.ren` = 200).
