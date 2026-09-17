# 04 — Post page walang blue mentions + mention regex walang dot-support

## Reklamo ng user

Sa comments modal may blue mentions, pero sa post page walang blue na mentions.
"Parang may absence yung postpage."

## Findings (verified sa code — 2 magkahiwalay na gaps)

### Gap A (CONFIRMED, sagot sa reklamo): sponsored cards = plain Text

`lib/widgets/post_card.dart`, `_buildPromotionCard` (line 863), lines 1017-1021:

```dart
if (_post.text.isNotEmpty)
  Text(
    _post.text,
    style: KatsText.postBody(context),
  ),
```

Plain `Text` — WALANG `HashtagText`, kaya kahit anong `@mention` o `#hashtag`
sa sponsored/promotion cards ay plain text. Ang main feed cards
(`post_card.dart:2383/2398`), post detail (`ExpandablePostText`), at comments
modal (`HashtagText`) ay may mention support — kaya "may absence" lang ang
promo cards. (Hindi pa inaayos — kailangan ng multi-line edit; detalye sa ibaba.)

### Gap B (CONFIRMED, apektado LAHAT ng screens): mention regex walang tuldok

`lib/widgets/hashtag_text.dart` — ang mention pattern `@([\p{L}\p{N}_]+)` ay
hindi kasama ang `.`, pero ang house-standard usernames ay may tuldok
(`itsuki.ren`, `yume.aiko`)! Resulta: `@itsuki.ren` → blue lang ang `@itsuki`,
plain ang `.ren`, AT pag tinap, maling profile (`itsuki`) ang binubuksan.
NAayos na (2 single-line edits, lines 117/121):

```dart
r'@([\p{L}\p{N}_]+(?:\.[\p{L}\p{N}_]+)*)'
```

Walang leading/trailing dot (`@ronaldo.` → mention `@ronaldo` lang).
Hashtag pattern hindi ginalaw.

### Bonus finding sa `buildHashtagTextSpans` (by design, huwag baguhin)

Line 172: `else if (mentionMatch != null && onMentionTap != null)` — ang
mention ay blue LANG kapag may `onMentionTap`. Kung walang handler, plain text
siya. Ito ang dahilan kung bakit tahimik na nawawala ang highlights sa mga
widget na walang handler — tandaan sa mga susunod na UI.

## Nagawa na (Muse Code, working tree)

- `lib/widgets/hashtag_text.dart` lines 117, 121 — dotted-mention regex.
- `test/hashtag_text_test.dart` (BAGO, flutter_test convention gaya ng
  `test/auth_service_test.dart`) — 4 tests: dotted mention full-span + tap
  target, trailing dot excluded, plain kapag walang handler, hashtag unaffected.
- Test run: HINDI tumakbo sa sandbox (`flutter test` 2× na-stuck 30min na walang
  output, pati `flutter --version` timeout — Flutter CLI hindi usable doon).
  I-run sa dev machine/CI: `flutter test test/hashtag_text_test.dart`.
- Pattern semantics na-verify via independent check (JS /u transliteration ng
  exact patterns): `@itsuki.ren` OLD→`@itsuki`/`itsuki` (sirang tap target),
  NEW→`@itsuki.ren`/`itsuki.ren`; `@ronaldo.` trailing dot excluded;
  `@ronaldo` unchanged; `#manila` unaffected; `@x.y.z` full match.

## Kailangang gawin (isang AI na kayang mag multi-line edit, o manual)

Sa `lib/widgets/post_card.dart`, `_buildPromotionCard`, palitan lines 1017-1021 ng:

```dart
if (_post.text.isNotEmpty)
  HashtagText(
    text: _post.text,
    style: KatsText.postBody(context),
    onHashtagTap: (_) {},
    onMentionTap: (username) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(username: username),
        ),
      );
    },
  ),
```

plus imports (TSEKIN: walang cycle — `user_profile_screen.dart` hindi
nag-iimport ng `post_card.dart`; sundin ang precedent ng
`expandable_post_text.dart:4-5`; huwag i-import ang `hashtag_screen.dart`
dahil NAG-IIMPORT ito ng `post_card.dart` (line 10) — cycle! kaya no-op ang
hashtag tap, gaya ng `post_detail_screen.dart:4452`):

```dart
import 'hashtag_text.dart';
import '../screens/user_profile_screen.dart';
```

Dahilan kung bakit hindi ginawa ng sandboxed AI: ang repo files ay CRLF at
ang file-edit tool ay single-line matches lang ang kaya — ang 5-line swap ay
hindi ma-match. Pure Dart ito kaya hot-reloadable (`r` lang sa `flutter run`).

## Paano i-verify (hot reload, walang rebuild)

1. `r` sa flutter run.
2. Magbukas ng post na may `@dotted.name` (hal. `@itsuki.ren`) sa feed/post
   detail → buong mention blue; tap → tamang profile (hindi 404).
3. Pagkatapos ng promo-card fix: sponsored card na may `@mention` → blue na rin.
