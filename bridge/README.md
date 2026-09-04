# Iam-hero local PC bridge

Private, **local-only** HTTP bridge service for the "Iam - hero" children's
storybook app. It runs on the family PC, owns the master library (SQLite +
folders), pairs companion mobile devices with short-lived pairing codes and
256-bit bearer tokens, reports the health of its local dependencies, generates
stories with a local Ollama model, illustrates them with a local ComfyUI
install, synchronizes both to every paired device, deletes them everywhere on
request, and writes password-encrypted backups of the whole library.

> ## ⚠️ Never expose the bridge listener directly to the internet
>
> The bridge has no TLS, no accounts, and no hardening against hostile
> traffic. It is designed to listen only on loopback, a private/LAN or
> link-local address, or a Tailscale address. The bridge refuses wildcard,
> public, and hostname bind addresses other than `localhost`.
> **Never port-forward the listener on your router.** If remote access is
> required, keep `bindAddress` on `127.0.0.1` and terminate public HTTPS in a
> narrowly configured proxy or tunnel that forwards to the loopback listener.
> Add the public web app's origin (not the bridge URL unless it also serves the
> app) explicitly to `allowedWebOrigins` using `https://`.

## Requirements

- [Dart SDK](https://dart.dev) 3.12 or newer (`sdk: ^3.12.2`)
- Optional: a local [Ollama](https://ollama.com) server with the configured
  model pulled. Without it `/health` reports `ollama` unavailable and story
  generation fails with a typed error; everything else keeps working.
- Optional: a local [ComfyUI](https://github.com/comfyanonymous/ComfyUI)
  install for illustrations. It needs an SD 1.5 checkpoint — by default
  `v1-5-pruned-emaonly-fp16.safetensors`, any fine-tune via
  `illustration.checkpoint` — and, for face likeness, the **IPAdapter-plus**
  custom nodes with `ip-adapter-plus-face_sd15.safetensors` in the
  `ipadapter` folder and the CLIP vision encoder
  `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`. Without ComfyUI the bridge
  runs fine and illustration jobs fail with `comfyui_unavailable`.
- Optional, only if the matching `illustration` settings are switched on:
  LoRA files in `models/loras`, an upscale model such as
  `RealESRGAN_x4plus_anime_6B.pth` in `models/upscale_models`, and the
  [ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack)
  custom nodes plus a face detector for `faceDetail`. Everything here is off
  by default; nothing has to be installed to render a book.

## Configuration

The bridge loads one JSON configuration file, resolved in this order:

1. `--config <path>` command-line argument,
2. the `IAM_HERO_BRIDGE_CONFIG` environment variable,
3. `bridge_config.json` in the current working directory.

If the file does not exist it is created with defaults and its location is
printed. All machine-specific values live in this file; nothing is hardcoded.

**The whole file is strict.** Every key below is optional and falls back to
its documented default, but a key that is not in the table is refused at
startup with its own name in the message — the rule the `illustration` section
has always followed, now applied to the top level too. A misspelled
`ollamaModle` used to be dropped in silence, which meant every story ran on
the default model with nothing anywhere saying so. If the bridge refuses to
start after an upgrade, the message names the key to fix or delete.

| Field           | Default                 | Meaning                                   |
| --------------- | ----------------------- | ----------------------------------------- |
| `bindAddress`   | `127.0.0.1`             | Interface the HTTP server binds to. Startup accepts only `localhost`, `127.0.0.0/8`, `::1`, private IPv4 (`10/8`, `172.16/12`, `192.168/16`), link-local (`169.254/16`, `fe80::/10`), private IPv6 (`fc00::/7`), or Tailscale (`100.64/10`). Wildcard, public, and other hostname addresses are refused. |
| `port`          | `8765`                  | TCP port of the HTTP server               |
| `libraryPath`   | `<cwd>/iam_hero_library`| Root folder of the master library         |
| `ollamaBaseUrl` | `http://127.0.0.1:11434`| Base URL of the local Ollama API. Must be an absolute `http(s)` URL; trailing slashes are ignored |
| `comfyUiBaseUrl`| `http://127.0.0.1:8188` | Base URL of the local ComfyUI API. Same rule as `ollamaBaseUrl`   |
| `ollamaModel`   | `gemma3:4b`             | Ollama model tag used for stories. `gemma3:4b` is the floor, not a recommendation — see [`docs/STORY_QUALITY_UPGRADE.md`](../docs/STORY_QUALITY_UPGRADE.md) |
| `visionModel`   | `gemma3:4b`             | Ollama model tag used to read a child's reference photo **once**, to derive their [character sheet](#one-child-one-drawn-hero). Separate from `ollamaModel` because the writers worth upgrading to (`qwen3.5:*` and friends) cannot see an image at all. A tag without vision just means no sheet, and the story planner invents the appearance line as it always did |
| `generationTimeoutSeconds` | `900`        | Budget for **one** generation call (30–3600); a job makes two |
| `maxGenerationAttempts`    | `3`          | Attempts per job, first try included (1–5)|
| `illustrationTimeoutSeconds` | `300`      | Budget for rendering one page (60–1800). ComfyUI's short metadata calls — submit, poll, node check, interrupt — are separately capped at 30 s, or at this value when it is smaller |
| `allowedWebOrigins` | `[]`             | Extra web origins allowed to call the bridge from a browser (CORS). Every entry must be an exact origin: scheme + host + optional port, with no wildcard, credentials, path, query, fragment, or trailing slash. Loopback origins (`localhost`, `127.0.0.0/8`, `[::1]`, any port) are always allowed. `http://` is accepted only for loopback and the private/LAN, link-local, and Tailscale ranges accepted by `bindAddress`; every public origin must be listed explicitly with `https://`. |
| `illustration`  | see below               | How pages are rendered. Optional as a whole |

Example `bridge_config.json`:

```json
{
  "bindAddress": "192.168.1.20",
  "port": 8765,
  "libraryPath": "D:/FamilyData/iam_hero_library",
  "ollamaBaseUrl": "http://127.0.0.1:11434",
  "comfyUiBaseUrl": "http://127.0.0.1:8188",
  "ollamaModel": "qwen3:8b",
  "visionModel": "gemma3:4b",
  "generationTimeoutSeconds": 900,
  "maxGenerationAttempts": 3,
  "illustrationTimeoutSeconds": 300,
  "allowedWebOrigins": []
}
```

`bridge_config.json` is listed in this package's `.gitignore`; real configs
with machine-specific paths must never be committed.

### The `illustration` section

Every key is optional and defaults to the value the bridge shipped with, so a
configuration file written before this section existed — or one without it —
renders exactly what it always rendered. **The section is strict**: an unknown
key anywhere inside it is refused at startup with the field named, because a
misspelled rendering setting that was silently ignored is a book that quietly
came out wrong. So is a value outside its range; nothing is coerced.

| Key | Default | Range | Meaning |
| --- | --- | --- | --- |
| `checkpoint` | `v1-5-pruned-emaonly-fp16.safetensors` | non-empty | SD 1.5 checkpoint in `models/checkpoints`. Any SD 1.5 fine-tune; **not** SDXL or Flux, which do not fit in 4 GB beside the face adapter |
| `imageSize` | `512` | `512`, `576`, `640` | Square edge every page and portrait is sampled at |
| `samplerSteps` | `24` | 1–60 | Sampling steps per image |
| `cfgScale` | `7.0` | 1–15 | Classifier-free guidance |
| `ipAdapterWeight` | `0.65` | 0–1.5 | How hard the reference face steers a page. 0.55–0.75 is the useful band: likeness against drawn-ness |
| `referenceDenoise` | `0.62` | above 0, up to 1 | How hard the photo is cartoonified in stage one. Zero is refused — it would hand the adapter the photograph itself |
| `loras` | `[]` | at most 8 entries | Ordered LoRA chain; each entry is `{"name": "…​.safetensors", "strength": 0.8}` with strength 0–1.5 |
| `upscale.enabled` | `false` | | Whether pages are enlarged after decoding |
| `upscale.model` | `RealESRGAN_x4plus_anime_6B.pth` | non-empty | Model in `models/upscale_models` |
| `upscale.targetSize` | `1024` | 512–2048 | Square edge a page is saved at. ESRGAN multiplies by four, so 512 becomes 2048 and is resized to this |
| `faceDetail.enabled` | `false` | | Whether faces are re-rendered after the page. **Needs ComfyUI-Impact-Pack** |
| `faceDetail.detector` | `bbox/face_yolov8m.pt` | non-empty | Model name for `UltralyticsDetectorProvider` |
| `faceDetail.denoise` | `0.45` | above 0, up to 1 | How much of a detected face is repainted |

```jsonc
"illustration": {
  "checkpoint": "dreamshaper_8.safetensors",
  "loras": [{ "name": "kids-illustration.safetensors", "strength": 0.8 }],
  "upscale": { "enabled": true, "targetSize": 1024 },
  "faceDetail": { "enabled": false }
}
```

Two constraints are checked when the file is read, not when a page fails:

- the finished page has to fit the **16 MB ceiling on a downloaded image**
  (`maxComfyUiImageBytes`), so a size the bridge could never fetch is refused
  at startup rather than after a book of failed renders;
- `faceDetail.enabled` is verified against ComfyUI itself before the first
  render of a job — see [Face detailing](#face-detailing).

Tuning, in order of usefulness: LoRA strength (style), then `ipAdapterWeight`
(likeness against drawn-ness), then `referenceDenoise`. If ComfyUI runs out of
VRAM at `targetSize` 1024, 768 is still a visible improvement over 512.

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

### Postman collection

Every endpoint below is also a ready request in
[`Iam-hero-bridge.postman_collection.json`](../Iam-hero-bridge.postman_collection.json)
at the repository root — Postman v2.1, importable in one step. **Set two
variables and nothing else:**

- `baseUrl` — `http://127.0.0.1:8765` on the PC itself, or the Tailscale Funnel
  address (`https://<machine>.<tailnet>.ts.net`) from anywhere else. The same
  collection works against both.
- `deviceToken` — **leave it empty**. Run *Pairing → Confirm pairing* once and
  its test script stores the returned token here for every other request.

`profileId`, `storyId`, `jobId` and `illustrationId` are filled the same way by
the requests that produce them, so the collection runs top to bottom without
copy-paste: *Management → List profiles* fills `profileId` the first time it
finds one and never overwrites a value typed by hand. `deviceId` stays the one
value always typed by hand, on purpose — removing a pairing should not be one
click away from a listing.

The Management folder also holds the one irreversible request in the
collection, *Delete profile everywhere*, so read that folder rather than
running it end to end.

Authentication is set once at the collection level as `Bearer {{deviceToken}}`,
and `/health`, `/pair/request` and `/pair/confirm` opt out of it exactly as the
bridge does.

The file ships with every variable empty except `baseUrl`: no token and no
family data are committed. `test/postman_collection_test.dart` checks the
collection against `lib/src/server/bridge_routes.dart` — the same list
`AppServer.buildHandler` builds its routers from — so a new endpoint without a
Postman request, or a request for an endpoint that no longer exists, fails the
suite.

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

Requires `Authorization: Bearer <deviceToken>`. Lists the devices that can
still authenticate (names and moments only — never tokens or token hashes):

```json
{
  "devices": [
    {
      "id": "...",
      "name": "Family tablet",
      "createdAtUtc": "2026-08-22T10:00:00Z",
      "lastSeenAtUtc": "2026-09-01T18:30:00Z",
      "isCaller": true
    }
  ]
}
```

`lastSeenAtUtc` is when that device last presented a valid token; it is
`null` for a device that paired and has not called since. Every
authenticated request stamps it, so it moves on the caller's own row before
this answer is built. `isCaller` marks the row belonging to the device
asking, which is how the app shows "this device" and hides a removal it
would be refused anyway — a device never has to store its own id.

Revoked devices are not listed.

Every endpoint except `/health`, `/pair/request`, and `/pair/confirm`
requires a valid bearer token; anything else gets `401 unauthorized`.

### `DELETE /devices/<deviceId>` — requires auth

Removes another device's pairing. The token row is kept but marked revoked,
so the removed device's **very next call fails with `401 unauthorized`** and
the PC still remembers the device once existed.

```json
{ "id": "...", "removed": true }
```

Failure modes:

- `409 cannot_remove_self` — a device may not remove its own pairing.
  Unpairing the device you are holding is a local decision made on that
  device (the app's *Forget this device*), and a self-removal would leave the
  parent looking at a list they can no longer refresh.
- `404 device_not_found` — no device is paired under that id, including one
  already removed.

### `GET /profiles` — requires auth

Every child the master library knows, oldest first:

```json
{
  "profiles": [
    {
      "id": "profile-1",
      "displayName": "Nour",
      "hasPhoto": true,
      "storyCount": 3,
      "createdAtUtc": "2026-08-22T10:00:00.000Z",
      "updatedAtUtc": "2026-09-01T18:20:00.000Z"
    }
  ]
}
```

`hasPhoto` is a yes-or-no. The photo bytes never leave the library, and
neither does its path: whether a child has a reference photo is something the
parent needs to know, and what the child looks like is not something an HTTP
answer should carry.

There is **no age here**. The bridge stores a child's name and nothing else
about them; the age a story was written for travels inside the generation
request and is used to pitch the prose, not kept. The app owns the birth date.

Failure: `401 unauthorized`.

### `DELETE /profiles/<profileId>` — requires auth

Deletes the child and everything the library holds for them — the profile row,
every story, every page, every illustration row, the rendered image files and
the reference photo:

```json
{
  "profileId": "profile-1",
  "deletedAtUtc": "2026-09-03T09:12:44.000Z",
  "deletedStoryCount": 3,
  "deletedPageCount": 18,
  "deletedIllustrationCount": 18,
  "removedFileCount": 15,
  "photoRemoved": true
}
```

The rows go in **one transaction**: either the whole child goes or nothing
does. Files are removed after it commits, for the reason a story deletion
gives — an orphaned file is harmless, a row pointing at a missing file is not
— so `removedFileCount` is lower than `deletedIllustrationCount` whenever some
pages were never drawn.

One `deletion_records` entry is written **per deleted story**, exactly the
record `POST /stories/<storyId>/delete` writes, so a paired device that never
saw this happen learns each book is gone from its next manifest through the
path it already understands. The profile's own disappearance needs no record:
a manifest carries the complete profile list, so a child no longer in it is a
child who is gone.

Unlike a story deletion this is **not idempotent**. Nothing records that a
profile once existed, so a second call cannot be told apart from a mistyped id
and answers `404 profile_not_found` — the same typed error the photo endpoints
answer, malformed ids included.

Failures: `404 profile_not_found`, `401 unauthorized`.

### `GET /stories` — requires auth

Every story with its illustration progress, oldest first:

```json
{
  "stories": [
    {
      "id": "…",
      "profileId": "profile-1",
      "title": "Nour and the Sea Lanterns",
      "languageCode": "ar",
      "pageCount": 6,
      "illustrations": { "pending": 1, "completed": 4, "failed": 1 },
      "createdAtUtc": "2026-08-22T10:04:11.000Z",
      "updatedAtUtc": "2026-08-22T10:31:02.000Z"
    }
  ]
}
```

Titles only — no page prose; a listing is a table of contents. The three
illustration counts always add up to the story's illustration rows, because
anything that is neither `completed` nor `failed` is counted as pending.

`?profileId=<id>` narrows the listing to one child's shelf. It is read through
the same `JsonReader` every request body goes through, so it gets the same
treatment: one known parameter, a 64-character limit, and never the value in
the message. A `profileId` that names no profile is a **`400 invalid_field`
naming the parameter**, not an empty list — an empty shelf and a typo look
identical otherwise, and the parent would read the wrong one as an answer. Any
other query parameter is refused the same way, by name, so a misspelled
`?profileID=` cannot quietly return the whole library.

Failures: `400 invalid_field`, `401 unauthorized`.

### `GET /stories/<storyId>` — requires auth

One whole book — every page's prose, its English scene description, and its
illustration id and status. **Byte for byte the answer
`GET /sync/stories/<storyId>` gives a paired device**: one serializer, one
shape, documented under that endpoint below. A second shape for the parent
would be a second thing to keep true.

Failures: `404 story_not_found` (a deleted story included), `401 unauthorized`.

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
  "illustrationStyle": "pictureBook",
  "favoriteTopics": "sea turtles and paper boats",
  "recurringWorld": "the Lantern Harbour"
}
```

Every field except the last two is required. `genderContext` is `girl` or
`boy` (the app's unspecified state never reaches here), `languageCode` is
`ar`, `en`, `sv` or `so`, `pageCount` is `6`, `8` or `10`, and
`illustrationStyle` is `pictureBook`, `watercolor` or `colorful3d`. Anything
else is rejected with `400 invalid_field` before a job exists.

`favoriteTopics` and `recurringWorld` are **optional** (≤ 240 characters
each) and carry the child's saved story preferences. Absent, `null` and blank
all mean the same thing — nothing was filled in — and the prompt then says
nothing about them at all. A present value of the wrong type or over the
limit is still `400 invalid_field`. A device that never sends them keeps
working unchanged.

On success:

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
and a deterministic path; the image files arrive when the story is sent
through `POST /stories/<storyId>/illustrate`.

### `POST /stories/jobs/<jobId>/cancel` — requires auth

Idempotent; answers `200` with the status the job ended in:

```json
{ "jobId": "…", "status": "cancelled" }
```

A queued job leaves the line immediately. The running job has its in-flight
HTTP request to Ollama aborted and is never persisted — cancelling always
means "no story", never "half a story".

### `PUT /profiles/<profileId>/photo` — requires auth

Stores the child's reference photo, which is what makes the hero look like
the same child on every page. The body is **the image itself**, not JSON:

```text
PUT /profiles/profile-1/photo
Authorization: Bearer <deviceToken>
Content-Type: image/jpeg

<raw bytes>
```

`Content-Type` must be `image/jpeg` or `image/png` (`image/jpg` is accepted
as a spelling of the former), and the bytes must actually start with that
format's magic bytes — a declared type is a claim, the bytes are the
evidence. Answers `200`:

```json
{
  "profileId": "profile-1",
  "relativePath": "photos/profile-1.png",
  "contentType": "image/png",
  "sizeBytes": 148213
}
```

The file is written atomically to `photos/<profileId>.<ext>`, replacing any
previous photo (including one stored in the other format — a profile never
has two), and the profile row's `updated_at_utc` moves inside a transaction
so the next sync manifest shows the change.

The response does not wait for the child's
[character sheet](#one-child-one-drawn-hero) to be re-derived from the new
photo. That runs behind the answer as a best-effort task, and is skipped when
the GPU is busy; a story that needs a sheet and does not find one derives it
itself.

Typed failures: `400 unsupported_image_type` (wrong or missing
`Content-Type`), `400 invalid_image` (bytes that are not that format, or an
empty body), `413 photo_too_large` (over 2 MB), `404 profile_not_found`.

**The bytes never leave the library.** They are not logged, not echoed in a
response, not named in an error message, and not sent to any paired device —
only to the local ComfyUI, and only while a page is being rendered.

### `DELETE /profiles/<profileId>/photo` — requires auth

Removes the photo. Idempotent — a profile that has none answers `200` with
`"removed": false` — and `404 profile_not_found` for an unknown profile.

```json
{ "profileId": "profile-1", "removed": true }
```

### `GET /profiles/<profileId>/hero-sheet` — requires auth

How this child's hero is **drawn** — see
[One child, one drawn hero](#one-child-one-drawn-hero) for what the sheet is
and where each half of it comes from.

```json
{
  "profileId": "profile-1",
  "sheet": {
    "hair": "short curly black hair",
    "skinTone": "warm brown",
    "eyeColor": "dark brown",
    "outfit": "wearing a red knitted cardigan over a white collared shirt",
    "prop": "carrying a small brass lantern",
    "photoHash": "9f2c…",
    "updatedAtUtc": "2026-09-03T20:14:02.000Z"
  }
}
```

A child whose photo has never been read answers `200` with `"sheet": null`.
That is a state, not a failure: it is what a family sees before their first
illustrated book, and the app shows it as "the PC has not read this photo yet".

A sheet may also carry **only** `outfit` and `prop`, with the three derived
values and `photoHash` empty, when a parent said what their hero wears before
any photo reached the PC. `isDerived` is that distinction on the bridge side,
and a sheet that is not derived is treated as no sheet at all by the story
planner.

Typed failures: `404 profile_not_found` (an unknown or malformed id).

### `PUT /profiles/<profileId>/hero-sheet` — requires auth

Sets what this child's hero always wears and carries, and nothing else.

```json
{
  "outfit": "wearing a mustard-yellow raincoat over a striped shirt",
  "prop": "carrying a small brass lantern"
}
```

The sheet has two owners and this endpoint writes one of them. `hair`,
`skinTone`, `eyeColor` and `photoHash` are the PC's — it is the only thing that
ever looks at the photo — and are refused here as unknown fields; the only way
to move them is to have the photo read again. `outfit` and `prop` were never in
the photo (see the wardrobe reasoning below), so they are the parent's.

Both fields are optional, and a blank one clears that half of the wardrobe: a
parent may undress a hero as deliberately as they dressed one. Each is at most
80 characters — the same limit the vision pass's own fields have — because the
one line they join is repeated into every page's scene description.

Answers `200` with the same body `GET` returns. A profile whose photo has never
been read still gets its wardrobe stored, and the derived half fills in the
first time a photo is read.

Typed failures: `400 invalid_field` (an unknown field, or one over the limit),
`404 profile_not_found`.

### `POST /profiles/<profileId>/hero-sheet/rederive` — requires auth

Reads the stored reference photo again and rewrites the three derived traits,
**ignoring the photo-hash cache**. That cache is the whole reason the sheet is
cheap, and asking to read the photo again is exactly a request to stop trusting
it for one call. The outfit and the prop are not touched.

Answers `202`:

```json
{
  "profileId": "profile-1",
  "started": true,
  "sheet": { "hair": "long straight brown hair", "…": "…" }
}
```

`202` rather than `200` because the PC accepts the request rather than
promising it is finished. The re-read takes its turn at the
[one-GPU gate](#one-gpu-one-job--story-or-picture-never-both) like a story or a
render does, and unlike the nudge behind a photo upload it **waits** for the
card instead of stepping aside — a parent asked for this. The `sheet` in the
answer is the best the PC has by the time it answers: usually the fresh one,
and the old one when the card was still busy drawing a book.

Nothing here fails the caller. A profile with no photo, an Ollama that is down,
and a model that answered in the wrong shape all leave whatever was already
stored, because none of them is something a parent could act on.

Typed failures: `404 profile_not_found`.

### `POST /stories/<storyId>/illustrate` — requires auth

Queues rendering of every page of the story that does not have an image yet:
`pending` and `failed` rows both count, `completed` ones are skipped. The
body is optional and carries the two things the library does not remember
about a story but a picture needs:

```json
{ "illustrationStyle": "watercolor", "genderContext": "girl" }
```

Both are optional. An absent `illustrationStyle` falls back to
`pictureBook`; an absent `genderContext` simply leaves the hero described as
a child. A present-but-invalid value is `400 invalid_field`. On success:

```json
{ "jobId": "…", "pageCount": 6, "queuePosition": 1 }
```

`pageCount` is how many pages **this job** will render, not how long the
story is: after a run where one page failed, a second call answers
`"pageCount": 1`. An unknown story answers `404 story_not_found`.

### `GET /illustrations/jobs/<jobId>` — requires auth

Polls one illustration job. Unknown ids — and jobs created by another device
— answer `404 job_not_found`, exactly like story jobs.

```json
{
  "jobId": "…",
  "storyId": "…",
  "status": "rendering",
  "progress": "Rendering page 3 of 6.",
  "pageCount": 6,
  "completedPageCount": 2,
  "failedPageCount": 0,
  "createdAtUtc": "2026-08-22T10:00:00.000Z",
  "updatedAtUtc": "2026-08-22T10:04:12.000Z"
}
```

`queuePosition` is present only while `status` is `queued`. A failed job
carries `"error": {"code": "…", "message": "…"}`. Nothing in this payload is
story content: no scene descriptions, no prompts, no file paths.

### `POST /illustrations/jobs/<jobId>/cancel` — requires auth

Idempotent; answers `200` with the status the job ended in:

```json
{ "jobId": "…", "status": "cancelled" }
```

A queued job leaves the line immediately. The running job **stops after the
page it is currently rendering**: that page is finished and stored, and no
page after it is started. Throwing away a minute of GPU work that is nearly
done would help nobody.

### `GET /sync/illustrations/<illustrationId>` — requires auth

The one endpoint that answers with bytes instead of JSON: the rendered page
as `image/png`, with a strong `ETag` (the SHA-256 of the file contents) and
`Cache-Control: private, no-cache`. Send the stored tag back as
`If-None-Match` to get `304 Not Modified` instead of the image again.

A content hash rather than size-and-mtime, deliberately: a re-render writes
the same path with a new timestamp, and re-downloading a byte-identical
image on every sync is exactly what the tag exists to prevent.

Two response headers carry the page's identity so a device does not have to
join it back to the manifest: `x-illustration-story-id` and
`x-illustration-page-number`.

Errors stay typed JSON: `404 illustration_not_found` for an unknown id, and
`409 illustration_not_ready` when the row is not `completed` — which is a
different thing from a missing story and must not be treated as one. A row
that says `completed` while its file is gone reads as `409` too.

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
reported one successful sync. Each illustration's `status` is `pending`,
`completed` or `failed`; only a `completed` one can be downloaded from
`GET /sync/illustrations/<id>`.

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
3. For every illustration the manifest reports as `completed` and the device
   does not already hold, it calls `GET /sync/illustrations/<id>` — sending
   the `ETag` it stored last time as `If-None-Match`, so an unchanged image
   costs a `304` instead of a download. A page finishing rendering moves its
   story's `updatedAtUtc`, which is how the manifest advertises new images.
4. It applies every entry in `deletions` to its own copy.
5. It calls `POST /sync/complete` with the manifest's `generatedAtUtc`.

There is deliberately no change feed. At this scale — ten-odd profiles and
hundreds of stories — one manifest of metadata plus timestamps is smaller and
far harder to get wrong than a cursor a device could lose or replay. The
watermark stored by step 5 is the manifest's own generation time, not the time
the report arrived, so anything written while the device was downloading is
simply picked up by the next sync.

A device that loses its notes needs no recovery path: it fetches one manifest
and downloads whatever it cannot account for.

### Three kinds of deletion

| Kind | Where | What the bridge does |
| ---- | ----- | -------------------- |
| Remove the offline copy | in the app, on one device | **nothing** — the app deletes its own local copy; the story stays in the master library and will simply appear in the next manifest again |
| Delete everywhere | `POST /stories/<id>/delete` | deletes the pages, illustration rows and illustration files, and records the deletion so every other device drops its copy too |
| Delete the child | `DELETE /profiles/<id>` | the same, for every story that child owns at once, plus the profile row and the reference photo |

The app's local "remove offline copy" needs no bridge endpoint at all, and
must not call one: freeing space on a tablet is not a family decision. The
other two are.

Deleting a child writes one story deletion record per book rather than a new
kind of record, so devices need to understand nothing new; the profile's own
disappearance is visible because a manifest always carries the complete
profile list.

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
  records, sync state, and devices **as names only** (name, paired and
  last-seen moments, revocation),
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

### Two passes: plan, then write

A story is written in **two model calls**, because a small model asked to
invent and write a whole book at once produces six unrelated scenes with the
moral announced on the last page.

1. **Outline pass.** A deliberately tiny schema: a working title, exactly one
   beat per page, a one-line **hero appearance sheet** — clothing colours,
   hair, one recurring prop — a **lesson moment**, and a **turn page**. The
   prompt asks for a real arc: a warm ordinary opening, a challenge or
   discovery growing through the middle, and a last page resolved by something
   the child themself chose or did.
2. **Page pass.** The approved outline is embedded verbatim in the prompt, so
   the pages tell that plan rather than a new story. Beat N becomes page N.

The appearance sheet is appended to every page's `illustrationScene` (em-dash
separated, inside the existing 2000-character cap), which is what makes the
hero wear the same clothes on page one and page ten when ComfyUI draws them.
Either way it describes a drawn character, and the prompt forbids describing a
photograph or a real person.

Where the line comes from depends on whether the child has a **character
sheet** (see [One child, one drawn hero](#one-child-one-drawn-hero)):

- **With a sheet** — the stored line is put in the prompt and the planner is
  told to copy it verbatim. Whatever it actually answers is ignored; the stored
  line is the one that reaches the pages. A wrong copy therefore costs nothing,
  not even a retry.
- **Without one** — no photo, or the vision pass never managed to run — the
  planner invents the line per story, exactly as it did before sheets existed.

The prompt also carries the reader's age into a concrete reading level
(sentence length and vocabulary bands for ≤4, ≤7, ≤10 and older), asks for the
child's name only where it reads naturally rather than in every sentence, and
weaves in `favoriteTopics` and `recurringWorld` when they were sent.

### The lesson is the spine

The parent's moral used to reach the model as one line, and two rules then
forbade the model to state it — so a story about "listening to your parents"
came back as a nice adventure with nothing in it to listen to. The plan now
carries the lesson itself:

- **`lessonMoment`** — one sentence, in the story's own language, naming the
  concrete situation where the hero faces the lesson. Not the moral restated:
  the moment it is tested. It is embedded verbatim in the page prompt.
- **`turnPage`** — the page where the hero chooses the lesson. **The middle is
  defined as every page after page 1 and before the last page.** Page 1 is the
  warm ordinary opening, so a turn there leaves the hero no room to do the
  opposite first; the last page is the resolution, so a turn there is the
  moral announced at the end — the exact failure this plan exists to prevent.
  A six-page book may turn on 2, 3, 4 or 5.

The outline prompt tells the planner the middle challenge **is** the lesson:
the hero does the opposite of it first, that costs something real, and on the
turn page the hero chooses the lesson instead. The page prompt names the turn
page and demands the choice be shown in action and in the body, never
reported afterwards.

A missing, blank, oversized or wrong-language lesson moment, and a turn page
outside the middle, are all `invalid_model_output` — the plan is refused and
re-planned, exactly like a hero appearance line in the wrong script. The
lesson moment's language is checked by the same purity check as the title and
the beats, so an English lesson moment on an Arabic book is refused.

**One character may say it out loud.** The old rule forbade the model to state
the moral at all. It still must never lecture and never address the reader —
no "and so we learn", no "remember, children", no closing lesson sentence, no
narrator explaining the point — but a parent or a friend may say the lesson
once, in ordinary dialogue, and never on the last page. Real picture books do
that; forbidding it was part of why the lesson evaporated.

### Job lifecycle

```text
queued ──▶ generating ──▶ validating ──▶ completed
             │                │
             └────────────────┴──▶ failed / cancelled
```

- **queued** — accepted, waiting for the worker; reports `queuePosition`.
- **generating** — `POST /api/generate` is in flight against the configured
  model with `"stream": false`, `"think": false` and a JSON schema in
  `format`. Thinking is off because reasoning models such as `qwen3.5:*`
  otherwise return the JSON in Ollama's `thinking` field and an empty
  `response`, which reads as `invalid_model_output`. Both passes
  live in this state; `progress` reads `Planning the story…` and then
  `Writing the story…`. The body is sent as explicit UTF-8 bytes with
  `Content-Type: application/json; charset=utf-8`, because Arabic corrupts
  otherwise.
- **validating** — the answer must be a JSON object with a non-empty title,
  exactly the requested number of pages, page numbers running 1..N in
  order, and non-empty text plus an English illustration scene on every
  page. Structured output is not trusted on its own: models observably drop
  the title or return the wrong page count even with a schema.
- **completed** — one transaction upserts the profile, inserts the story,
  its pages and one `pending` illustration row per page. If that write
  fails the job fails as `library_write_failed` and no rows remain.
- **failed / cancelled** — no story, no partial rows, ever.

After any running job reaches one of those terminal states, the shared GPU
gate asks Ollama to unload the configured model before the card changes hands
or goes idle. The gate owns that rule for both queues; a queue never unloads
on its own.

### Language purity

Both passes are checked against the script the story was requested in, and a
violation is reported as `invalid_model_output` — so it costs a retry exactly
like a wrong page count.

- For `ar`, at least 95 % of the **letters** in the title and pages must be
  Arabic script. English prose, a Latin sentence dropped into Arabic, and
  transliterated Arabic are all refused.
- For `en`, `sv` and `so`, **no** Arabic-script letter is accepted at all and
  at least 95 % of the letters must be Latin.
- Digits (ASCII, Arabic-Indic and Eastern Arabic-Indic), punctuation,
  whitespace and Arabic vowel marks are not letters and never count.

Not 100 %, on purpose: an invented creature's name is not a language failure.
This is script-level defense in depth behind the prompt, not a spellchecker —
correct grammar is the model's job, and the reason the model choice matters.
Scene descriptions are exempt, because they are deliberately English.

### Retry policy

A job gets `maxGenerationAttempts` attempts (default 3 = one try plus two
retries), and **both passes share that one counter**:

- An attempt runs the outline pass only until an outline has been accepted.
  From then on every retry re-sends that same approved plan, so a retry
  reproduces the story instead of drifting into a different one.
- With the default of 3 a job therefore makes at most **four** model calls:
  one outline plus three page passes.
- An outline the model keeps getting wrong consumes the same three attempts
  and pass two never runs at all.

**Only invalid model output is retried** — including a failed language-purity
check. A missing Ollama, a timeout, or a failed library write fails the job
immediately: retrying a fifteen-minute timeout three times would just make the
parent wait three quarters of an hour for the same answer.

`generationTimeoutSeconds` is the budget for **one** call, not for the job, so
two passes cannot exhaust one timeout between them.

Typed failure codes: `invalid_request`, `ollama_unavailable`,
`ollama_timeout`, `invalid_model_output`, `library_write_failed`,
`cancelled`, `internal_error`.

### What generation logs

Job ids, statuses, attempt counters, timings and typed error codes — and
nothing else. Prompts, story text, titles, child names and model output are
never written to the console or to any log.

The character-sheet pass logs one verdict — `hero sheet derived`, `refreshed`,
`unchanged`, `deferred` or `unavailable` — with no profile id, no photo hash,
and not one word of the sheet itself.

## Illustrations

### One GPU, one job — story or picture, never both

The machine has one 4 GB card. Story generation loads a language model onto
it; illustration rendering loads a diffusion checkpoint onto it. Two workers
that each fit alone will together exhaust the card and fail in a way neither
queue can explain, so **the two queues share one lock**: while a story is
being written no page renders, and while a page renders no story is written.

The two queues stay separate — they have different job shapes, statuses and
failure modes — and share only that lock. The illustration queue takes it per
**page** rather than per job, so a story queued behind a ten-page book waits
for one page instead of ten. The story queue takes it for a whole job,
because a half-generated story is not a thing worth yielding for.

Within each queue the rule is the familiar one: a single worker drains a FIFO
line, everyone else waits with a reported position, and jobs live in memory
only.

### The render itself

Per page, in order: build the node graph, submit it to `POST /prompt`, poll
`GET /history/<promptId>` until `status.completed`, download the image from
`GET /view`, check it really is a PNG, write it atomically to
`illustrations/<storyId>/<pageIndex>.png`, and flip the row to `completed`.

The graph is SD 1.5 at the configured size — 512x512 out of the box — with a
fixed negative prompt that guards against scary, adult, deformed and
text-covered output on every single render. That guard is deliberately **not**
configurable and not a per-request option, because this is a children's book
generator; everything else about the graph is, through the `illustration`
section. Each of `pictureBook`, `watercolor` and `colorful3d` contributes its
own prompt prefix. The sampler seed is derived from the illustration id, so
**re-rendering a page reproduces it**: a parent who asks for the same picture
again gets the same picture, not a lottery ticket.

Three optional stages hang off the configuration, all off by default:

1. **LoRA chain** — one `LoraLoader` per configured entry, chained in file
   order between the checkpoint and *everything* that reads a model or a
   CLIP. Both graphs get it: a prompt encoded without the LoRA that paints
   the picture fights the picture, and a portrait drawn by a different model
   than the pages is a face the pages cannot reproduce.
2. **Upscale** — after the decode: `UpscaleModelLoader` →
   `ImageUpscaleWithModel` → an `ImageScale` down to `targetSize` (lanczos),
   because the ESRGAN models multiply by a fixed four. Built-in nodes only.
3. **Face detailing** — after the upscale, so faces are refined at the size
   the page is actually read at. Needs the Impact Pack.

The reference portrait gets the LoRA chain and **neither** the upscale nor the
face-detail pass. It is an adapter input, not a picture: nobody ever looks at
it, and both passes would spend GPU minutes on pixels that are downsampled
again the moment they are used.

### Face detailing

`faceDetail` wires the Impact-Pack `FaceDetailer` between the page and the
save, fed by an `UltralyticsDetectorProvider`, the same model the page was
sampled with (adapter chain included, or the refined face stops looking like
the child), the same CLIP and VAE, and **both** prompt encoders — the safety
guard applies to a re-rendered face exactly as it applies to a page.

Those nodes are not part of a stock ComfyUI. Rather than discovering that one
rejected submission at a time, the bridge asks ComfyUI whether it knows both
class types **once, before the first render of a job**, and fails the whole job
with `missing_custom_node` and a message naming what to install or what to turn
off. No row is touched, exactly as with an unreachable ComfyUI: the
configuration is wrong, not the pages. There is no half-drawn book and no hang.

If the profile has a reference photo, the render is **two-stage**, and the
first stage runs once per job — one extra render on top of the pages:

1. **Stylize the reference.** The photo is uploaded to ComfyUI once, scaled to
   512x512 and redrawn as a cheerful storybook portrait: an img2img pass at
   denoise 0.62, in the book's own style prefix, with a negative prompt that
   adds `photo, photorealistic, dslr, skin pores` and friends in front of the
   usual guards. Its seed is derived from
   `reference:<profileId>:<sha256 of the photo>` — **the child and the photo,
   never the story** — so every book of one child redraws the same face, a
   re-run reproduces it, and a re-rendered page still matches the pages that
   already landed. The denoise is the whole tradeoff in one number: lower
   keeps more of the real child and more of the photograph, higher cartoonifies
   harder and starts inventing a different child.
2. **Render the pages.** Exactly as above, except the checkpoint's model output
   is routed through the IPAdapter-plus-**face** chain — load the *stylized
   portrait*, encode it with CLIP vision, apply the adapter at weight 0.65 —
   before it reaches the sampler. The pages themselves are unchanged, including
   their negative prompt: a page must stay free to be whatever its style
   demands instead of arguing with its reference.

Stage one takes the same turn on the one-GPU gate a page takes, so no story
is ever generated alongside it. If it fails for any reason the job renders the pages
with **no reference at all** — never with the raw photo, which is the output
this pass exists to avoid. The portrait is derived from the child's photo and
is treated as private content: it stays inside ComfyUI's folders, exactly as
the photo already does, and is never written into the library or logged.

Without a photo the graph is plain text-to-image, there is no stage one, and
the hero simply will not resemble anyone in particular.

The portrait file inside ComfyUI's input folder is still named per story
(`iam-hero-ref-<storyId>.png`). It is scratch — one job writes it and that same
job's pages read it — and two books of one child in different styles must not
overwrite each other mid-render. What has to be stable across books is the
face, and that is the seed's job.

### One child, one drawn hero

A child's hero used to be reinvented twice per book: the portrait was seeded
from the story id, so every book drew a different cartoon of the same face, and
the story planner invented a fresh appearance line every time. A family reading
three books saw three different children.

Two things now come from the **child**, not the book:

1. **The face.** The portrait seed is `reference:<profileId>:<photo hash>`, as
   above. Same photo, same face, in every book. A new photo is the one thing
   that deliberately draws a new one.
2. **The character sheet.** One row per profile in `hero_character_sheets`
   (schema v4), holding `hair`, `skinTone` and `eyeColor` — read from the photo
   — plus one `outfit` and one `prop`, and the `photo_hash` the first three came
   from. Its one English line is what the story planner is told to copy, and it
   ends up appended to every page's scene description exactly as an invented
   line used to be.

**How the sheet is derived.** One Ollama `/api/generate` call with an `images`
array and a three-string schema, on `visionModel`. The prompt asks for a
**drawn cartoon character** and nothing else: it forbids mentioning a photo, a
picture, a camera or a real person, and forbids every identifying detail — no
name, age, expression, background, glasses, jewellery, scars or birthmarks. It
asks for three colours, and that is all it can answer.

**Clothing deliberately does not come from the model.** Asked what the
character wears, a vision model describes the jumper in the picture — which is
both an identifying detail and a costume that would change with every new
photo. So the `outfit` and the `prop` are picked from two small curated
wardrobes, hashed per profile: one child keeps one coat for as long as the
profile exists, a new photo repaints the hair and colouring and leaves the hero
dressed as the last book left them, and every entry was written once to be
English, drawn and appropriate for a picture book.

**When it runs.** Twice over, so that neither path is load-bearing on its own,
plus once more when a parent asks:

- **On `PUT /profiles/<id>/photo`**, as a detached best-effort task using the
  bytes that were just uploaded. Detached because a request has 20 seconds and
  a vision call does not fit in them; **skipped outright when the GPU is busy**,
  because a book being rendered must not queue behind a nicety.
- **Lazily, before a story**, from the story queue, if the sheet is missing or
  its `photo_hash` no longer matches. This is the guarantee — a restart, a busy
  card, an Ollama that was down, a restored backup all end here — and the story
  that triggers it already has its sheet.
- **On `POST /profiles/<id>/hero-sheet/rederive`**, when a parent asks from the
  app. The only path that ignores the `photo_hash` cache, and the only one that
  waits for the card rather than stepping aside.

The same photo never costs a second model call, however many books the child
gets, unless a parent asks for one.

**The parent's half.** The wardrobe is chosen for a child, not fixed forever:
`PUT /profiles/<id>/hero-sheet` replaces the `outfit` and the `prop` with
whatever the parent typed, and touches nothing the photo was read into. A
parent may also write a wardrobe before any photo has reached the PC. The row
then exists with its three derived values empty — `isDerived` is false — and the
story planner treats it exactly as it treats no sheet at all and invents the
appearance itself, until the first photo fills the other half in. Which is also
why a re-derive keeps the wardrobe: the two halves have two owners.

**On the card.** The pass is a third Ollama tenant at the one-GPU gate. It takes
a turn like either queue, and the gate unloads its model before the card changes
hands, so ComfyUI never starts a render with a vision model still resident.

**Not backed up, not synced.** The sheet is derived data: a
[master-library backup](#master-library-backups) carries the photos, and the
sheet is read again from those. A **restore empties the table** rather than
leaving it — the restored profiles are a different set, and a sheet describing a
child the library no longer has would be both wrong and, since it references
`profiles(id)`, a foreign-key failure on the restore itself.

It is **not in the sync manifest** either, and that one is a choice rather than
an omission. The manifest is broadcast metadata: every paired device downloads
all of it, every sync, and applies it wholesale. How one named child is drawn is
not that. The three `/profiles/<id>/hero-sheet` endpoints hand the sheet to a
device that asked for one child by id, when a parent opened that child's editor,
and the app keeps no copy — so the sheet still lives in exactly one place.

**Never logged.** The log lines are `hero sheet derived`, `refreshed`,
`unchanged`, `deferred` or `unavailable` — verdicts with no profile id and not
one word of the sheet or the photo.

### What face likeness actually means here

**Recognizably similar, not photographic.** A 4 GB SD 1.5 setup with an
IPAdapter face model reproduces a child's general look — hair, colouring,
face shape, the overall impression — well enough that a family recognizes who
the story is about. It is not a photograph of the child and will not survive
close comparison with one: features drift between pages, and a specific
detail such as glasses or a birthmark may or may not appear. The adapter
weight is deliberately below full strength, because at full weight the photo
drags every page towards its own pose and lighting and the illustration stops
looking drawn. If you expected a likeness that could be mistaken for the
child, this setup will disappoint you; if you expected the child to be
recognizable in a picture book, it delivers that.

**The photo is never used directly.** It is first redrawn as a smiling
storybook portrait, and only that portrait is shown to the face adapter. This
is not a nicety: a photographic reference carries its own lighting, texture and
expression into every page, and the pages come out as distorted photorealistic
images of the child — a photo of a crying child produced a book of crying
children. Redrawing it first means the book inherits the face and nothing else.

For the best likeness, give the profile a **clear, front-facing, well-lit
photo** where the face fills a good part of the frame. The portrait pass sees
one centre-cropped 512x512 square, so a sharp head-and-shoulders shot has far
more to work with than a distant, dim or side-on one. The expression does not
matter — the hero smiles either way.

### Job lifecycle

```text
queued ──▶ rendering ──▶ completed
              │
              └──▶ failed / cancelled
```

- **queued** — accepted, waiting for the worker; reports `queuePosition`.
- **rendering** — pages are going through ComfyUI one at a time; `progress`
  reads `Rendering page 3 of 6.`
- **completed** — every page was attempted and at least one image landed.
  **A completed job may still have failed pages**: the counts, not the
  status, say how the book turned out.
- **failed** — no image at all. Either ComfyUI was unreachable when the job
  started, or every single page failed.
- **cancelled** — stopped after the page that was in flight.

A page that fails marks **its own row** `failed` and the job carries on with
the remaining pages: a six-page book is never re-rendered from scratch
because page five timed out. Calling `POST /stories/<id>/illustrate` again
picks up exactly the pages that are still outstanding.

One exception, deliberately: when ComfyUI is not reachable at all, the job
fails immediately and **no row is touched**. Flipping six pages to `failed`
because the renderer was not running is not information, it is noise.

Each finished page is one small transaction — the row's status plus the
story's `updated_at_utc` — so a row can never claim an image the manifest
does not advertise, and the pages that did finish stay permanently done.

Typed failure codes: `comfyui_unavailable`, `comfyui_timeout`,
`comfyui_failed`, `invalid_image_output`, `image_write_failed`,
`library_write_failed`, `missing_custom_node`, `cancelled`, `internal_error`.

### What illustration logs

Job ids, story ids, page indexes, counts, timings, typed error codes, and
whether a reference photo was used — and nothing else. Scene descriptions,
prompts, file paths and image bytes never reach the console or a log.

## Pairing flow (human-in-the-loop)

1. On the phone, tap *Pair with PC* → the app calls `POST /pair/request`.
2. The PC screen shows the 6-digit code; type it into the phone within
   2 minutes.
3. The app calls `POST /pair/confirm`; on success the phone stores the
   returned bearer token and uses it for all further calls.

Codes expire after 2 minutes, live only in memory (a restart clears them),
and wrong attempts are capped at five.

To undo a pairing later, the parent opens the app's AI connection settings on
any *other* paired device, finds the device by name in **Devices paired with
the PC** — with when it was paired and when the PC last heard from it — and
removes it, which is `DELETE /devices/<deviceId>`. The removed device's next
call is refused and the app there tells its holder to pair again.

## Security model

- **Loopback by default.** Binds to `127.0.0.1`; LAN exposure requires an
  explicit config change. Never port-forward to the internet (see warning).
- **Token authentication everywhere** except `/health` and the two pairing
  endpoints. Tokens are 256 bits from a cryptographically secure source;
  only SHA-256 hashes are stored, compared in constant time.
- **Pairing codes** are 6 digits, expire in 2 minutes, exist only in
  memory as hashes, are compared in constant time, and invalidate after
  five wrong entries. Request rate limit: 5 per minute.
- **Revocation is immediate.** `DELETE /devices/<deviceId>` marks the token
  row revoked, and the next call carrying that token fails authentication.
  A device cannot revoke itself. Each accepted call records only the moment
  it happened, in `devices.last_seen_at_utc` — never what was asked for.
- **Bounded requests**: bodies larger than 25 MB are rejected with `413`;
  slow handlers time out with a typed error instead of hanging.
- **Privacy by design**: request bodies, photo bytes, story content, scene
  descriptions, prompts, child names, model output, image bytes, file paths,
  tokens, and pairing codes are never logged. No third-party network calls —
  the only outbound traffic is health probes, story generation and
  illustration rendering against the configured local Ollama/ComfyUI URLs.
- **Bounded generation**: one job at a time, a configurable timeout per
  call (default 15 minutes; a job makes two calls), a capped number of
  attempts shared by both passes, and cancellation that aborts the in-flight
  request instead of orphaning it.
- **Bounded rendering**: one page at a time behind the same one-GPU lock, a
  configurable per-page timeout (default 5 minutes) that interrupts the
  abandoned render so the card is freed, a 30-second cap on every metadata
  call to ComfyUI inside that budget, a 16 MB ceiling on a downloaded image,
  and a PNG magic-byte check before anything is stored.
- **Reference photos**: at most 2 MB, accepted only as JPEG or PNG, and only
  when the bytes match the declared type. Stored under the profile id inside
  `photos/`, so an id that could escape the folder is refused before the
  database is even asked. The bytes are never logged, never echoed, and never
  sent anywhere but the local ComfyUI.
- **Master library**: all structured data in SQLite under `db/master.db`,
  writes wrapped in transactions; binary assets stay in folders referenced
  by stable ids and relative paths (never blobs), written atomically via
  temp-file rename. A relative path that could point outside the library is
  refused, so a restored row can never reach another folder.
- **Bounded sync**: the manifest is metadata only — never prose, never file
  bytes — and every device sees only its own sync watermark.
- **Management listings are metadata too**: `GET /profiles` and `GET /stories`
  carry names, titles and counts — no page prose, no scene descriptions, no
  photo bytes and no file paths. Page prose exists in exactly one answer,
  shared by `GET /stories/<storyId>` and `GET /sync/stories/<storyId>`. A
  refused filter names the parameter and never repeats its value, and nothing
  in this group is logged.
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

Tests mock Ollama/ComfyUI at the client boundary and always use temporary
directories, so nothing real is ever touched — no model is loaded and no
render is started. The production Ollama client is additionally exercised
against a local stub HTTP server, which is how the UTF-8 encoding, timeout
and abort behavior stay honest.

Illustration tests replace only `ComfyUiClient`: the queue, the one-GPU lock,
the workflow builder, the atomic file writes and the row updates are all the
real implementations, and the fake renderer returns a genuine PNG because the
bridge checks magic bytes on everything it stores. The fake also answers what
node classes it "has", which is how the missing-Impact-Pack failure is proved
without installing anything. The workflow tests assert exact node wiring —
which node reads which slot of which other node — because that is what a
rendering bug actually looks like.

`postman_collection_test.dart` needs no services at all: it parses the
committed collection and holds it against `bridgeRoutes`, both ways — every
route has a request, and every request has a route — plus the empty variables
and the three `noauth` opt-outs.

Sync, deletion and backup tests mock nothing: they run the real SQLite
database, the real file system inside a temporary library, and the real
crypto at production cost. The backup tests build their own payloads with the
public codec, which is how "no partial restore" is proved with a genuinely
failing restore instead of a stubbed one.
