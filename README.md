# Teno Android 0.6.1

Version **0.6.1 / 12** aligns existing features to verified PLAUD 4.x official references: Home and shifted sidebar, expandable Library, real statistics, combined search filters, recording/import/share sheets, transcript controls, templates, calendar, Chat and settings. Teno / Ask Teno, English, JWD priority, the original Android signer and existing accounts remain.

[80 independent page states](design-baseline/v0.6.1/index.html) · [Measured anchors and typography](design-baseline/v0.6.1/measurements.html) · [Retained differences and inferred states](design-baseline/v0.6.1/differences-and-acceptance.txt) · [Release and installation](RELEASE-0.6.1.txt)

Search uses folder subtrees, type, current-revision manually named speakers and local date ranges together, before pagination. Old servers retain their original search behavior and hide unsupported controls. Read-only backend 1.4.1 adds capability flags and complete counts without a schema migration, generation/prompt changes or business-data rewrites.

The reviewed APK is `dist/Teno-0.6.1.apk`. Install over the current Teno without uninstalling or clearing data. The same-signer release is distinct from GitHub CI build-verification APKs. Android-only feature release: no main merge, store submission, iOS delivery or baseline promotion. Magic4 Pro / JWD hardware acceptance remains pending.

Reproduce checks: `python scripts/flutter_check.py release-checks --version 0.6.1`, `python scripts/review_personal_pages.py --version 0.6.1`; package with `python scripts/package_mobile.py --android-only --version 0.6.1`. Native verification requires an explicitly selected dedicated emulator with the 0.6.0 baseline. Evidence is versioned; original 0.6.0 files remain preserved. Use `scripts/run_and_report.py` for development reporting.

The following releases and their evidence are retained for traceability.

# Teno Android 0.6.0

This release extends the existing Flutter/Java Android app with the approved PLAUD 4.x personal core. It keeps Teno / Ask Teno branding, English UI, the original `com.teno.app` signer and account/device/local-file isolation. Version code is 11. iOS remains at the separately confirmed 0.5.0 baseline; no iOS package is built here.

[0.6.0 page-by-page review](design-baseline/v0.6.0/index.html) · [Differences and acceptance](design-baseline/v0.6.0/differences-and-acceptance.txt) · [Release and installation](RELEASE-0.6.0.txt) · [Architecture](ARCHITECTURE.txt)

Import entry: Home → ＋ → Import files → From Files / From Photos. Android Share also accepts one or multiple files; sign in and explicitly accept pending shares into the current account. Each file is copied completely before queueing. Cloud processing defaults on only when its account key is missing; explicit off is retained. Historical unrequested local files do not upload automatically. Wi-Fi-only and durable retry policies apply.

Audio/video imports support MP3/M4A/WAV/AAC/FLAC/OGG/MP4/MOV/3GP/WEBM with real decoder validation, up to 120 minutes / 250 MiB. PDF/DOC/DOCX/PPTX/MSG documents are limited to 15 MB, UTF-8 TXT/MD to 2 MB, PNG/JPEG to 20 MB / 25MP. The compatible backend 1.4.0 performs local text extraction/OCR, preserves page/source references and exposes errors without deleting originals. Local processing protection limits are 200 pages / ten minutes / one million extracted characters.

The personal UI adds Upcoming/calendar association, typed library/search with matched timestamps/pages, nested folders, batch operations and drag destinations; original-preserving trim/merge; raw/edited/cleaned transcripts, per-recording speaker naming, real waveform/chapters/playback; multiple independent versioned notes and Teno templates; Chat with typed contexts, editable voice input, citations and saved answers; system calendar/manual/ICS import, themes, notifications, cache and optional system-credential App lock. Exports are content/format specific. Share links are explicit snapshots, default to summary only / seven days / no audio, and can be revoked.

The backend opt-in flag keeps old upload clients on their original pipeline. Explicit re-transcription from 0.6.0 opts an old recording into the personal pipeline; old summaries and transcript revisions remain. Team web, team prompts, profiles/tasks and daily automations are retained. Personal voiceprints, Agent/Work/Tasks/Skills/Routines/Connectors, billing/team/SSO are outside this release.

