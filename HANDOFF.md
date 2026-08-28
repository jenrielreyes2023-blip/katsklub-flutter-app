# KatsKlub Flutter — Cloud Build & Analyze Handoff

**Date:** 2026-08-28
**Status:** Active

## 1. Build Strategy — Cloud Only (No Local APK Build)

- **Hindi na nagbi-build ng APK sa local/VPS.**
- Lahat ng APK build ay sa **GitHub Actions** lang (`Build Flutter Android APK`).
- Workflow file: `.github/workflows/build-android.yml`
- Trigger: `push` sa `main` at `feature/**` + manual `workflow_dispatch`
- Build command sa cloud:
  ```
  flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
  ```
- Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Deploy: auto-upload via `actions/upload-artifact` + `curl POST https://katsklub.top/api/admin/deploy-apk`

## 2. Analyze — Nasa GitHub Na Lahat

- **No local `flutter analyze` needed.**
- Analyze step ay nasa workflow mismo, after `flutter pub get`:
  ```yaml
  - name: Analyze code
    run: flutter analyze
  ```
- Pag may analyze error, babagsak agad ang workflow at hindi tutuloy sa build — tipid sa oras.
- Dagdag oras lang ng analyze: ~20-40 seconds sa total na ~4-5 mins build time.

## 3. Local Flutter SDK sa VPS (`/home/ubuntu/flutter`)

- Naka-install pa rin ang Flutter SDK `3.47.1` sa VPS (1.6GB) sa `/home/ubuntu/flutter`.
- **Hindi na ginagamit pang-build ng APK.**
- Nananatili lang for optional local checks kung kailangan (e.g. `flutter pub get`, `dart analyze` via SSH).
- Kung puro cloud workflow lang ang gamit, safe na hindi galawin — hindi nakakaapekto sa GitHub build.
- GitHub Actions uses sarili nitong SDK via `subosito/flutter-action@v2` (cached sa `/opt/hostedtoolcache/flutter`).

## 4. Git Workflow

- Lahat ng changes ay `push` sa `main` → auto-trigger ng cloud build + analyze.
- Walang local `flutter build apk` na kailangan patakbuhin.
- APK ay makukuha sa GitHub Artifacts at auto-deploy sa `https://katsklub.top/katsklub-latest.apk`.

## 5. Para sa Susunod na AI/Dev

- Huwag ibalik ang local build process — cloud only na.
- Kung magdagdag ng bagong check (tests, lints), idagdag sa workflow as separate step bago mag-build.
- Old handoff files (`handoff.txt`, `handoff_v2.txt`, `handoff_v3.txt`, `codebase-explanation.txt`, `CLAUDE.md`) ay nasa `.gitignore` na at hindi na tracked — nananatili lang locally kung meron pa.

