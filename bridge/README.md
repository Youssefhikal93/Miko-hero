# Iam-hero local PC bridge

Private, **local-only** HTTP bridge service for the "Iam - hero" children's
storybook app. It runs on the family PC, owns the master library (SQLite +
folders), pairs companion mobile devices with short-lived pairing codes and
256-bit bearer tokens, reports the health of its local dependencies, generates
stories with a local Ollama model, synchronizes them to every paired device,
deletes them everywhere on request, and writes password-encrypted backups of
the whole library. Illustration generation (ComfyUI) follows in a later
milestone.

> ## ⚠️ Never expose this service to the internet
>
> The bridge has no TLS, no accounts, and no hardening against hostile
> traffic. It is designed for a trusted home network only.
> **Never port-forward it on your router, never expose it via a tunnel or
> reverse proxy to the public internet.** By default it binds to
> `127.0.0.1` and is unreachable from other machines; change `bindAddress`
> only if you understand the consequences.

## Requirements

- [Dart SDK](https://dart.dev) 3.12 or newer (`sdk: ^3.12.2`)
- Optional: a local [Ollama](https://ollama.com) server with the configured
  model pulled, and a local ComfyUI install — both are probed for `/health`
  only; the bridge works without them.

## Configuration

The bridge loads one JSON configuration file, resolved in this order:

1. `--config <path>` command-line argument,
2. the `IAM_HERO_BRIDGE_CONFIG` environment variable,
3. `bridge_config.json` in the current working directory.

If the file does not exist it is created with defaults and its location is
printed. All machine-specific values live in this file; nothing is hardcoded.

| Field           | Default                 | Meaning                                   |
| --------------- | ----------------------- | ----------------------------------------- |
| `bindAddress`   | `127.0.0.1`             | Interface the HTTP server binds to        |
| `port`          | `8765`                  | TCP port of the HTTP server               |
| `libraryPath`   | `<cwd>/iam_hero_library`| Root folder of the master library         |
| `ollamaBaseUrl` | `http://127.0.0.1:11434`| Base URL of the local Ollama API          |
| `comfyUiBaseUrl`| `http://127.0.0.1:8188` | Base URL of the local ComfyUI API         |
| `ollamaModel`   | `gemma3:4b`             | Ollama model tag used for stories         |
| `generationTimeoutSeconds` | `600`        | Budget for one generation call (30–3600)  |
| `maxGenerationAttempts`    | `3`          | Attempts per job, first try included (1–5)|
| `allowedWebOrigins` | `[]`             | Extra web origins allowed to call the bridge from a browser (CORS). Loopback origins (`localhost`, `127.0.0.1`, any port) are always allowed; list LAN origins such as `http://192.168.1.20:8765` explicitly. Never list a public internet origin. |

Example `bridge_config.json`:

```json
{
  "bindAddress": "192.168.1.20",
  "port": 8765,
  "libraryPath": "D:/FamilyData/iam_hero_library",
  "ollamaBaseUrl": "http://127.0.0.1:11434",
  "comfyUiBaseUrl": "http://127.0.0.1:8188",
  "ollamaModel": "gemma3:4b",
  "generationTimeoutSeconds": 600,
  "maxGenerationAttempts": 3,
  "allowedWebOrigins": []
}
```

`bridge_config.json` is listed in this package's `.gitignore`; real configs
with machine-specific paths must never be committed.

## Start / stop

```powershell
cd bridge
dart pub get
dart run bin/iam_hero_bridge.dart            # default config discovery
dart run bin/iam_hero_bridge.dart --config D:\path\to\bridge_config.json
```

On startup the bridge creates the master library skeleton
(`db/`, `photos/`, `illustrations/`, `exports/`, `db/master.db`) if missing,
prints the config location, then listens. Stop with `Ctrl+C` (SIGINT);
the process closes the socket and database cleanly.

## Endpoints

All requests and responses are JSON. Errors use the typed envelope
`{"error": {"code": "...", "message": "..."}}`.

### `GET /health` — no auth

Returns bridge version, uptime, and dependency statuses:

```json
{
  "version": "0.1.0",
  "uptimeSeconds": 12.4,
  "statuses": {
    "ollama":  {"available": true,  "detail": "Ollama ready with gemma3:4b."},
    "comfyui": {"available": false, "detail": "ComfyUI unreachable."},
    "library": {"available": true,  "detail": "Database open and folders writable."}
  }
}
```

Probe timeouts are capped at 3 s each; probe failures never crash the
server. ComfyUI reporting unavailable is expected until it is installed.

### `POST /pair/request` — no auth

Rate-limited to 5 pending requests per rolling minute (`429 rate_limited`
beyond that). Prints `Pairing code: XXXXXX — expires in 2 minutes` on the PC
console — the code's single deliberate appearance anywhere — and responds:

```json
{ "pairingId": "b6c1..." }
```

The pairing code itself is never sent over HTTP and never stored in
plaintext (only its SHA-256 digest is kept in memory).

### `POST /pair/confirm` — no auth

Body: `{"pairingId": "...", "code": "123456", "deviceName": "Family tablet"}`

On success registers the device and returns a one-time 256-bit token:

```json
{ "deviceToken": "..." }
```

Store this token on the device; it cannot be retrieved again.

Failure modes: unknown/expired/invalidated pairings return `404
pairing_not_found`, `410 pairing_expired`, or `403 invalid_pairing_code`.
**Five wrong attempts invalidate the pending pairing**, so even the correct
code stops working and a fresh request is needed.

### `GET /devices` — requires auth

Requires `Authorization: Bearer <deviceToken>`. Lists paired devices
(name + created date only — never tokens):

```json
{ "devices": [ { "id": "...", "name": "Family tablet", "createdAtUtc": "2026-08-22T10:00:00Z" } ] }
```

Every endpoint except `/health`, `/pair/request`, and `/pair/confirm`
requires a valid bearer token; anything else gets `401 unauthorized`.

### `POST /stories/generate` — requires auth

Queues one story generation job. Body:

```json
{
  "profileId": "profile-1",
  "heroName": "Nour",
  "ageYears": 6,
  "genderContext": "girl",
  "languageCode": "ar",
  "theme": "A lantern festival by the sea",
  "moral": "Sharing a small light makes it bigger",
  "pageCount": 6,
  "illustrationStyle": "pictureBook"
}
```

Every field is required. `genderContext` is `girl` or `boy` (the app's
unspecified state never reaches here), `languageCode` is `ar`, `en`, `sv`
or `so`, `pageCount` is `6`, `8` or `10`, and `illustrationStyle` is
`pictureBook`, `watercolor` or `colorful3d`. Anything else is rejected with
`400 invalid_field` before a job exists. On success:

```json
{ "jobId": "…", "queuePosition": 1 }
```

Status `202 Accepted`: nothing has been generated yet. Position `1` means
the job is next (or already starting); `2` means one job is ahead of it.

### `GET /stories/jobs/<jobId>` — requires auth

Polls one job. Unknown ids — and jobs created by another device — answer
`404 job_not_found`, so ids cannot be probed.

```json
{
  "jobId": "…",
  "status": "generating",
  "progress": "Writing the story (attempt 1 of 3).",
  "createdAtUtc": "2026-08-22T10:00:00.000Z",
  "updatedAtUtc": "2026-08-22T10:00:04.000Z"
}
```

`queuePosition` is present only while `status` is `queued`. A failed job
carries `"error": {"code": "…", "message": "…"}`; a completed one carries
the whole book:

```json
{
  "status": "completed",
  "story": {
    "id": "…",
    "profileId": "profile-1",
    "title": "…",
    "languageCode": "ar",
    "createdAtUtc": "2026-08-22T10:06:11.000Z",
    "pages": [
      {
        "id": "…",
        "pageNumber": 1,
        "text": "…",
        "illustrationScene": "…",
        "illustrationId": "…",
        "illustrationRelativePath": "illustrations/<storyId>/0.png",
        "illustrationStatus": "pending"
      }
    ]
  }
}
```

The generation request itself is never echoed back: it holds the child's
name. Illustration rows exist from the first save with status `pending`
and a deterministic path; the image files arrive with the ComfyUI
milestone.

### `POST /stories/jobs/<jobId>/cancel` — requires auth

Idempotent; answers `200` with the status the job ended in:

```json
{ "jobId": "…", "status": "cancelled" }
```

A queued job leaves the line immediately. The running job has its in-flight
HTTP request to Ollama aborted and is never persisted — cancelling always
means "no story", never "half a story".

### `GET /sync/manifest` — requires auth

Everything the calling device needs to decide what to download. Metadata
only: titles and timestamps travel here, prose and files never do.

```json
{
  "generatedAtUtc": "2026-08-22T10:00:00.000Z",
  "lastSyncedAtUtc": null,
  "profiles": [
    {"id": "profile-1", "displayName": "Nour", "updatedAtUtc": "…"}
  ],
  "stories": [
    {
      "id": "…",
      "profileId": "profile-1",
      "title": "…",
      "languageCode": "ar",
      "createdAtUtc": "…",
      "updatedAtUtc": "…",
      "pageCount": 6,
      "illustrations": [
        {"id": "…", "pageNumber": 1, "status": "pending"}
      ]
    }
  ],
  "deletions": [
    {"entityType": "story", "entityId": "…", "deletedAtUtc": "…"}
  ]
}
```

`lastSyncedAtUtc` is this device's own watermark and is `null` until it has
reported one successful sync. Illustration status is `pending` for every slot
until the ComfyUI milestone.

### `GET /sync/stories/<storyId>` — requires auth

The complete story: title, language, and ordered pages with prose, the English
scene description, and the illustration id and path. Exactly the payload shape
a completed generation job returns, so a device parses one format either way.

```json
{
  "story": {
    "id": "…",
    "profileId": "profile-1",
    "title": "…",
    "languageCode": "ar",
    "createdAtUtc": "…",
    "updatedAtUtc": "…",
    "pages": [
      {
        "id": "…",
        "pageNumber": 1,
        "text": "…",
        "illustrationScene": "…",
        "illustrationId": "…",
        "illustrationRelativePath": "illustrations/<storyId>/0.png",
        "illustrationStatus": "pending"
      }
    ]
  }
}
```

Unknown ids — including a story that was deleted — answer `404
story_not_found`.

### `POST /sync/complete` — requires auth

Body: `{"manifestGeneratedAtUtc": "2026-08-22T10:00:00.000Z"}` — the
`generatedAtUtc` of the manifest the device finished applying. Upserts one
`sync_state` row for the calling device inside a transaction and answers with
the stored value:

```json
{ "deviceId": "…", "lastSyncedAtUtc": "2026-08-22T10:00:00.000Z" }
```

### `POST /stories/<storyId>/delete` — requires auth

Permanently deletes one story everywhere. No body.

```json
{
  "storyId": "…",
  "alreadyDeleted": false,
  "deletedAtUtc": "2026-08-22T10:05:00.000Z",
  "removedFileCount": 6
}
```

Idempotent: a story that is already gone answers `200` with
`"alreadyDeleted": true` and the original deletion time. An id that was never
in this library answers `404 story_not_found`. Profiles and reference photos
are never touched.

### `POST /library/backup` — requires auth

Body: `{"password": "at least eight characters"}`. Writes one encrypted
snapshot of the whole master library into the library's `exports/` folder and
answers `201`:

```json
{
  "fileName": "iam-hero-master-20260822T101530Z.ihmb",
  "sizeBytes": 184913,
  "createdAtUtc": "2026-08-22T10:15:30.000Z",
  "rowCount": 47,
  "fileCount": 12
}
```

The file itself never travels over HTTP — only its name does. See
[Master library backups](#master-library-backups).

### `POST /library/restore` — requires auth

Body: `{"fileName": "iam-hero-master-….ihmb", "password": "…"}`. Replaces the
library with that file's contents and answers `200`:

```json
{
  "fileName": "iam-hero-master-20260822T101530Z.ihmb",
  "backupCreatedAtUtc": "2026-08-22T10:15:30.000Z",
  "restoredRowCount": 47,
  "restoredFileCount": 12,
  "restoredDeviceCount": 2,
  "devicesMustRePair": true
}
```

Typed failures: `backup_password_too_short`, `backup_invalid_file_name`,
`backup_not_found`, `backup_unreadable`, `backup_authentication_failed`
(wrong password **or** an altered file), `backup_unsupported_version`,
`backup_too_large`, `backup_write_failed`, `backup_restore_failed`.

## Synchronization

### Manifest → downloads → complete

1. The device calls `GET /sync/manifest`.
2. It compares each story's `updatedAtUtc` against the copy it holds and calls
   `GET /sync/stories/<id>` only for the ones that are new or newer.
3. It applies every entry in `deletions` to its own copy.
4. It calls `POST /sync/complete` with the manifest's `generatedAtUtc`.

There is deliberately no change feed. At this scale — ten-odd profiles and
hundreds of stories — one manifest of metadata plus timestamps is smaller and
far harder to get wrong than a cursor a device could lose or replay. The
watermark stored by step 4 is the manifest's own generation time, not the time
the report arrived, so anything written while the device was downloading is
simply picked up by the next sync.

A device that loses its notes needs no recovery path: it fetches one manifest
and downloads whatever it cannot account for.

### Two kinds of deletion

| Kind | Where | What the bridge does |
| ---- | ----- | -------------------- |
| Remove the offline copy | in the app, on one device | **nothing** — the app deletes its own local copy; the story stays in the master library and will simply appear in the next manifest again |
| Delete everywhere | `POST /stories/<id>/delete` | deletes the pages, illustration rows and illustration files, and records the deletion so every other device drops its copy too |

The app's local "remove offline copy" needs no bridge endpoint at all, and
must not call one: freeing space on a tablet is not a family decision. Only
"delete everywhere" is.

Rows and the deletion record commit together in one transaction; the
illustration files are removed immediately after that commit, because the
file system cannot join a database transaction. The order is deliberate — an
interrupted delete can leave an orphan image file, which is harmless, where
deleting files first could leave a row pointing at a file that is already
gone. Only paths inside `illustrations/` are ever removed.

Deletion is permanent and has no undo — the recovery path for a mistake is a
backup, which is why the two features arrived together.

## Master library backups

### What a backup holds

One authenticated file with everything the library is:

- every database row — profiles, stories, pages, illustrations, deletion
  records, sync state, and devices **as names only**,
- every file under `photos/` and `illustrations/`, base64 inside the payload.

**Device token hashes are never in a backup.** A backup that could
authenticate a device would be a credential, and this one is a document. The
consequence is stated in the response and worth repeating: after a restore
**every device must pair again**, including the one that asked for the
restore. Restored device rows exist so the parent recognizes the list; they
cannot authenticate anything.

`db/master.db` is not copied as a file — the rows are the backup — and
`exports/` is excluded, so backups never nest.

### File format

```text
16  magic          "IAMHEROMASTERBK1"
 1  formatVersion  1
 1  kdfId          1 = PBKDF2-HMAC-SHA256
 1  cipherId       1 = AES-256-GCM
 1  reserved
 4  iterations     200000
 1  saltLength     32
 1  nonceLength    12
 1  macLength      16
 1  reserved
32  salt           random per file
12  nonce          random per file
 n  ciphertext     AES-256-GCM over the versioned JSON payload
16  mac            GCM tag; the whole header is authenticated as AAD
```

The payload is `{payloadVersion, createdAtUtc, librarySchemaVersion, tables,
files}`. A file whose payload version or library schema version is newer than
this build understands is refused before anything is touched, and so is one
declaring fewer PBKDF2 iterations than the current minimum. Because the header
is authenticated, editing the iteration count or a reserved byte fails
authentication rather than changing how the file is read.

### Never confused with an app backup

The app's own family backup (`iam-hero-backup`) and single-story share files
are JSON envelopes with a `format` field, and they use **Argon2id**. A master
backup is binary, starts with `IAMHEROMASTERBK1`, ends in `.ihmb`, and uses
**PBKDF2-HMAC-SHA256** with 200 000 iterations. Neither program can read the
other's file: handing an app backup to `POST /library/restore` fails as
`backup_invalid_file_name` or `backup_unreadable`, never as a wrong password.

PBKDF2 instead of Argon2id is deliberate. Argon2id is the better password KDF
and stays the choice inside the app, where the file may leave the family's
control. A master backup is created and read only by this pure-Dart process on
the family PC, and PBKDF2-HMAC-SHA256 gets there with no new dependency at
all — the difference is a dependency decision, not a security downgrade in
this setting.

### Where the file goes

The bridge writes into the library's own `exports/` folder and stops there.
**Copy the `.ihmb` file somewhere else yourself** — an external drive, another
computer, a USB stick — because a backup that only exists on the PC it backs
up protects against a mistake but not against a dead disk. To restore, copy
the file back into `exports/` and call `POST /library/restore` with its name.

### Restore is all-or-nothing

1. The file is read, authenticated, decrypted and fully validated. Nothing has
   been touched yet.
2. Every photo and illustration is written to a temporary sibling of its
   target. A failure here removes the temporaries and changes nothing.
3. The database is emptied and refilled inside one transaction. A failure
   here rolls back and removes the temporaries; the library is untouched.
4. Only after that commit are the temporaries renamed over their targets and
   files the backup does not contain removed.

A wrong password, a single flipped bit, a foreign file, or a payload this
build cannot read all fail at step 1 with a typed error. The one window that
is not atomic is a file-system failure inside step 4, reported as
`backup_restore_failed` with the database already restored.

## Story generation

### One at a time, always

The PC has one small GPU (4 GB VRAM), so a ten-page story can take several
minutes. Concurrency is not a tuning knob: a single worker drains the queue
in FIFO order and every other job waits with a reported position. Jobs live
in memory only — the durable, restartable queue is the app's, and a bridge
restart deliberately clears in-flight work.

### Job lifecycle

```text
queued ──▶ generating ──▶ validating ──▶ completed
             │                │
             └────────────────┴──▶ failed / cancelled
```

- **queued** — accepted, waiting for the worker; reports `queuePosition`.
- **generating** — `POST /api/generate` is in flight against the configured
  model with `"stream": false` and a JSON schema in `format`. The body is
  sent as explicit UTF-8 bytes with `Content-Type: application/json;
  charset=utf-8`, because Arabic corrupts otherwise.
- **validating** — the answer must be a JSON object with a non-empty title,
  exactly the requested number of pages, page numbers running 1..N in
  order, and non-empty text plus an English illustration scene on every
  page. Structured output is not trusted on its own: models observably drop
  the title or return the wrong page count even with a schema.
- **completed** — one transaction upserts the profile, inserts the story,
  its pages and one `pending` illustration row per page. If that write
  fails the job fails as `library_write_failed` and no rows remain.
- **failed / cancelled** — no story, no partial rows, ever.

### Retry policy

A job gets `maxGenerationAttempts` attempts (default 3 = one try plus two
retries). **Only invalid model output is retried** — the whole generation
runs again from the prompt. A missing Ollama, a timeout, or a failed
library write fails the job immediately: retrying a ten-minute timeout
three times would just make the parent wait half an hour for the same
answer.

Typed failure codes: `invalid_request`, `ollama_unavailable`,
`ollama_timeout`, `invalid_model_output`, `library_write_failed`,
`cancelled`, `internal_error`.

### What generation logs

Job ids, statuses, attempt counters, timings and typed error codes — and
nothing else. Prompts, story text, titles, child names and model output are
never written to the console or to any log.

## Pairing flow (human-in-the-loop)

1. On the phone, tap *Pair with PC* → the app calls `POST /pair/request`.
2. The PC screen shows the 6-digit code; type it into the phone within
   2 minutes.
3. The app calls `POST /pair/confirm`; on success the phone stores the
   returned bearer token and uses it for all further calls.

Codes expire after 2 minutes, live only in memory (a restart clears them),
and wrong attempts are capped at five.

## Security model

- **Loopback by default.** Binds to `127.0.0.1`; LAN exposure requires an
  explicit config change. Never port-forward to the internet (see warning).
- **Token authentication everywhere** except `/health` and the two pairing
  endpoints. Tokens are 256 bits from a cryptographically secure source;
  only SHA-256 hashes are stored, compared in constant time.
- **Pairing codes** are 6 digits, expire in 2 minutes, exist only in
  memory as hashes, are compared in constant time, and invalidate after
  five wrong entries. Request rate limit: 5 per minute.
- **Bounded requests**: bodies larger than 25 MB are rejected with `413`;
  slow handlers time out with a typed error instead of hanging.
- **Privacy by design**: request bodies, photo bytes, story content,
  prompts, child names, model output, tokens, and pairing codes are never
  logged. No third-party network calls — the only outbound traffic is
  health probes and story generation against the configured local
  Ollama/ComfyUI URLs.
- **Bounded generation**: one job at a time, a configurable timeout per
  call (default 10 minutes), a capped number of attempts, and cancellation
  that aborts the in-flight request instead of orphaning it.
- **Master library**: all structured data in SQLite under `db/master.db`,
  writes wrapped in transactions; binary assets stay in folders referenced
  by stable ids and relative paths (never blobs), written atomically via
  temp-file rename. A relative path that could point outside the library is
  refused, so a restored row can never reach another folder.
- **Bounded sync**: the manifest is metadata only — never prose, never file
  bytes — and every device sees only its own sync watermark.
- **Backups are documents, not credentials**: device token hashes are never
  written into one, so a stolen backup file cannot talk to any bridge. The
  file is encrypted with AES-256-GCM under a PBKDF2-HMAC-SHA256 key (200 000
  iterations, random salt and nonce per file) and its header is authenticated,
  so a wrong password and an edited byte fail the same way.

## Development

```powershell
dart pub get
dart analyze                          # must report zero issues
dart test                             # full suite, no services needed
dart format --set-exit-if-changed .   # formatting gate
```

Tests mock Ollama/ComfyUI at the HTTP-client boundary and always use
temporary directories, so nothing real is ever touched. The production
Ollama client is additionally exercised against a local stub HTTP server,
which is how the UTF-8 encoding, timeout and abort behavior stay honest.

Sync, deletion and backup tests mock nothing: they run the real SQLite
database, the real file system inside a temporary library, and the real
crypto at production cost. The backup tests build their own payloads with the
public codec, which is how "no partial restore" is proved with a genuinely
failing restore instead of a stubbed one.
