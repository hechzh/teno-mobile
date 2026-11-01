# Teno Android 0.3.0

Native Android implementation of the English V2 design, with live transcription and team workspaces. Package: `com.teno.app`; version code: `4`. Release date: 2026-11-01.

Install `dist/Teno-0.3.0.apk` over the previous signed release. Do not uninstall to upgrade: uninstalling removes local recordings and device keys. This release uses the same signing certificate as 0.2.1 and is not debuggable. It requires Android 8 or newer; the user's target is Magic4 Pro / Magic UI 6.0 / Android 12.

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

1. Choose **Start recording**, a title and recognition language. Live transcription can be disabled.
2. `AudioRecord` captures 16 kHz mono PCM16. The foreground service writes a WAV file on the phone while `LiveTranscriber` sends PCM frames through the authenticated Teno WebSocket bridge to the server's Azure Speech SDK.
3. Confirmed segments and the current partial segment are displayed separately. Pause does not add silence or elapsed audio. Stop remains visible below the scrolling transcript.
4. **Stop and save** finalizes local audio and waits for the last recognition result. **Save and continue** uploads; **Keep on phone** leaves a local recording.
5. A completed live preview can be reused only if account, client ID, language, PCM byte count and SHA-256 all match the uploaded audio. Interrupted or mismatched previews fall back to a full-file transcription. One stable upload client ID prevents duplicate library recordings.

Azure and model keys remain on the server. The APK contains only business authentication tokens encrypted with Android Keystore. First use of 0.3 initializes generated output to English; **Account → Preferences** can select another summary language. Recognition language is independent of interface/output language.

Audio remains local if networking fails, the service is busy or recognition cannot finish. Interrupted capture metadata is recovered on return to the library where possible. This does not guarantee recovery from full storage, hardware failure or deletion by Android/the user. Phone WAV recording is limited to approximately 54 minutes to stay below the 100 MiB upload cap. Imported files are limited to 60 minutes / 100 MiB. The current Azure F0 configuration admits one recognition session at a time.

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

Release signing reads `~/.android/teno-signing.properties`. Do not copy signing credentials, account files, SSH keys, server `.env`, or the private root `AGENTS.md` into source archives. The source ZIP is created from an explicit allowlist.

Test runners require the existing protected internal test accounts to be copied into the isolated emulator app's private files and removed afterward. `V3Instrumentation` also requires `speech.wav` and `opus.raw` from the synthetic JWD verification fixtures. `V3PolishInstrumentation` reuses that runner's result IDs in the isolated acceptance workspace. Neither runner should target the user's physical installation.

The previous README is retained as `README-0.2.1-history.md` for historical evidence only. Installation notes for this release are in `RELEASE-0.3.0.txt`.
