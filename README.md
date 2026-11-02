# Teno Android 0.4.2

Native Android companion app for the JWD recorder, with live transcription, optional phone recording and team workspaces. Package: `com.teno.app`; version code: `7`. Release date: 2026-11-02.

Install `dist/Teno-0.4.2.apk` over the previous signed release. Do not uninstall to upgrade: uninstalling removes local recordings and device keys. This release uses the same signing certificate as 0.4.1 and is not debuggable. It requires Android 8 or newer; the user's target is Magic4 Pro / Magic UI 6.0 / Android 12.

## Version 0.4.2 recorder-first entry

The main **Record with device** button is now above the recording library and opens the recorder connection/control screen. An unconnected recorder goes through the existing scan, service verification and authorization flow; an authorized recorder exposes its recording controls. Opening this entry never starts the phone microphone or silently falls back to phone recording.

**Record with phone** is a smaller text link directly beneath the primary button, with a 48dp minimum tap height. Its setup page explicitly identifies the phone microphone and uses **Start phone recording**. During capture, the link becomes **Return to phone recording**. The Add content menu lists device recording first and keeps phone recording as an explicit choice.

Two API 35 emulator runs (411dp normal text; 360dp with 1.5 text scaling) passed 30 checks each and captured 20 screenshots. Checks cover primary/secondary hierarchy, both menu routes, no microphone permission request from the device entry, simulated connected/authorizing/recording device states, and actual emulator PCM capture, return and local WAV save. Eight relevant screenshots were visually inspected. Hardware states are test-only UI fixtures: no real Bluetooth or physical recorder acceptance is claimed. The signed release upgraded from 0.4.1 and cold-started to sign-in. See `verification/v0.4.2/recording-entry-review.html`; source and release checksums are in `dist/Teno-0.4.2-release-manifest.json`. Earlier navigation and cloud reports remain historical evidence.

## Version 0.4.1 navigation correction

Bottom navigation labels were left-aligned inside full-width views while their icons were centered. The shared personal/team component now centers each label beneath its icon, uses a consistent gap and grows with system text size. Folders, calendar and saved context also retain the appropriate active tab.

The earlier 0.4.0 screenshots covered selected team-audio flows, not a complete visual review of the app. The 0.4.1 correction added 14 navigation scenarios at three display settings: 411dp width with normal text, 411dp with 1.5 text scaling and 360dp with 1.5 text scaling. All 42 captures pass glyph alignment, visibility, spacing, selected-tab and click-destination checks. Visual review covers all 14 normal screenshots plus eight enlarged/compact screenshots. Evidence and before/after images are in `verification/v0.4.1/navigation-review.html` and its JSON reports.

Tests run against read-only synthetic loopback data in the isolated `com.teno.app.navigationverification` package, using the production view code. No fixture server, synthetic account or test runner is included in the release APK. The actual signed `com.teno.app` package was upgraded from 0.4.0 on the API 35 emulator and cold-started to the sign-in page. Release lint reports 0 errors and 59 warnings. No new backend or physical Magic4 Pro/JWD acceptance is claimed. Existing long content-button labels can still wrap awkwardly at enlarged text sizes; the navigation pass does not certify every dialog or content layout.

## Version 0.4 team audio

Open **Team → Meetings → Meeting audio**. Import a file, a saved phone/JWD recording, or an owned library recording; confirm that audio will be shared with the current team. The app retains the original and a private retry receipt. Upload progress uses a foreground service; retry sends the original file with the same client ID.

Processing status, authenticated playback, segment seeking and speaker confirmation use the shared backend. Keep unknown speakers in review, or explicitly confirm an external speaker. Automatic and human matches are distinct. Publication stays disabled until every identity is resolved and notes match the current transcript revision.

**Voice profiles** supports administrator enrollment and calibration and member self-revocation. Samples and embeddings remain on the server. The first historical calibration failed the conservative separation check, so initial profiles remain manual-review-only; Samuel also lacks an independent validation recording. No automatic name attribution is enabled for these profiles.

Historical 0.4.0 evidence: 17 Android flow checks on an API 35 emulator, 22 unchanged JWD protocol checks, signed 0.3 → 0.4 upgrade and cold start, release lint with no errors. See `verification/v0.4.0` and `dist/Teno-0.4.0-release-manifest.json`. These checks were not rerun as part of the 0.4.1 navigation correction. Physical Magic4 Pro/JWD, full English meetings and long microphone recordings are not certified by these checks. Earlier 0.3 reports below remain historical evidence.