Packaging: `python scripts/package_mobile.py --android-only --version 0.6.0`. Version and evidence are independent of 0.5.0/iOS. Run checks through `scripts/run_and_report.py`. The private development build report does not promote a confirmed baseline. No store release or main-branch merge is performed. Physical Magic4 Pro/JWD acceptance remains pending; screenshots and emulator checks are identified separately.

The 0.5.0 implementation and evidence below are historical.

# Teno mobile 0.5.0

Teno uses one Flutter interface with Java and Swift runtimes for Android and iOS. The interface follows the approved 33-page reference dated 2026-11-04, with Teno / Ask Teno branding and English copy. It is implemented in Flutter widgets, not a WebView containing the design HTML.

Android keeps `com.teno.app`, version code `10`, the original signing certificate and existing local data formats. Install the locally signed APK over 0.4.4 without uninstalling. CI APKs are for build verification and cannot replace the originally signed installation. iOS starts at 0.5.0, build 10; its unsigned IPA requires local signing before installation.

[Architecture](ARCHITECTURE.txt) · [Individual page review](design-baseline/index.html) · [Validation and installation](RELEASE-0.5.0.txt) · [iPhone installation](ios/INSTALL.txt) · [Versioning](VERSIONING.txt)

## Current mobile scope

The sidebar contains Home, Library, Ask Teno, Tools and Settings. Tools exposes account templates. The main recording entry uses JWD; phone recording is a separate secondary choice. The app includes:

- Existing Teno account sign-in, token refresh and account-isolated local data.
- Recorder connection, key import/backup, acknowledged start/pause/resume/stop, complete-file sync and live preview.
- Phone recording, pause/resume, local WAV saving, recording notes and timestamp highlights.
- System audio import, durable uploads, retry with the same client ID and processing status.
- Recordings, folders/subfolders, search, native playback, seek and playback speed.
- Transcript segment editing with revision checks; summary generation, editing, templates and versions.
- Ask conversations, history, recording context selection and timestamp citations.
- Preferences, local file management, system audio/text export, trash and restore.

Work, Tasks, Routines, Skills, Connectors, photos, independent new notes, public links, team knowledge and voice-profile management have no mobile entry. Historical server data and the existing web application are retained. No backend routes or database migrations are introduced. Earlier Android feature lists remain historical evidence in Git and the versioned RELEASE files.

The design review records each reference page, evidence gaps and actual adaptations. Bulk selection/drag sorting, date/speaker filter combinations, calendar/Upcoming and a community template marketplace are not implemented in this first scope. System pickers, permission sheets and share panels use each OS. No device telemetry or transcript is fabricated in production.

## Repository layout

| Directory | Responsibility |
|---|---|
| `app/` | Existing Android host, Java services, native storage and tests |
| `shared-ui/lib/` | Flutter pages, state, API repositories and generated Dart bridge |
| `shared-ui/pigeons/runtime.dart` | Typed host commands, snapshots and state events |
| `ios/Teno/` | Swift app host, session, recorder, CoreBluetooth, media and upload queue |
| `ios/Vendor/` | Authorized Objective-C SDK and Opus framework, with provenance/hashes |
| `design-baseline/` | Separate page captures and traceability to the approved reference |
| `scripts/` | Secret audit, page review and packaging tools |
| `.github/workflows/mobile.yml` | Android/Linux and iOS/macOS build/test jobs |

Generated Flutter `.android` and `.ios` wrappers are disposable. They are not separate maintained hosts. The existing web and API remain in the sibling `../teno-v1.1` repository.

## Recording and data ownership

Native runtimes own audio, Bluetooth, files, authenticated HTTP, WebSocket and upload persistence. Dart receives state and text, never raw audio. Closing a page does not stop recording. Each platform has one session manager and serialized refresh. Account changes stop current uploads before replacing credentials; the original files and client IDs remain under their original account. Active recording or device transfer must finish first.

Recognition always sends `auto` (Automatic). Azure realtime results are preview only. The complete local file still enters the existing final transcription/summary pipeline. Summary language is separate. Azure and DeepSeek credentials are never client configuration.

JWD files require the declared length and OFF completion marker; CRC must match when supplied. Missing CRC is explicitly reported as length-only verification. Strict decoding rejects incomplete Opus frames. Device files are not automatically deleted. A Bluetooth disconnect means connection interrupted, not recording stopped. Reconnecting restores actual device state before further commands.

