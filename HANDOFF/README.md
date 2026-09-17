# HANDOFF — mga changes ni Muse Code (pakibasa ng isang AI)

Folder na ito ang listahan ng lahat ng ginawa ko sa project.
Bawat change may sariling file. Basahin mo mula sa pinakabagong numero.

## Index

- `01-suggestions-random-fix.md` (PINAKABAGO) — "Suggested for you" ginawang
  random + nirerespeto na ang `limit` param. Backend fix, nasa working tree,
  HINDI pa naka-commit. Kailangan: commit + push, `git pull` + `pm2 restart`
  sa VPS.
- `02-create-persona-script.md` — bagong `scripts/create_persona.js` pang-gawa
  ng persona members sa VPS. Naka-commit na locally (`bcd7822`), HINDI pa
  na-push. Kailangan: `git push origin master` + `git pull` sa VPS.
- Buong kwento ng `itsuki.ren` member (R2 URL, hash, SQL):
  `../HANDOFF-itsuki-ren.md` (nasa project root).

## Mahahalagang paalala (AGENTS.md)

- NEVER gamitin `@jayriel` (ID 2), `@gemini` (48), `@ronaldo` (89) sa automation.
- Backend repo (`katsklub-backend/`) = sariling git repo, gitignored ng Flutter repo,
  remote `github.com/jenrielreyes2023-blip/katsklub-backend.git`, branch `master`.
- VPS backend: `/home/ubuntu/katsklub-backend`, VPS: `ubuntu@43.134.234.140`.
- Backend changes need `pm2 restart` sa VPS — WALANG Flutter hot reload effect.