## Interface and navigation

The app uses native views, neutral colors, rounded cards, Lucide line icons and plain English copy. There is no bundled mockup WebView, demo device or simulated cloud result. Source transcripts and user-authored content keep their original language. The design reference is `../design-review/20261101-v2-en/`; related design screens are implemented as pages, dialogs or sections rather than separate Android activities.

| Area | Available pages and flows |
|---|---|
| Getting started | Sign in, invitation activation, Android permissions, personal/team workspace selection |
| Library | Recording list, search, folders/tags, audio import, recording setup, live transcript, save/upload, processing states |
| Recording details | Audio playback, transcript editing, summary editing with versions, templates, mind map, attachments, export and sharing |
| Recorder | Service verification, connection and key authorization, live preview, verified file import, playback/upload, settings, key backup and button/reset help |
| Ask | Personal recording sources, saved context, conversations, citations; team published content and task queries |
| Tasks | Personal tasks/events, reminders and calendar import/export; team acceptance, progress, submission, independent review and activity |
| Team knowledge | Meeting/group-chat transcript import, speaker review, editable publication, decisions, opinions, questions, source versions, member invitations |
| Account | Language preferences, saved context, insights, briefs, message drafts, storage, trash, usage and server settings |

Design pages marked as future concepts remain outside this release. These include Wi-Fi/USB fast transfer, direct device-to-cloud upload, speaker vocabulary, audio editing, subscriptions, connectors and firmware maintenance. There is no automatic sending of messages, automatic speaker identity assignment, or fabricated recorder telemetry.

## Phone recording and Azure Speech

1. Choose the small **Record with phone** link, set a title and recognition language, then choose **Start phone recording**. Live transcription can be disabled.
2. `AudioRecord` captures 16 kHz mono PCM16. The foreground service writes a WAV file on the phone while `LiveTranscriber` sends PCM frames through the authenticated Teno WebSocket bridge to the server's Azure Speech SDK.
3. Confirmed segments and the current partial segment are displayed separately. Pause does not add silence or elapsed audio. Stop remains visible below the scrolling transcript.
4. **Stop and save** finalizes local audio and waits for the last recognition result. **Save and continue** uploads; **Keep on phone** leaves a local recording.
5. A completed live preview can be reused only if account, client ID, language, PCM byte count and SHA-256 all match the uploaded audio. Interrupted or mismatched previews fall back to a full-file transcription. One stable upload client ID prevents duplicate library recordings.

Azure and model keys remain on the server. The APK contains only business authentication tokens encrypted with Android Keystore. First use of 0.3 initializes generated output to English; **Account → Preferences** can select another summary language. Recognition language is independent of interface/output language.

Audio remains local if networking fails, the service is busy or recognition cannot finish. Interrupted capture metadata is recovered on return to the library where possible. This does not guarantee recovery from full storage, hardware failure or deletion by Android/the user. Phone WAV recording remains limited to 54 minutes. Imported files are limited to 120 minutes / 250 MiB. The S0 backend supports 2 realtime sessions, 1 Fast file task and 1 voice task independently. When realtime capacity is busy, local recording continues.

## JWD recorder behavior

Service verification, serial GATT operations, independent encrypted 16-character keys, timeouts, length/end-marker checks and CRC32 checks are retained from 0.2.1. Native vendor decoder files are unchanged. See `VENDOR-JWD.md`.

Live preview accepts fragmented fixed-80-byte Opus packets and decodes each to 320 PCM samples using the supplied vendor decoder. Live and file decoding share a lock because that decoder is a process-wide singleton. An invalid packet is reported rather than silently skipped. BLE file transfer remains unavailable during recording. There is no device pause command in this UI.

Device start/stop state follows acknowledged hardware messages. Disconnecting Bluetooth does not claim to stop the recorder. A live preview does not become an uploadable device recording: after stopping, import the complete original file through the existing integrity checks. Original device files are never deleted automatically.

Viewing a saved key requires Android screen-lock confirmation and uses a secure window. Reset help documents three quick presses followed by an approximately five-second hold, the conflicting completion-light descriptions, and the format/unbind consequence. The app does not issue reset/format commands.

Physical BLE streaming, the user's firmware format and Magic4 Pro behavior remain unverified. Synthetic Opus decoding is not physical-device acceptance.

## Team data and permissions

