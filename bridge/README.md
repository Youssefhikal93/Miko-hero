# Iam-hero local PC bridge

Private, **local-only** HTTP bridge service for the "Iam - hero" children's
storybook app. It runs on the family PC, owns the master library (SQLite +
folders), pairs companion mobile devices with short-lived pairing codes and
256-bit bearer tokens, reports the health of its local dependencies, and generates stories with a
local Ollama model. Illustration generation (ComfyUI) follows in a later
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
  temp-file rename.

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
