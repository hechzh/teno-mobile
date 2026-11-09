# Teno Web 0.2.1 candidate

Startup recovery and static delivery update; the shared interface remains 0.7.0.
See [startup release notes](RELEASE-0.2.1.txt). Startup displays download, engine/font
and first-frame stages, with a slow-network hint after 15 seconds, recovery controls
after 45 seconds, and immediate errors for failed scripts. It never clears retained
imports or login data. Diagnostics are copied locally on request and contain only
static resource paths/timings, without query strings, account data or recording content.

`prepare_web_assets.py` puts compiled code, fonts and rendering assets under a
content-derived `_static/<hash>/` path. Run it after every release build; it also
precompresses resources with Brotli/gzip using Node. The deployment retains these
immutable directories in `/srv/static`; entry HTML/bootstrap/release metadata still
revalidate. Missing assets return 404. No service worker or offline-app claim is added.
The initial visit still needs a network download; cache reuse applies after a
successful download. A nearby static delivery region/CDN remains an infrastructure
option if the user's network path to the existing server is slow.

# Teno Web 0.2.0 candidate history

Uses shared UI base 0.7.0, with Chinese/English/system language, MVP styling and responsive layouts. See [candidate release notes](RELEASE-0.2.0.txt). The production `/app/` remains on 0.1.3 until real iPhone Safari acceptance; the candidate uses its own entry. Existing cache, accounts, API and prompts remain.

Previous deployed release history follows.

# Teno Web preview 0.1.3

The browser application reuses `../shared-ui` from Android 0.6.2. It has its own
entry point, browser runtime, build, CI job and deployment. Android's package,
version, native runtime, recorder, keys and upload queue are not changed.

The deployed entry is `https://54-214-180-183.sslip.io/app/`. Sign in with an
existing Teno account. The library and generated content belong to that account
and are shared with the installed app. No additional ChatGPT account is needed.

Supported: home/library/folders/search and pagination, file import, transcripts,
speaker labels, audio playback and seeking, summary notes/templates, Ask with
source references and chat history, file download/export, account preferences.
Hardware recording, phone microphone recording, dictation, system calendar,
Android app lock/notifications and incoming native share intents are omitted.

## Recording notes

Web 0.1.3 supports evidence-linked narrative notes (`personal-notes-v2`). The short
overview stays above the topic directory; each topic opens its complete saved prose,
including proposal, confirmation and uncertainty labels. The compatibility body and
transcript excerpts are not repeated below those chapters. Copy and edit preserve
the overview, full prose, key points and next steps. Saved versions retain their
original wording and overview. Legacy notes keep their existing presentation; an
incomplete chapter structure falls back to the saved full body.

This client does not generate or infer note content. The separately deployed personal
Notes pipeline supplies the new structure. Android 0.6.2 remains the UI base, and this
release does not replace an installed Android or iOS package.

Web 0.1.1 applies the approved Notes V1 design to recording details: Notes and
Transcript tabs, a sage overview, a real chapter directory, note selection,
direct editing, saved versions, copy/export, and a fixed audio/Ask bar. The audio
bar opens the existing seek/speed controls. Share retains the existing content
selection and revocation behavior.

Content comes from the existing APIs. No additional model call is made to fill
the layout. Chapters use the saved note's actual titles; transcript excerpts are
shown only when the source ID and transcript revision match. Older notes keep
their stale/source indicators. Manual notes without chapters do not show a fake
directory, and identical summary/body text appears once. A privacy label appears
only after share state is successfully retrieved. The displayed waveform comes
from the existing audio API; unavailable peaks remain an unfilled progress line.

This presentation is enabled only by `webExperience`. Native recording details
keep their previous layout. Light/dark and 360dp enlarged-text layouts are covered
by automated tests; actual iPhone Safari acceptance remains a device test.

## Recording read cache

Web 0.1.2 first displays an account-scoped saved recording, transcript, notes and
waveform, then refreshes the content from the existing API in the background.
Saved data is labelled while checking or when a connection fails. Every entry
is revalidated on opening; a denied/deleted recording is removed from view.
Transcript variants are separate. Unchanged recording revisions reuse waveform
peaks, avoiding repeated server-side decoding of long recordings.