Native clients use their existing bearer access token with the deployed team API. Cookie clients keep their existing CSRF checks. Workspace membership and all task state transitions are checked server-side. Published records alone enter shared search; conversation histories are account-private.

Personal audio is not shared automatically when importing a transcript to a team. The native import preserves source timestamps when using an unchanged personal transcript. Dated group-chat lines accept `[YYYY-MM-DD HH:mm] Name: message`; structured segment JSON can preserve explicit IDs and timestamps. Editing an imported transcript retains its segment IDs and timestamps and creates a new version.

Task suggestions are editable, checked for duplicates and submitted as an atomic batch with a stable request ID. The assignee accepts and submits their work; a different designated reviewer approves it. Backend source and tests are in **`../teno-v1.1`**, the codebase that was verified against the deployed server. Do not deploy the older `../backend` tree over the current team service.

## Verification

`verification/v0.3.0/` contains reports and native screenshots:

- `backend-tests.txt`: 53 tests passed in the dedicated test database and Redis database, including live preview reuse, silent audio, ownership boundaries, summary-version conflicts and existing team regression checks.
- `v3-report.json`: 29 checks passed on an Android API 35 emulator. Real Azure partial/final recognition, a pause longer than 30 seconds, busy-state handling, exact-audio transcript reuse, upload deduplication, real summary generation, synthetic fragmented Opus decoding, team import and task review were exercised.
- `v3-polish-report.json`: 11 checks passed, covering English generated output, native summary editing, local message drafts, encrypted device keys, offline capture/save, fixed recording controls and reset help without device commands.
- Protocol tests: 22 checks passed for candidate names, independent keys, CRC32, framing, completeness and malformed input.
- Signed release installation over 0.2.1 and cold launch passed. Lint has zero errors; remaining warnings are recorded in the release manifest.

The microphone test captured emulator input. Speech-content acceptance used a clearly labeled synthetic English WAV, not the user's phone microphone. Device decoding used a synthetic Opus fixture on the emulator's ARM translation. The physical recorder, Magic4 Pro, Mandarin recognition quality, long sessions and manufacturer power management still require user testing.

Test APKs use `com.teno.app.v3verification` and are not included in the distributable APK. Existing test fixtures are not bundled in the release. Historical 0.2.x test reports and old UI test runners are not evidence for new layouts.

## Build

JDK 21, Gradle 8.11.1, Android Gradle Plugin 8.9.3, compile/target SDK 35. OkHttp 4.12.0 provides authenticated WebSocket transport; no GMS dependency is required.

```powershell
$env:JAVA_HOME='C:/Program Files/Android/Android Studio/jbr'
./gradlew.bat :app:assembleRelease :app:lintRelease
./gradlew.bat :app:assembleDebug :app:assembleDebugAndroidTest '-PverificationAppId=com.teno.app.v3verification' '-PtestRunner=com.teno.app.V3Instrumentation'
```

For isolated navigation screenshots, build with `-PverificationAppId=com.teno.app.navigationverification -PtestRunner=com.teno.app.NavigationInstrumentation` instead. Install the resulting debug and androidTest APKs only on the development emulator, then run `adb -s emulator-5554 shell am instrument -w com.teno.app.navigationverification.test/com.teno.app.NavigationInstrumentation`. This runner needs no cloud account and rejects other target package names. Set the emulator's display/font configuration before each run and restore it afterward. Always rebuild release without verification properties before packaging.

For recorder-entry checks, use `-PverificationAppId=com.teno.app.recordentryverification -PtestRunner=com.teno.app.RecordingEntryInstrumentation` and run that instrumentation in the corresponding `.test` package. It uses the same loopback fixture helper, starts with microphone permission denied, and later grants microphone access only inside the isolated emulator app for explicit phone capture. Device connection states are simulated inside androidTest; no device command is sent. This test never targets `com.teno.app`.

Release signing reads `~/.android/teno-signing.properties`. Do not copy signing credentials, account files, SSH keys, server `.env`, or the private root `AGENTS.md` into source archives. The source ZIP is created from an explicit allowlist.

Test runners require the existing protected internal test accounts to be copied into the isolated emulator app's private files and removed afterward. `V3Instrumentation` also requires `speech.wav` and `opus.raw` from the synthetic JWD verification fixtures. `V3PolishInstrumentation` reuses that runner's result IDs in the isolated acceptance workspace. Neither runner should target the user's physical installation.

The previous README is retained as `README-0.2.1-history.md` for historical evidence only. Installation notes for this release are in `RELEASE-0.4.2.txt`.
