# Teno Web preview 0.1.0

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
test account or test recording in the build. Existing API contracts and generation
prompts are unchanged. Backend 1.4.2 adds an owner-checked, read-only personal chat
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