IndexedDB retains up to 24 recent recording/variant snapshots, 8 MiB total, for
at most seven days. Memory caching still works if storage is disabled or full.
This is disposable read data, separate from retained imports; it contains no
credentials or audio files. Logout, account changes, explicit cache clearing,
and successful or ambiguous write requests invalidate read data. Other open
tabs receive invalidation notices when BroadcastChannel is available. A late
cache read or request from an old account cannot overwrite current content.

Initial visits still need network loading and first-time waveform computation.
This does not cache model requests, rerun transcription on opening, or create an
offline login/library. Generated results already persist on the server.

## Import behavior

Choose Home → + → Import files. Files are first staged in IndexedDB under the
signed-in account. Select **Upload and process** to confirm that account and send
the file. Keep the tab open until the upload finishes. Processing then continues
on the existing server. The browser never changes Android's cloud-upload setting.

After a network interruption or page reload, open Library → My files → Browser
imports and retry. The original upload ID and bytes are reused. Cancelled requests
may already have reached the server; retry reconciles the same ID. Browser storage
can be cleared or evicted, so keep the original file. This is not an offline or
background-upload replacement for the installed app.

Audio/video: 120 minutes / 250 MiB (duration enforced by the server). PNG/JPEG:
20 MB. PDF/DOC/DOCX/PPTX/MSG: 15 MB. TXT/MD: 2 MB. Up to 20 files per selection.
Use unencrypted documents. Safari playback may require a second Play tap after
the authenticated audio finishes loading; errors are displayed in the player.

## Architecture and account safety

`lib/web_runtime.dart` implements the existing RuntimeHost interface; `web/runtime.js`
owns same-origin authenticated HTTP, serialized token refresh, browser imports,
downloads and playback. Tokens stay in tab session storage, passwords are never
persisted, requests omit cookies and only target `/api/v1/` on the same origin.
Account changes reject stale results, abort uploads and revoke in-memory audio URLs.
The shared `webExperience` flag defaults to false. It is set only by this entry point.

Static assets (including Inter and Noto Sans SC) are self-hosted. No generated
service worker caches account/API responses. There is no provider key, recorder key,
test account or test recording in the build. Existing API contracts remain compatible;
personal generation changes are released separately on the backend. Backend 1.4.2
adds an owner-checked, read-only personal chat
history endpoint for typed sources; only Web uses this new read path. Android keeps
its existing endpoint. The gateway routes only `/app/` to a separate static container.

## Build and verification

Use the repository's Flutter 3.47.9 SDK and Node 22 or later:

```text
cd shared-ui
flutter pub get --enforce-lockfile
flutter test --no-pub
cd ../web-client
flutter pub get --enforce-lockfile
node --test test/runtime.test.cjs
flutter analyze --no-pub
flutter build web --release --base-href /app/ --no-web-resources-cdn
```

`scripts/preview.py` serves a loopback preview and forwards the existing API without
logging request bodies or tokens. Browser verification uses the real backend and
explicitly named synthetic acceptance files. Chromium mobile viewport checks and
Flutter tests do not establish actual iPhone Safari acceptance.

## Deployment and rollback

Package `build/web` with the files in `deploy/` (the `/deploy` URL is blocked).
Upload the archive to the existing host, then run `scripts/deploy.sh RELEASE ARCHIVE`.
The script backs up the gateway configuration and backend Git bundle, creates an
independent capped static container, and reloads Caddy. It does not restart the API,
workers, database or Redis, and performs no migration or data-volume deletion.
If an older gateway bind mount still references a replaced configuration file,
the script validates the current file and recreates only the gateway to refresh
that mount. This may cause a brief connection retry. Backend 1.4.2 is deployed
separately after isolation tests and a verified backup restore; only its API
container needs replacing, with workers and their generation behavior preserved.

To roll back, point `/opt/teno-web-preview/current` to the previous retained release,
or restore the backed-up gateway Caddyfile and reload Caddy to remove `/app/`.
Keep data volumes, all backend migrations and Android release artifacts intact.

Create the Web distribution and source archives with `python scripts/package.py`.
The version is read from this app's pubspec and never overwrites an Android APK.
