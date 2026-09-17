# 03 — Reply mention nagpapakita ng maling pangalan (PINAKABAGO)

## Reklamo ng user

Sa comments modal: nag-comment ang user sa post ni ronaldo (parent = user),
nag-reply si ronaldo, tapos nag-reply ang user SA reply ni ronaldo. Ang input
box tama ("Replying to ronaldo"), pero pagka-post, ang pangalan NG USER ang
lumabas sa mention prefix imbes na "ronaldo".

## Root cause (backend, hindi Flutter)

- Flutter tama ang pasa: `_startReplyToReply` (`lib/widgets/comments_modal.dart:390`)
  nagpapadala ng `parentCommentId` = top-level parent (comment ng user!) +
  `replyToUserId` = authorId ni ronaldo, via `FeedService.createComment`
  (`lib/services/feed_service.dart:1710`). Ang UI (`_ReplyTile`, lines 1343-1352)
  nagre-render ng `replyToFullName` prefix — model OK (`post_comment.dart:81-86`).
- Backend `POST /api/posts/:id/comments` at `POST /api/posts/:id/slides/:slideId/comments`
  (`katsklub-backend/src/routes/posts.js`) kinuha ang `replyToUsername/FullName
  LAGI mula sa PARENT comment author, binalewala ang `replyToUserId`. Kaya sa
  nested reply, sariling pangalan ng user ang binalik ng API.
- Dagdag: ang `post_comments` table WALANG column para sa reply target, kaya
  pagka-reload, `GET /api/comments/:id/replies` parent name din ang pinapakita.

## Ginawang fix (working tree, HINDI naka-commit — 3 files)

1. `katsklub-backend/src/db/init.sql` — bagong column sa `post_comments`:
   `reply_to_user_id INT REFERENCES users(id) ON DELETE SET NULL`
   (para sa fresh installs).
2. `katsklub-backend/src/routes/admin.js` (`initAdminTables`, tumatakbo kada boot,
   gaya ng `is_sensitive` precedent) — `ALTER TABLE post_comments ADD COLUMN
   IF NOT EXISTS reply_to_user_id ...` (para sa existing VPS DB nang walang
   manual migrate).
3. `katsklub-backend/src/routes/posts.js`:
   - BOTH POST handlers: kapag may `replyToUserId`, i-lookup ang user na yun
     para sa `replyToUsername/FullName` (override sa parent fallback); i-persist
     sa `reply_to_user_id` via fail-safe UPDATE (`... AND EXISTS (SELECT 1 FROM
     users WHERE id = $1)` — hindi mag-500 kahit stale ang id).
   - `GET /api/comments/:id/replies`: `LEFT JOIN users ru ON ru.id =
     COALESCE(c.reply_to_user_id, pc.user_id)` — reload-safe, old rows
     bumabagsak sa dating parent-name behavior.
   - Walang Flutter changes na kailangan (app na nagpapadala/nagre-render nang tama).

## Verification

- `node --check src/routes/posts.js` → 0, `node --check src/routes/admin.js` → 0.
- Full `git diff` nirebyu: 3 files, +34/-6, walang nadamay, walang naiwang
  experiment artifacts (isang maling object-spread edit sa slides handler ang
  na-revert bago matapos).
- Backend WALANG test harness (walang test dir/script sa `package.json`) kaya
  walang committed test — disclosed per repo convention.
- Live test KAILANGAN ng deploy (hindi kaya ng sandboxed AI). Pagka-deploy:
  1. Mag-reply sa nested reply → dapat pangalan ng target (ronaldo) ang prefix.
  2. I-reload ang thread → dapat nandoon pa rin ang pangalan (persistence check).

## Kailangang gawin

1. I-commit + push: `src/routes/posts.js`, `src/routes/admin.js`, `src/db/init.sql`
   (backend repo, branch `master`).
2. Sa VPS: `git pull` + `pm2 restart` ng backend (HINDI sapat ang Flutter hot reload).
3. Tandaan: unang `pm2 restart` PAGKATAPOS ng pull ang nag-aapply ng
   `reply_to_user_id` column (via `initAdminTables` sa boot).