Android retains its SharedPreferences, Keystore aliases, encrypted device keys, file paths, recorder sync ledger and upload receipts. iOS stores device/session secrets in Keychain and private audio under Application Support. Import an existing recorder's original 16-character key when connecting from another phone; the app never silently resets the binding.

Phone PCM recording is limited to 54 minutes; general audio import to 120 minutes/250 MiB. JWD BLE sync retains the existing 60-minute/100-MiB limit. Local copies stay after successful upload. Temporary upload failures retry up to three attempts; manual retry reuses the client ID. Force-stopped apps must be reopened to resume app work; iOS background execution remains subject to OS scheduling.

## Pinned tools and builds

See `toolchain.json` and `shared-ui/pubspec.lock`. Flutter 3.47.9, Pigeon 29.1.0, Java 21, Gradle 9.1.0, AGP 9.0.1, Kotlin 2.2.20; Android min/compile/target = 26/36/35. iOS minimum 15, Xcode 16.4, XcodeGen 2.46.0, Swift 5 mode. Use the pinned Flutter release for generated contracts and native packages.

Windows Android build:

```powershell
$env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
$env:Path='C:/Users/lexia/AppData/Local/teno-tools/flutter/bin;'+$env:Path
Push-Location shared-ui
flutter pub get --enforce-lockfile
dart run pigeon --input pigeons/runtime.dart
dart format lib/platform/runtime.g.dart
flutter analyze --no-pub
flutter test --no-pub
Pop-Location
./gradlew.bat :app:assembleDebug :app:assembleRelease :app:lintRelease
```

Set the local Android SDK location in ignored `local.properties`. The existing private signing properties stay outside this repository. With no signing file, CI release builds are unsigned. Never copy signing credentials into source or CI.

macOS iOS build:

```sh
export DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer
cd shared-ui
flutter pub get --enforce-lockfile
flutter build swift-package --platform ios --no-codesign
cd ../ios
xcodegen generate
xcodebuild -project Teno.xcodeproj -scheme Teno -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

The workflow additionally runs simulator XCTest and packages `Payload/Teno.app` as an unsigned IPA. After launching the actual host, it waits for a screenshot containing Teno and Sign in; a successful process launch alone does not pass the screen check. No Apple account, provisioning profile or store submission is configured in CI. Windows installation is documented in `ios/INSTALL.txt`.

## Verification boundaries

`shared-ui/test` uses test-only fixtures. Set `TENO_SCREENSHOTS` to an output directory and `TENO_PLATFORM=ios` for the iOS widget variant; the default variant is Android. Each screenshot is one page. These renders verify layout/state and are not hardware screenshots. Large-text checks use 360 logical pixels at 1.5 text scale; standard checks use 390 × 844 with platform safe areas.

`app/src/crossPlatformTest` exercises upgrade/data retention and actual emulator phone capture using synthetic accounts/audio and a loopback service. The seed mode is only for a dedicated emulator running 0.4.4. It is never a user-device migration tool. The test APK is separate from the deliverable.

`ios/Tests` checks native WAV recovery, strict corrupt-file rejection, CRC, server URL validation and typed bridge errors. CI also launches the actual iOS host. Actual Magic4 Pro, iPhone, JWD firmware, long recordings, physical lock-screen behavior and AltStore signing require device acceptance. See the release record for completed checks; compilation does not certify hardware operation.

## Publication safeguards

Before pushing, scan the current files and all Git history. Local known provider credentials can be loaded privately for exact-value checks; the report emits only paths/rules, never values.

```powershell
python scripts/secret_audit.py --history --private-values ../../AGENTS.md
python scripts/secret_audit.py --artifact dist/Teno-0.5.0.apk
```

AGENTS files, environment files, accounts, private signing/SSH material, actual recordings, logs, databases and generated build folders are excluded. Source archives use Git's explicit tracked-file allowlist and are scanned again. Vendor files are unchanged, authorized dependencies: see `VENDOR-JWD.md`, `ios/VENDOR.txt` and their hash records. The software is an independent implementation; it does not call PLAUD or Pocket private services.


Private development roadmap and build reporting: [scripts/DEVELOPMENT-REPORTING.txt](scripts/DEVELOPMENT-REPORTING.txt).
