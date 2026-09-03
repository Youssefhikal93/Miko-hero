# Codebase map

This document explains every source file in the repository, which feature it
belongs to, and the architecture rules that keep the app maintainable. Update
it whenever a file is added, moved, or changes responsibility.

## Architecture

The dependency direction is one-way. Widgets never touch storage, crypto, or
generation directly; they go through a feature controller, which uses a core
service, which uses local storage.

```mermaid
flowchart LR
    UI["Pages and widgets<br/>(features/, shared/)"] --> Controllers["Feature controllers<br/>(features/*_controller.dart)"]
    Controllers --> Services["Core services<br/>(core/generation, backup, export, narration, security)"]
    Services --> Storage["Local persistence<br/>(core/storage, shared_preferences)"]
    Services --> Bridge["PC bridge client<br/>(core/ai_connection)"]
    Bridge --> LocalAI["Family PC: Ollama now,<br/>ComfyUI later"]
```

Rules that every change must respect:

- Widgets read state through Riverpod providers and call controller commands;
  they never construct services or repositories.
- Each feature has its own controller. `AppController` only loads the snapshot
  and publishes one storage already accepted; it does not grow feature logic.
- Every change to family state goes through `LibraryTransaction`, the one seam
  that validates, persists, and only then publishes. A feature controller never
  writes to `LocalRepository` and never publishes a snapshot itself, so a failed
  write can never leave a screen ahead of what the device actually holds.
- Core services are Flutter-framework-light and platform-boundary focused so
  they stay unit-testable without a device.
- Stored JSON is validated on read (`AppState.validated`); corrupt local data
  surfaces as a typed error instead of being silently overwritten.
- User-reachable "that no longer exists" states throw `Exception` subtypes such
  as `UnknownEntityException` so screens can recover; only genuine programming
  bugs stay `Error`s.
- Expensive Argon2id work goes through `compute` with a top-level entry point,
  and the services keep an injectable deriver so tests can skip the isolate.
- Everything is free and local: no accounts, no analytics, no paid or required
  cloud service. The only network client talks to the family's own PC bridge
  on the home network, and only when the parent selected Local AI.
- All authored public APIs carry `///` documentation (`public_member_api_docs`
  is enforced by the analyzer).

## Entry point and app frame — `lib/app/`, `lib/main.dart`

| File | Responsibility |
| --- | --- |
| `lib/main.dart` | Boots the Flutter binding and runs the root widget inside a Riverpod `ProviderScope`. |
| `lib/app/iam_hero_app.dart` | Root `MaterialApp.router` widget; binds the persisted locale and active-profile theme to the routed application, and asks for the one automatic library synchronization that follows an app start. |
| `lib/app/app_controller.dart` | Loads the complete persisted `AppState` on startup and publishes snapshots `LibraryTransaction` has already written; `commit` is that transaction's publish half and has no other caller in the application. Also the composition root: hosts the repository and service providers and the `storyGeneratorProvider`, which follows the parent's saved generator mode and falls back to the demo only while those settings are still loading. |
| `lib/app/app_router.dart` | go_router configuration: all routes, the shell wrapper, and parent-PIN gating for parent-only destinations (`/settings`, `/kingdom`, `/profiles`, `/review`, `/generation`). `/library` also reads the optional `child` query parameter that names whose shelf to open on. |
| `lib/app/app_shell.dart` | Responsive navigation frame around every route: app bar plus drawer and bottom navigation on mobile, extended rail from `desktopBreakpoint` up. The five destinations, their icons, and their routes are declared once and shared by all three. The bottom bar prints no labels — each destination is an icon over a dot that appears only under the active one, in the active child's accent — and keeps its localized name in its semantics label and tooltip; the drawer and the rail stay labelled. The app bar carries no exit of its own on any route: the reader prints its own close beside the hero. On a phone the bar is absent on Home, the shelf, the creation form and the reader, which paint their own header row; the drawer still opens with an edge swipe there. |
| `lib/app/app_theme.dart` | The shared visual system: the named redesign palette tokens (`night`, `tile`, `sunken`, `candle`, `candleLight`, `onCandle`, `light`, `frost`, `muted`, `mutedDeep`, `hairline`, `hairlineWarm`) every component theme reads from — cards, fields, chips, buttons, app bar, dialogs, and the bottom bar, rail, and drawer; the per-child color schemes (rose for girls, cyan for boys, plus saved custom colors) that stay the accent on rings, indicators, and selected states; the Outfit interface typography, whose `wght` axis is pinned per style because the bundled variable file defaults to its thinnest instance; and the reader's bedtime prose, surface, and warm page wash. `interfaceFontFamilyFor` is the one place the Arabic fallback is decided, following `AppLanguage.usesLatinScript` exactly as story prose does. |

## Domain models — `lib/core/models/`

| File | Responsibility |
| --- | --- |
| `app_language.dart` | The four supported languages (English, Arabic, Swedish, Somali) with ISO codes, used for both interface chrome and story text. |
| `app_state.dart` | The complete persisted application snapshot: `schemaVersion`, locale, profiles, active profile, and stories. `AppState.validated` enforces uniqueness, referential integrity (every story belongs to an existing profile), and newest-first story order, and is what every library transaction is checked against before it is written. `profileById` and `storyById` resolve one entity; `requireStoryById` reports a missing book as `UnknownEntityException`. Writes version 4 (reading comfort and reading rewards; 3 added kingdom personalization, 2 added birth dates), reads versions 1 through 4, and refuses anything newer with `UnsupportedSchemaVersionException`. `requireSupportedAppStateSchemaVersion` is shared with the single-story share payload. |
| `child_profile.dart` | One child's private profile: name, optional `birthDate` plus the legacy stored age it replaced, required Girl/Boy choice, optional base64 reference photo (≤ 2 MB), saved theme color, story preferences, the `KingdomTheme` decoration, `ChildReadingSettings`, and the identities of stories finished on this device. `ageOn`/`age` compute a birthday-accurate age and fall back to the legacy value. Every `with…` transformation goes through one private copy helper so a newly stored field cannot be dropped. Includes the validated editor form model. |
| `child_reading_settings.dart` | Per-child reading comfort: the four `ReaderTextSize` steps (scaling the theme body size) and the easy-reading font switch, which resolves to the bundled Latin-script family and stays absent for Arabic. Deliberately separate from `child_story_preferences.dart`, which is prompt context copied into every generated story. |
| `reading_badge.dart` | The 1, 5, 10, and 25 finished-story badges plus the pure helpers for badges earned, the badge reached exactly now, and the next one. Counts only: no streaks, dates, or daily goals. |
| `shared_story.dart` | Payload of one encrypted single-story file: snapshot `schemaVersion`, the complete `StoryBook`, and the hero's display name for the import preview. Carries no photo and no other profile field. Also owns `DuplicateStoryException`, raised when an imported story identity already exists locally. |
| `kingdom_theme.dart` | One child's My Kingdom decoration: castle style, avatar frame, backdrop flavor, and favourite symbol. Every choice is optional and enum-name encoded; an absent field decodes to its default and an unknown stored name is refused with a `FormatException`. |
| `local_identity.dart` | `newLocalId`: one collision-free device-local identity from a per-kind prefix and a UTC microsecond stamp, checked against the identities already taken. Shared by child profiles and generation jobs so neither drifts into its own scheme. |
| `unknown_entity_exception.dart` | `UnknownEntityException`, the recoverable error thrown when a command targets a profile, story, or queued job that no longer exists locally. |
| `child_story_preferences.dart` | Per-child story defaults chosen by the parent: favorite topics, recurring story world, default story language, and `SafetyTopic` exclusions destined for future local AI prompts. |
| `generation_job.dart` | One durable story-generation request with lifecycle states (`queued`, `running`, `failed`, `cancelled`). Jobs survive app restarts so requests are never silently lost. |
| `story_models.dart` | Everything a story is made of: `StoryLength` (6/8/10 pages), `IllustrationStyle`, `StoryReviewStatus` (draft/approved), `StoryHero`, `StoryPrompt` (with legacy-JSON migration), `StoryPresentation`, `StoryRequest`, `StoryPage` (prose plus a `sceneDescription` reserved for ComfyUI), `StoryContent`, and the persisted `StoryBook` with favorites and collection labels. `withProfileId` re-attaches a whole book to another local profile, which is how an imported story file joins a chosen child's shelf. |

## Core services — `lib/core/`

### Generation — `core/generation/`

| File | Responsibility |
| --- | --- |
| `story_generator.dart` | The `StoryGenerator` boundary: `generate(StoryRequest) → StoryBook`, implemented by the demo generator and by the local AI adapter (see `docs/LOCAL_AI_INTEGRATION.md`). Also `CancellableStoryGenerator`, the optional extension for generators whose work runs on another machine and must be stopped there. |
| `demo_story_generator.dart` | Clearly labeled offline sample generator. Produces deterministic, gender-aware prose in all four languages, weaves in the child's saved preferences and recurring world, and must never be presented as AI output. |
| `local_ai_story_generator.dart` | The local AI adapter: submits one request to the paired PC bridge, polls the job every two seconds until it is terminal, and maps the completed payload onto `StoryBook` after checking language, page count, and page order. Every failure — unreachable, unauthenticated, failed job, cancelled, unusable payload, timeout — throws a typed `BridgeException`; it never returns demo content and never yields a partial book. Implements `CancellableStoryGenerator` so cancelling in the app also stops the PC. |

### Local AI connection — `core/ai_connection/`

| File | Responsibility |
| --- | --- |
| `bridge_client.dart` | Typed HTTP client for the PC bridge over `package:http`, so the same code runs on mobile and web: bearer token attached, bodies sent as explicit UTF-8 with `charset=utf-8` (Arabic corrupts otherwise), one bounded timeout per call, and every transport or bridge failure converted into a typed reason. Covers health, pairing, generation, the three synchronization calls, and delete-everywhere. Also owns the default address and `parseBridgeBaseUrl`, which refuses anything that is not a plain `http`/`https` origin. |
| `bridge_exception.dart` | `BridgeFailure` and `BridgeException`: the typed reason a bridge call failed, deliberately carrying no bridge-authored prose so every parent-facing sentence is localized in the app. `blockedByBrowser` is the web build's reading of a refused connection, because a browser hides whether Chrome's Local Network Access permission, a missing allowed origin, or a PC that is off stopped the call; its message names the permission first. |
| `bridge_models.dart` | Validated payloads of the bridge contract: health statuses, job submission, job status, the completed story and its pages (including the optional owning profile and timestamps a synchronization download adds), the exact generate-request field names, and the shared bridge-timestamp parser. |
| `bridge_sync_models.dart` | Validated payloads of the synchronization contract: the metadata-only manifest with its profile, story, illustration, and deletion entries, one downloaded story, and the delete-everywhere answer. Absent lists decode as empty and both spellings of the deletion list are accepted, so one added field cannot fail a whole sync. |
| `library_sync_state.dart` | What this device already took from the master library: the last reported watermark, the bridge `updatedAtUtc` of every downloaded story, and the "not wanted offline" list that keeps sync from re-downloading a story the parent removed here. Stories themselves stay in `AppState`, which is what makes them readable offline. |
| `library_sync.dart` | One synchronization: read the manifest, download only the stories that are new or whose timestamp moved, then report the manifest back — and only then hand the caller a library to persist, so a failure at any step changes nothing locally. Downloaded stories arrive approved with their pages' `BridgeStoryProvenance` rebuilt; a story generated on this device is adopted without a transfer so a pending review is never overridden; a story whose child has no local profile is reported instead of being placed on an invented profile. `mergeSyncedLibrary` applies the outcome to the library as it is at persistence time. |
| `ai_connection_settings.dart` | `StoryGeneratorMode` (demo or local AI) and the persisted `AiConnectionSettings` (mode plus bridge address). Holds no secret. |
| `bridge_credential.dart` | The stored pairing record — token, device name, pairing time — plus the device-name and pairing-code validators. Stored like the parent-PIN verifier under its own key, never logged, and `toString` never reveals the token. |
| `bridge_story_provenance.dart` | Builds and reads back the bridge story and illustration identities carried inside `StoryPage.sceneDescription`, following the demo generator's em-dash segment convention, so no stored story needs migrating when ComfyUI lands. `storyIdOf` is how every surface recognizes one master-library story, including a story generated here whose local identity came from its queued job. |
| `local_ai_progress.dart` | `LocalAiStage` and `LocalAiProgress`: what the PC is doing right now, as an enum rather than the bridge's English progress sentence. |

### Illustrations — `core/illustrations/`

| File | Responsibility |
| --- | --- |
| `illustration_service.dart` | Draws one bridge story's page images on the paired PC: starts the job, polls it (`IllustrationProgress` carries counts, never prose), bounded by a whole-job timeout because one page takes minutes on a home GPU, then hands the finished pages to the downloader. Forgiving about everything except the PC itself: an unusable photo is skipped, a page the PC fails on is reported and the rest still fetched, cancelling keeps what was drawn. |
| `illustration_downloader.dart` | Fetches finished page images into the local cache one identity at a time, so a single refused image never blocks the rest; `IllustrationDownloadReport` counts fetched, not-yet-drawn and failed pages separately. |
| `illustration_store.dart` | The cache boundary: `IllustrationStore`, `CachedIllustration` (bytes plus the ETag they arrived with), and identity validation so nothing that could escape a file name or object-store key ever reaches a platform implementation. |
| `illustration_store_io.dart` / `illustration_store_web.dart` / `illustration_store_platform.dart` | The two platform caches and the single conditional import that picks one. Files under application support on every non-web platform (temp-file write then rename, so no half-written PNG survives); IndexedDB on the web, because `localStorage` is text-only and a few megabytes. |
| `illustration_providers.dart` | Riverpod wiring: the platform store, the poll interval and clock (both injectable for tests), and `illustrationBytesProvider` watched per page so one finished download repaints exactly that page and a broken cache falls back to placeholder art. |
| `reference_photo.dart` | Reads a usable JPEG or PNG face reference out of a stored profile by its magic bytes, or null meaning "send no photo" — the book still gets pictures, just without the likeness. |

### Storage — `core/storage/`

| File | Responsibility |
| --- | --- |
| `local_repository.dart` | The only code that touches `shared_preferences`, and this device's implementation of `LibraryStore`. Persists locale, profiles, stories, the generation queue, the stored schema version, the AI connection settings, the bridge pairing token, and the library synchronization record; validates on load; `replaceState` swaps the whole snapshot during a backup restore while preserving the device's parent PIN and its pairing, and rolls every replaced key back if any write fails midway. Deleting all family data clears the sync record too, so a rebuilt library can be synced back. The bridge pairing token is read through `BridgeCredentialStorage`; a store that cannot answer leaves the device readable as unpaired, or keeps its plaintext copy, instead of failing the whole AI connection. |
| `library_transaction.dart` | The one seam every change to family state goes through: apply the mutation to the loaded snapshot, check the result with `AppState.validated` (which is also what re-sorts a shelf newest first), write it through `LibraryStore`, and publish last. A refused or failing write publishes nothing. Offers `updateStory`, `mutateStories`, `mutateProfiles` (profiles and the active child together, in that order, skipping the profile write when the list came back unchanged), `setLocale`, and the two whole-snapshot swaps `replaceState` and `clearFamilyData`. |
| `library_store.dart` | `LibraryStore`, the six writes a library transaction performs, implemented by `LocalRepository`. Exists so the transaction's persist-then-publish guarantee can be tested against a store that refuses a write, which a healthy preferences file never does. |
| `bridge_credential_storage.dart` | The seam for the bridge's bearer token: `SecureBridgeCredentialStorage` (platform-protected store on phones and desktops), `PreferencesBridgeCredentialStorage` (the web build, where a browser has nothing more protected than `localStorage` and the web plugin failed silently in release), and `InMemoryBridgeCredentialStorage` for tests. The repository migrates the legacy plaintext preference into whichever store is active. |

### Backup — `core/backup/`

| File | Responsibility |
| --- | --- |
| `encrypted_backup_codec.dart` | The shared `EncryptedEnvelopeCodec` — Argon2id key derivation (19 MiB, t=2, p=1) on a background isolate plus AES-256-GCM, with the envelope's format name and authenticated associated data supplied per payload type — and `EncryptedBackupCodec`, which uses it for portable `.iamhero` family snapshots. Typed exceptions distinguish wrong password, malformed or foreign file, oversized input (64 MiB cap), and a snapshot from a newer app version. |
| `story_share_codec.dart` | Encrypts and validates one `.iamhero-story` file on the same envelope with a distinct format name and associated data, so a story file and a full backup can never be opened as each other even under the same password. |
| `backup_file_service.dart` | Platform file flow for backups: save and pick encrypted files on Android, iOS, and web through `file_picker`. |
| `story_share_file_service.dart` | Platform file flow for single-story files: pick and save `.iamhero-story` on Android, iOS, and web, reusing the backup size cap and read error, with a bounded safe file name derived from the story title. |

### PDF export — `core/export/`

| File | Responsibility |
| --- | --- |
| `story_pdf_service.dart` | Renders one approved story as an A4 **picture book** entirely on-device: a cover carrying the story's first illustration and its title in a display face, a dedication page ("this book belongs to…", the child's kingdom badge, the moral, the creation date), one sheet per story page with the picture over roughly the top two thirds and the prose in a soft rounded panel beneath a page-number badge, and a back cover with the moral and the app mark. The book's own words are printed in the **story's** language, loaded through `AppLocalizations.delegate`, not in the parent's interface language. Places the child's photo on the cover only when the parent asked for it at export time, and never on inner pages. Pages with no picture get a title-led text layout instead of a hole. Loads fonts sequentially because concurrent `rootBundle.load` calls resolve empty under the test binding, and loads only the one display face the story's script needs. |
| `story_pdf_layout.dart` | `StoryPdfLayout` — reading direction and every measurement that depends on it (badge corner, accent-bar side, mirrored panel padding), resolved eagerly so Arabic mirroring is assertable in a test rather than only visible in the file — and `StoryPdfPalette`, the wash/panel/accent/ink colours each `IllustrationStyle` prints in. |
| `story_pdf_symbols.dart` | `paintKingdomSymbol`: each of the twelve favourite kingdom symbols drawn as PDF vector shapes for the dedication page. Deliberately not an icon font, so the export depends on nothing outside this app's own asset bundle. |
| `pdf_file_service.dart` | Opens the platform save dialog for a rendered PDF and produces a safe, bounded file name from the story title. |

### Narration — `core/narration/`

| File | Responsibility |
| --- | --- |
| `narration_service.dart` | Device text-to-speech boundary (`supports`, `speak`, `stop`) so the reader never depends on a TTS plugin directly. Deliberately thin: one utterance at a time, with completion the only progress signal required from a platform. |
| `device_narration_service.dart` | The real implementation using voices already installed on the device; free and offline. |
| `narration_options.dart` | Validated narration settings: speech speed presets, narration scope (current page or rest of story), the off/5/10/20-minute `NarrationSleepTimer`, and the `NarrationRequest` value passed across the boundary. |
| `sentence_splitter.dart` | Pure sentence splitter shared by narration and the reader highlight. Splits on `.` `!` `?` `؟` `…` and line breaks, keeps a run of terminators with its sentence, drops blank fragments, and reports each sentence's offsets inside the original page text so the highlight never rewrites the story. |

### Parent security — `core/security/`

| File | Responsibility |
| --- | --- |
| `parent_security.dart` | The stored PIN verifier record (version, salt, Argon2id verifier — never the PIN) plus its failed-attempt counter and cooldown, the escalating throttling policy (5 free attempts, then 30 s / 1 m / 2 m / 5 m cap), the in-memory parent access state, and the typed attempt result. Version-1 records still decode as having no attempt history. |
| `parent_security_service.dart` | Hashes and verifies the optional 4–8 digit parent PIN with Argon2id and a constant-time comparison, deriving on a background isolate through an injectable deriver. |

## Features — `lib/features/`

### Home — `features/home/`

| File | Responsibility |
| --- | --- |
| `home_page.dart` | Home's widgets: the "Reading as" header, a greeting by time of day over one line about what is really waiting, the tiles a family's own state has something to say with, and the "On the shelf" strip whose "See all" hands the rest to the library. A family with no profiles sees the setup prompt and nothing else. Home offers no secondary command on a book, so its tiles carry no overflow control. The page decides nothing: it asks `HomeView.of` once per build and lays the answer out, choosing only tile spans and turning the greeting's `HomeTimeOfDay` and `HomeGreetingLine` into localized sentences. |
| `home_view.dart` | Everything Home decides, from one stored snapshot and one supplied moment. `HomeView.of` resolves the keep-reading book (the newest approved story on the active child's shelf that this device has not recorded as finished — nothing about a reading position is stored, so there is nothing to remember and nothing to migrate), the "On the shelf" strip (the same shelf with that featured book left out by identity, capped at six), the count of drafts waiting for a parent, the "See all" route naming the active child so the shelf opens where the strip left off (absent exactly when there is no strip), `homeTimeOfDay`, and `HomeGreetingLine` — which of the three things Home has to say is true, as a kind rather than a sentence, so the wording stays in the widget. |
| `home_hero_switcher.dart` | Home's header and the family switcher behind it: the active child's name under "Reading as", their photo ringed in their own accent, and a bottom sheet listing every child. Picking one runs `ProfileController.activateProfile`, which is what makes the theme and every other screen follow. |
| `home_tiles.dart` | The four Home tiles and the rounded surface they share: keep reading (the shared `StoryCover` under a "Keep reading" label and the book's page count, opening the reader), new story, the active child's reading badges out of four (read-only), and the parent's drafts row, whose tap goes to `/review` where the parent gate already lives. |

### Profiles — `features/profile/`

| File | Responsibility |
| --- | --- |
| `profile_controller.dart` | Commands for child identity: add/edit/delete profiles, active-profile switching, gender, theme color, story preferences, the kingdom decoration, reading comfort, and the reading-reward history (`recordFinishedStory` returns the badge just earned; `forgetFinishedStory` drops a deleted story from every child). Each one is a single `LibraryTransaction.mutateProfiles` call, so profiles and the active identity stay one atomic write. Resolves the saved birth date and rejects any resulting age outside 1–17, while letting a legacy age-only profile keep its stored age. New profiles seed their default story language from the current locale. |
| `profile_page.dart` | Profile list and the editor form (name, localized birth-date picker bounded to ages 1–17, Girl/Boy choice, reference photo). |

### My Kingdom — `features/kingdom/`

| File | Responsibility |
| --- | --- |
| `my_kingdom_page.dart` | Family hub for switching the active hero and personalizing each child's app color palette, plus the active child's castle header, framed avatar, favourite symbol, and page backdrop. |
| `kingdom_style_card.dart` | Parent-editable castle, photo frame, backdrop, and favourite-symbol choices for the active child. Each selection persists immediately through `ProfileController` and confirms with a snackbar. |
| `kingdom_decorations.dart` | Every kingdom decoration drawn locally: `KingdomCastle` and the framed `KingdomAvatar` (`CustomPaint`), the backdrop gradient, and the bounded Material icon for each favourite symbol. Adds no binary asset and makes no network call. |
| `story_preferences_card.dart` | Parent-editable per-child story preferences: favorite topics, recurring world, default language, and safety-topic exclusions, with a four-language chip dialog. Also hosts the reading-comfort controls (text size and easy-reading font), which save immediately and state that Arabic prose keeps its usual letters. |
| `reading_rewards_card.dart` | The active child's finished-story count, all four badges drawn with Material icons, and progress toward the next badge. Read-only and count-based; no streaks or dates are shown because none are stored. |

### Story creation — `features/story_creation/`

| File | Responsibility |
| --- | --- |
| `story_creation_page.dart` | Tap-first request form: profile photo cards (plus the existing add-profile route), inherited Girl/Boy context with the shared selector only for legacy profiles missing it, plain theme and moral fields, 6/8/10 page segments, illustration-style cards, and self-scripted language chips. Its header waits for the saved selection before naming the actual Demo or Local AI generator, the selected child's saved preferences and safety-exclusion count stay visible, and the unchanged progress panel follows the paired PC stage by stage. |
| `story_controller.dart` | Owns the generation transaction: validates the request, enqueues a durable job, waits for the saved generator selection so a Local AI family is never quietly handed the demo, runs the generator, and hands the finished draft to `LibraryTransaction` — a failed generation writes no story, and approval, favourites, collections, and deletion are one-line transactions too. Cancelling the request that is currently running also stops it on the PC. Deleted profiles and stories surface as `UnknownEntityException`. |
| `generation_queue_controller.dart` | Persists the generation queue independently of app state so interrupted or failed requests survive restarts and can be retried or cancelled. Commands for a job that no longer exists raise `UnknownEntityException`. |
| `generation_center_page.dart` | Parent-only generation center: honest report of the selected generator and its readiness, the localized stage of a job running on the PC, and retry/cancel controls. Cancel stays enabled while a job runs, because it is the parent's only way to stop a story the PC already started. |
| `generation_progress_controller.dart` | Holds the current `LocalAiProgress` above the generator boundary so the creation screen and the generation center can show a localized stage. Null whenever nothing is running, and always null for the demo generator. |

### Parent review — `features/review/`

| File | Responsibility |
| --- | --- |
| `story_review_page.dart` | Parent-only draft queue and full-text review surface. Every generated story starts as a draft, invisible to the child, until the parent approves or deletes it. The page preview uses the hero's saved reading comfort so the parent reads what the child will read. Approval opens the reader. |

### Library — `features/library/`

| File | Responsibility |
| --- | --- |
| `story_library_page.dart` | The shelf's widgets: the shelf name over a line naming where the books really are — only this device, or in step with the PC, read from the stored connection and pairing — the import-story-file action, a parent-only badge when drafts await review, and the title search field. Below it, one tappable chip per child (initial, hero name, and their favourite symbol once a family has more than one), each selected chip in that child's own accent; then All with its count, Favorites, and one chip per collection label on that shelf. The books themselves are laid out on the shared mosaic — the newest on a full-width cover tile and the rest on rows, one column on a phone and three from the desktop breakpoint — and every tile carries the overflow control, so favouriting, collections, sharing, illustrating, and both kinds of deletion stay one tap away behind the same parent gates. The page decides nothing: it keeps the tapped chip, the selected filter, and the search text as view state — nothing new is persisted — and asks `ShelfView.resolve` once per build for everything it draws. |
| `shelf_view.dart` | What the shelf shows, decided away from the widgets. `ShelfFilter` is a sealed value — `AllStories`, `FavoriteStories`, `StoriesInCollection(name)` — replacing the `collection:`-prefixed string that used to encode all three, under which a collection a parent named `collection:bedtime` decoded back as `bedtime`. `ShelfView.resolve` answers one build: whose shelf is on screen (in order of how explicit the wish was — a chip already tapped, then the child the route's `child` parameter names, then the child the family is reading as, then the first profile, falling through any of them that has been deleted), which approved books of that child's the search left, which collection labels that shelf has in case-insensitive order, whether the selected filter still exists or falls back to All, and which books survive both the search and the filter. |
| `story_collections_dialog.dart` | Editor for a story's collection labels (for example bedtime, learning, adventures) with bounded, deduplicated parsing. |
| `story_share_controller.dart` | Commands for single-story files: encrypt one stored story with its hero name, save or pick the file, decrypt a selected file, and import it into a chosen profile through `LibraryTransaction`, which is what puts the imported book in shelf order. Refuses an already present story identity (`DuplicateStoryException`) and a destination profile that no longer exists (`UnknownEntityException`). |
| `story_share_actions.dart` | The parent-gated export and import flows: password prompt, decrypted preview (title, page count, hero), destination-profile choice, and one localized message per typed failure. Talks only to `StoryShareController`. |
| `illustrate_story_controller.dart` | Owns the one picture run this device may have going at a time, as `IllustrateStoryRun` (running, finished or failed in one value so a dialog can never show a state the run is not in). Nothing is persisted: the artwork lives in the image cache and the PC master library, so a restart loses none of it. |
| `story_illustrate_actions.dart` | The parent-gated "make the pictures" flow on a PC-library story's card: shows what the run costs first (minutes per page, the child's photo travels to the PC), then a live view that names the page being drawn in one sentence rather than a spinner. Offered only for stories the PC holds and only while this device is paired. |
| `story_delete_actions.dart` | The parent-gated deletion flow. A demo story keeps today's single local deletion; a story that also lives in the PC master library offers the two clearly worded choices instead — remove this device's offline copy, or delete it everywhere. Delete-everywhere requires the PC and reports the typed bridge failure without removing anything locally. |

### Reader — `features/reader/`

| File | Responsibility |
| --- | --- |
| `story_reader_page.dart` | Full-screen reader, arranged as the redesign's Reader screen: the hero's ringed avatar, an exit, and the session-only bedtime toggle in a top row; swipeable pages with placeholder illustrations until ComfyUI and the spoken sentence tinted in place; then one control row of previous, the wide candle "Read to me" control (play, pause, resume, plus a stop control while narration runs) and next; then "Page x of y" beside one dot per page, both following swipes and button turns; then one icon row of reading speed, sleep timer, text size, and PDF export. Speed and sleep timer open the shared narration dialog that also owns spoken scope; text size writes the hero's saved reading comfort through `ProfileController`; export asks whether the cover carries the child's photo. Arabic keeps its right-to-left story layout with previous and next mirrored. Reaching the last page records the story as finished once per session and celebrates a newly earned badge. Three short rows rather than one long one, so a 360 px phone keeps full touch targets without wrapping. Only approved stories can be opened. |
| `narration_controller.dart` | Owns the reader's sentence queue, position, playback state, and sleep timer above the `NarrationService` boundary: speaks one sentence per utterance, pauses by remembering the sentence and resuming from its start, follows rest-of-story narration onto the next page, and stops when the reader turns to a page the queue did not ask for. The clock and countdown are injectable so all of it is testable without a device. |
| `story_export_controller.dart` | Coordinates PDF rendering and the save dialog; refuses to export unapproved drafts and resolves the hero's photo only when the parent opted in. |

### Settings — `features/settings/`

| File | Responsibility |
| --- | --- |
| `settings_page.dart` | Language selection, AI connection, backup, parent PIN, and the deliberate delete-all-family-data action. |
| `ai_connection_controller.dart` | Owns generator-mode and bridge-address persistence, the health probe, the pairing ceremony, and forgetting a paired device. Holds the token inside its state exactly as `ParentAccessState` holds the PIN verifier. Also hosts the injectable HTTP client provider every bridge call travels through. |
| `ai_connection_card.dart` | The parent-gated AI connection card: Demo/Local AI selector, validated bridge address, a connection test showing the three localized statuses, the pairing modal that asks for the 6-digit code shown on the PC, and the synchronization section. The token is never rendered. |
| `library_sync_controller.dart` | Owns synchronization and both deletion kinds as transactions, the merged library landing through `LibraryTransaction` and the synchronization record straight after it, so a record that fails to persist costs the next run a re-download instead of stranding stories: "Sync now", the one automatic sync after an app start on a paired Local AI device, removing one offline copy (which also records it as not wanted), deleting one story everywhere through the PC, and clearing that not-wanted list. Nothing is published before it is persisted, and a removed story also leaves every child's reading-reward history. |
| `library_sync_section.dart` | The card's synchronization block: the sync action, when this device last agreed with the PC, the short `x new · y updated · z removed` report, the children whose stories are waiting for a local profile, the typed failure of the last attempt, and the re-download control for stories removed from this device. |
| `settings_controller.dart` | Locale persistence and the delete-everything transaction, both through `LibraryTransaction`; it additionally drops the durable generation queue after a deletion. |
| `backup_controller.dart` | Orchestrates export (state → encrypt → save file) and restore (pick file → decrypt → preview counts → `LibraryTransaction.replaceState` → refresh queue). |
| `backup_settings_card.dart` | Backup UI: password dialogs with confirmation, restore preview, and distinct localized error messages per failure type, including a backup written by a newer app version. |
| `parent_access_controller.dart` | Owns PIN persistence, the throttled attempt policy, the injectable clock, and the session unlock/lock state used by gates. A `WidgetsBindingObserver` re-locks the session when the app is paused or hidden. |
| `parent_security_settings_card.dart` | PIN status, setup, two-step Change PIN (current PIN then the new one twice), re-lock, removal controls, and the note that a forgotten PIN has no recovery. |

## Shared widgets — `lib/shared/`

| File | Responsibility |
| --- | --- |
| `app_state_boundary.dart` | Standard loading/error boundary every page uses around persisted state. |
| `parent_access_gate.dart` | Two parent-PIN surfaces: a full-page gate for parent-only routes and a modal prompt for destructive actions (deletion, export, collection edits). Refuses input while a cooldown is stored and shows the remaining wait; PIN fields never retain the secret. Also owns the shared localization of one attempt outcome. |
| `gender_selector.dart` | The required Girl/Boy selector shared by profile and story forms. |
| `app_language_dropdown.dart` | Four-language dropdown with ISO badges, shared by app settings and story settings. |
| `screen_layout.dart` | Width-constrained page scaffold, the hero panel — a flat tile ringed by the active child's accent rather than a gradient surface — and section headings. Accepts an optional per-page backdrop gradient, used by My Kingdom for the active child's chosen flavor. Also `MosaicGrid` and `MosaicTile`, the shared mosaic every redesigned screen is laid out on: two columns on a phone and three from `desktopBreakpoint` (900 px, where the navigation shell also becomes a desktop frame), tiles asking for one or two columns, a span wider than the grid narrowed to it, row widths that always add up to the available width so nothing overflows sideways, and no scrolling of its own so it composes inside each page's scroll view. |
| `story_card.dart` | The story tile in three shapes: `StoryCardVariant.large` (cover, title, page count and date, favourite heart, Demo badge), `small` (cover and title) and `wide` (cover thumbnail, title, meta, overflow). Every variant is one full-size tap target that opens the story, and the large and wide shapes carry the favorite, collections, illustrate, share, and delete commands their surrounding feature allows in a single overflow menu, each running the feature's own callback so parent gating stays where it lives. The card renders only what it is given: a feature that allows nothing gets no overflow control. Also `StoryCover`, the single-book cover the parent review screen uses, and `StoryDemoBadge`. |
| `encryption_password_dialog.dart` | The password prompt shared by encrypted backups and single-story files, with per-file localized wording, optional confirmation field, the shared minimum length, and controllers that discard the secret with the modal. |
| `reading_text_style.dart` | `readingProseStyle` resolves book typography from one child's reading comfort: a 1.15× step above the interface body size with 1.6 line height, then the saved text-size scale; Newsreader for Latin script, the optional easy-reading family when selected, and the existing Arabic body face unchanged. Shared by the reader and the review preview. |
| `reading_badge_view.dart` | The bounded Material icon and localized name of one reading badge, shared by My Kingdom and the reader's congratulation message. |
| `local_ai_messages.dart` | One localized sentence per typed bridge failure and per generation stage, shared by the creation screen, the generation center, and the AI connection card. The bridge's own English text is never shown. |

## Localization — `lib/l10n/`

| File | Responsibility |
| --- | --- |
| `app_en.arb`, `app_ar.arb`, `app_sv.arb`, `app_so.arb` | The four source translation files. Every user-visible string lives here; add new strings to all four. |
| `app_localizations*.dart` | Generated by `flutter gen-l10n` — never edit by hand. |
| `somali_platform_localizations.dart` | Hand-written Material/Cupertino localization delegate for Somali, which Flutter does not ship. |

## Assets — `assets/`

| Path | Responsibility |
| --- | --- |
| `assets/fonts/NotoSans-Regular.ttf` | Latin-script **body** font embedded only for offline PDF export (English, Swedish, Somali). |
| `assets/fonts/Outfit-Variable.ttf` | The **interface** typeface: headings, labels, buttons, chips, and navigation on every platform. One variable file (`wght` 100–900) whose default instance is the thinnest weight, so the theme pins the axis. Latin script only. |
| `assets/fonts/NotoNaskhArabic-Regular.ttf` | Arabic-script **body** font for offline PDF export, and the **interface** face for the Arabic locale, which Outfit cannot render. Regular weight only. |
| `assets/fonts/Baloo2-Variable.ttf` | Rounded storybook **display** face for exported titles, dedications and badges in English, Swedish and Somali. |
| `assets/fonts/Amiri-Bold.ttf` | Arabic **display** face for the same headings. Two faces rather than one because the PDF renderer shapes Arabic into Presentation Forms-B code points, which the rounded Arabic candidates do not carry — see `assets/fonts/README.md`. |
| `assets/fonts/AtkinsonHyperlegible-Regular.ttf` | Latin-script easy-reading font used only by the optional per-child reader setting; regular weight only. |
| `assets/fonts/Newsreader-Variable.ttf` | Latin-script serif used for story prose in the reader and parent review preview when easy reading is off. Variable `opsz` 6–72 and `wght` 200–800 face whose default instance is 16pt regular at weight 400. |
| `assets/fonts/OFL.txt`, `OFL-Outfit.txt`, `OFL-AtkinsonHyperlegible.txt`, `OFL-Newsreader.txt`, `OFL-Baloo2.txt`, `OFL-Amiri.txt`, `README.md` | SIL Open Font License texts and provenance notes for the bundled fonts, including where each file came from, the measured glyph-coverage reasoning behind the display pair, and why the interface falls back to Naskh for Arabic. |
| `assets/brand/iam_hero_mark.svg` | The one drawn brand mark: an open book in candle amber with cream pages and a candle flame rising from the gutter, on the night backdrop of the redesign palette. No text, no photograph, no child data. Drawn so every painted point stays inside the circle Android and the web maskable spec are allowed to crop to, which is why one drawing serves as icon, adaptive foreground and splash logo. Deliberately **not** listed under `flutter: assets:` — nothing at runtime reads it. |
| `assets/brand/generated/app_icon.png`, `app_icon_foreground.png`, `app_icon_monochrome.png`, `splash.png`, `splash_android_12.png` | The PNG masters rasterized from that SVG, one per shape the platform generators need (opaque icon, adaptive foreground, themed silhouette, splash logo, Android 12 splash icon). Generated — never hand-edited — and committed so a fresh checkout builds every platform without running the renderer. |

## App icons and splash screens — `assets/brand/`, `web/`, `android/`, `ios/`

One drawing becomes every launcher icon and every launch screen, and every
launch surface shows the same night background, so no platform ever flashes
white before the first Flutter frame. Both generators are dev dependencies
configured entirely inside `pubspec.yaml`; neither is imported by any Dart
code, and no splash-removal call was needed in `lib/`.

Regenerate with, in this order:

```sh
flutter test tool/render_brand_assets.dart  # SVG      -> PNG masters
dart run flutter_launcher_icons             # masters  -> launcher icons
dart run flutter_native_splash:create       # masters  -> splash screens
git restore ios/Runner.xcodeproj/project.pbxproj ios/Runner/Info.plist
```

That last line is not optional. `flutter_launcher_icons` writes the AppIcon
set name over the unrelated boolean `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`,
and `flutter_native_splash` re-indents the whole `Info.plist` to add a
`UIStatusBarHidden` that is already the default. Neither change is needed by
the icons or the splash. `flutter_native_splash` also re-serializes
`web/index.html`; it finds its own blocks by element id, so the hand-written
parts survive, but the whitespace needs tidying again afterwards.

To change a colour: edit it in `assets/brand/iam_hero_mark.svg` and in the
`iam_hero_brand_palette` anchors in `pubspec.yaml` (both generator blocks alias
them), then run the commands above.

| Path | Responsibility |
| --- | --- |
| `tool/render_brand_assets.dart` | The renderer: reads the SVG, takes the night colour from its `id="backdrop"` rectangle, drops its `id="glow"` halo for the themed icon, and writes each master at the size and scale that platform crops to. Shaped as a test so it can borrow the Flutter test engine as a headless rasterizer, which keeps regeneration free of an image editor and of any machine-specific tool path. `flutter test` with no arguments only globs `test/`, so it never runs with the suite. |
| `web/index.html` | The night background and the mark are in the `<head>` style the browser applies before anything loads, so the page is never white. Two blocks are hand-written and survive regeneration: the `theme-color` meta and `<script id="brand-splash-handoff">`, which drops the splash on the engine's `flutter-first-frame` event. The generated `removeSplashFromWeb()` is called by nothing on purpose — its only caller is the package's runtime Dart API, which would turn a build-time tool into a runtime dependency, and it would clear the night background as it went. |
| `web/manifest.json` | PWA install metadata: `theme_color` and `background_color` are the night colour, and the icon list carries 192, 512 and both maskable sizes. Colours and icon list are written by the generator; name, description and orientation are not touched. |
| `web/favicon.png`, `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` | Generated from the opaque master. The maskable pair is the same drawing resized, which is safe because the mark is authored inside the maskable safe circle. |
| `web/splash/img/light-1x..4x.png`, `dark-1x..4x.png` | The loading mark for the page splash, 256 to 1024 px. Light and dark are the same night design by choice. |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Legacy launcher bitmaps, 48 to 192 px. The `ic_launcher` name, the manifest and the application id are unchanged. |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `values/colors.xml` | Android 8+ adaptive icon: the night `ic_launcher_background` colour as the background layer, the mark as the inset foreground and monochrome layers. |
| `android/app/src/main/res/drawable-*/ic_launcher_foreground.png`, `ic_launcher_monochrome.png` | Those two layers per density. The monochrome one is the halo-free silhouette, because Android 13+ keeps only its alpha and tints it. |
| `android/app/src/main/res/drawable*/launch_background.xml`, `drawable*/background.png`, `drawable-*/splash.png` | Pre-Android-12 splash: the night background filled, the mark centred, with `-night` and `-v21` variants of the same night design. |
| `android/app/src/main/res/drawable-*/android12splash.png`, `values-v31/styles.xml`, `values-night-v31/styles.xml` | Android 12+ splash, which the system draws from the window theme: `windowSplashScreenBackground` and `windowSplashScreenIconBackgroundColor` night, `windowSplashScreenAnimatedIcon` the mark drawn inside the 768 px circle the system crops to. |
| `android/app/src/main/res/values/styles.xml`, `values-night/styles.xml` | The pre-12 `LaunchTheme`, plus the fullscreen, cutout and force-dark items the splash generator adds. `NormalTheme` takes the same night `ic_launcher_background` colour as its window background instead of the platform default, so the hand-off from the splash to the first Flutter frame never shows a light window. |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | The full iOS AppIcon set from the opaque master, 20 pt to 1024 pt. |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/` | The launch mark at 1x, 2x and 3x (256 to 768 px), light and dark the same. |
| `ios/Runner/Assets.xcassets/LaunchBackground.imageset/` | A one-pixel night image the storyboard stretches over the whole launch view. |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` | The launch screen: night background image behind the centred mark. The view's own `backgroundColor` is hand-set to night as well, so the first pixels are never white; the generator only rewrites the subviews and constraints, so that edit survives. |

## Tests — `test/`

| File | What it proves |
| --- | --- |
| `test/app/iam_hero_app_test.dart` | End-to-end widget flows: onboarding, profile creation, choosing a birth date for a legacy age-only profile, story creation through review and approval into the reader, the shelf opening on the child the app is reading as with the other child's chip beside it, theme restoration, and localization. Two of them hold the creation form to its contract: tapping a hero, eight pages, and a language hands the generator exactly the request the dropdowns used to build, and a device saved on Local AI never sees the demo named in the header. |
| `test/app/home_page_test.dart` | That Home is wired to the real application: the header switcher changes the active child and persists it, the new story tile reaches the creation page, keep reading opens the newest unfinished book at its first page and disappears once that book is finished, the drafts row counts drafts and its tap stops at the parent PIN before continuing to the queue, "See all" opens the shelf with the active child's chip already selected rather than the first child's, and a family with no profiles is asked for one before anything else. What Home decides is asserted without a widget next door. |
| `test/features/home/home_view_test.dart` | Home's decisions as pure functions of one snapshot and one moment: the keep-reading book is the newest unfinished one and absent when every book is finished or no child is active, the shelf strip never repeats the featured book and caps at six with or without one, a draft and another child's book stay off it, "See all" names the active child and is absent without a strip, the greeting line goes continue-reading before drafts before the invitation while another child's drafts still count, and each part of the day keeps its own hours on the moment supplied. |
| `test/app/app_theme_test.dart` | The shared skin: every palette token holds its redesign value and reaches the cards, fields, chips, buttons, dialogs, and all three navigation surfaces; the active child's colour stays the accent on the filled button, the selected chip, and the indicators; every interface text slot asks for Outfit with its weight pinned on the axis; the Arabic locale asks for the Naskh face and never for Outfit; both faces are in the asset bundle; and the hero panel paints a flat tile with an accent ring instead of a gradient. |
| `test/core/generation/demo_story_generator_test.dart` | Demo stories respect language, page count, gender context, and saved child preferences; requests without a gender choice are rejected. |
| `test/core/models/child_profile_test.dart` | Legacy age-only profiles still decode, ages count the birthday itself (including leap-day children), and malformed, future, or too-recent birth dates are refused at the storage boundary. |
| `test/core/storage/local_repository_test.dart` | Real persistence round-trips, legacy-JSON migration, corrupt-data surfacing, `replaceState` preserving the parent PIN while clearing the queue, an end-to-end encrypted restore, rollback when a preference write fails midway, and refusal of a newer-schema backup. |
| `test/core/storage/library_transaction_test.dart` | The one order every family change follows, against a store that records or refuses writes: a refused write publishes nothing and leaves the snapshot untouched, a shelf handed back out of order is stored newest first, updating a story this device no longer has writes nothing, a story for a child who does not exist is refused before any write, and activating a child writes the identity without rewriting every profile. |
| `test/core/backup/encrypted_backup_codec_test.dart` | Backup round-trip fidelity including birth dates, wrong-password rejection, tamper (bit-flip) detection, unsupported-version rejection, and that plaintext never appears in the ciphertext. |
| `test/core/export/story_pdf_service_test.dart` | A valid PDF renders offline for each of the four story languages using the bundled fonts; a book is a cover, a dedication, one sheet per page and a back cover; the first drawn page becomes the cover picture; a page with no picture, undecodable bytes, or a demo story with no identities at all keeps its sheet; the optional cover photo joins the cover without adding a sheet and an unreadable one falls back; all twelve kingdom badges draw; each illustration style prints in its own palette; and the Arabic layout mirrors — badge corner, accent side and panel padding — as well as rendering. |
| `test/core/export/story_pdf_fonts_test.dart` | The bundled display faces really cover what the export prints: every title, dedication, badge and closing string per language is shaped exactly the way the PDF package shapes it and looked up in the real font files, so a font that would print blanks fails the suite instead of shipping. |
| `test/core/security/parent_security_service_test.dart` | The stored verifier accepts only the original PIN and never contains the PIN itself. |
| `test/core/security/parent_security_test.dart` | The attempt counter and escalating cooldown policy, that success clears both, and that version-1 records decode with no attempt history. |
| `test/features/settings/parent_access_controller_test.dart` | Five wrong PINs start a cooldown that escalates and survives a restart, the correct PIN unlocks once it elapses, Change PIN requires the current PIN, and backgrounding re-locks the session. |
| `test/features/story_creation/generation_queue_controller_test.dart` | A request interrupted mid-run reopens as a durable queued job after restart. |
| `test/features/story_creation/story_controller_test.dart` | Retrying, cancelling, favouriting, or generating for deleted content fails as a catchable `Exception` instead of crashing the screen. |
| `test/support/fake_bridge_http_client.dart` | The only boundary the local AI tests replace: a scripted `http.BaseClient` that records requests, plus builders for the bridge's JSON answers, typed error envelopes, and completed story payloads. |
| `test/support/seeded_device.dart` | One seeded device, shaped in one place: `child()`, `book()`, `pairedDevice()` and `localAiConnection()` build real model values, `seedDevice()` writes them through a real `LocalRepository` so the preference key names stay private to the repository and an impossible seed fails at seed time, and `pumpApp()` builds the real application over an in-memory pairing store and page-image cache. Only `local_repository_test.dart`, whose subject is the stored wire format, still writes raw JSON. |
| `test/core/ai_connection/bridge_client_test.dart` | Address validation, health decoding, UTF-8 request bodies with the bearer token, a refusal to call an authenticated endpoint while unpaired, every typed bridge error code mapped to its typed failure, unreachable told apart from timed out, an unusable answer refused, and the two-step pairing exchange. |
| `test/core/generation/local_ai_story_generator_test.dart` | A completed job becomes one complete book with page order, language, prose, and scene text intact plus the bridge story and illustration ids; Girl/Boy and all three page counts reach the request; queued, writing, and checking stages are reported; failed, unreachable, unauthenticated, timed-out, and never-finishing jobs raise typed failures; cancelling calls the PC and reports cancellation; a payload with the wrong page count or language is refused. |
| `test/features/settings/ai_connection_controller_test.dart` | A new device starts on the demo and the loopback address, the mode persists across a restart and switches the active generator, pairing stores the token without ever printing it, a wrong code leaves the device unpaired, forgetting removes only the token, an unusable address is refused, and the health probe reports all three dependencies. |
| `test/features/story_creation/local_ai_generation_test.dart` | Through the real queue and storage: a completed PC story is saved once as a draft, a failed job stays retryable with an empty library, an unreachable PC, a refused token, and a silent PC all leave the library untouched, and cancelling a running request stops the PC and clears the queue. |
| `test/shared/mosaic_grid_test.dart` | The shared mosaic at the two widths that matter: two columns on a 360 px phone with a second row starting where the first one filled, three columns at the desktop breakpoint with the two-column tile still covering exactly two of them, a span wider than the grid narrowed to it, no horizontal overflow at either width, and the grid scrolling inside a page scroll view. |
| `test/shared/story_card_test.dart` | The three tile shapes: every variant opens the story from the middle of its own face, the wide row carries the Demo badge, the favourite heart, the meta line and exactly one overflow control instead of an icon row, the small tile carries only cover and title, and a feature that allows no secondary command gets no overflow control at all. |
| `test/features/library/story_card_overflow_test.dart` | Through the real library UI: the overflow menu's delete stops at the parent PIN and only deletes after the right one, the overflow's favourite runs the same story command and is persisted, and the large tile carries the Demo badge, the favourite heart, and the page-count-and-date line. |
| `test/features/library/shelf_chips_test.dart` | That the shelf's chips and its search are wired, through the real library UI: the shelf opens on the first child and says the books are stored only on this device, a child chip swaps the shelf for that child's books and back, a collection chip narrows the mosaic while All restores it, and typing in the search field narrows both the mosaic and the All count before reporting no match. What each of those *decides* is asserted without a widget next door. |
| `test/features/library/shelf_view_test.dart` | The shelf's decisions as pure functions: the four-level precedence for whose shelf is on screen and the fall-through when a named child has been deleted, drafts and the other child's books staying off the shelf, a shelf that holds books but matches nothing told apart from an empty one, a case- and whitespace-insensitive title search that never reads a page of prose, collection labels listed once in case-insensitive order, a filter whose collection left the shelf falling back to All while Favorites never does, and collections literally named `collection:bedtime` and `all` filtering as the labels they are. |
| `test/shared/parent_access_gate_test.dart` | A configured PIN hides settings, a wrong PIN keeps them hidden, the right PIN opens them, and repeated wrong PINs refuse input with the remaining wait. |
| `test/core/narration/sentence_splitter_test.dart` | Pages split the way they are read aloud: English terminators, the Arabic `؟`, ellipses and terminator runs, line breaks, a single-sentence page, blank pages, and offsets that still point at the original characters. |
| `test/features/reader/narration_controller_test.dart` | Sentences are spoken in order, pause freezes the position while resume repeats that sentence, stop clears the queue, an unrequested page turn stops narration while rest-of-story follows the queue onto the next page, an injected sleep timer stops narration at expiry, and the selected speed reaches the boundary. |
| `test/features/reader/story_reader_narration_test.dart` | What the reader sees: starting narration tints the first sentence and advances it, pausing keeps the sentence and resuming re-speaks it, stopping clears the tint and hides the stop control, and the settings dialog offers the sleep timer. |
| `test/core/models/kingdom_theme_test.dart` | Kingdom decoration round-trips through JSON, an absent field decodes to its default, an unknown stored name is refused, a profile keeps its decoration through an encrypted backup, and snapshots are written at schema version 3 while version 4 is refused. |
| `test/features/kingdom/my_kingdom_page_test.dart` | Choosing a castle, frame, backdrop, or symbol saves it and re-renders My Kingdom, and a second hero keeps decoration choices independent of the first. |
| `test/core/models/child_reading_settings_test.dart` | Reading comfort round-trips, absent fields decode to the defaults, unknown values are refused, the easy font applies to Latin script only, the size steps grow, and a pre-comfort profile keeps the defaults with an empty reward history. |
| `test/core/backup/story_share_codec_test.dart` | A shared story round-trips with its review status and collections, the payload never contains a photo, a wrong password and a bit flip both fail, a backup and a story file each refuse the other's decoder, a newer payload is refused, and an imported story is re-attached to the chosen profile. |
| `test/features/library/story_share_test.dart` | Importing writes the story to the chosen profile only, the same story twice is refused, an export carries the local hero name and no photo, and through the real library UI a picked file is previewed, imported, and opened in the reader while a full backup is refused with a localized message. |
| `test/features/settings/library_sync_test.dart` | Through the real client, service, controllers, and preference storage: a first sync places every story on the right shelf with its provenance intact, a second sync transfers nothing, a changed PC copy is downloaded again while local favourites survive, a deletion record removes the local copy and its badge (including one this device had removed on purpose), remove-from-device keeps a story out of the next sync until the re-download control clears it, delete-everywhere calls the PC and fails offline without local changes, stories for an unknown child are reported instead of invented, a failure mid-download or in the report back leaves nothing changed, Arabic prose survives the whole path, and the automatic start-up sync runs once and only for a paired Local AI device. |
| `test/features/settings/library_sync_card_test.dart` | What the parent-gated card says: the automatic sync's report after a start, "already matches the PC" on a second run, and the never-synced state plus a typed failure on an unpaired device. |
| `test/features/library/story_delete_choice_test.dart` | Through the real library UI: a demo story keeps one plain local deletion, removing a bridge story's offline copy calls no bridge endpoint and surfaces the re-download control in settings, and deleting everywhere drops the copy only after the PC agrees — offline it keeps the story and shows the typed message. |
| `test/features/reader/story_reader_chrome_test.dart` | The rearranged reader chrome: a button turn and a swipe both move the page counter and the open page's dot, the top row and the icon row offer every control the design reference names, and the text-size icon opens the hero's saved prose size and changes it. |
| `test/features/reader/story_reader_comfort_test.dart` | The reader scales prose by the saved text size, uses the easy font for English but never for Arabic, mirrors both in the review preview, ships that font in the asset bundle, and bedtime mode warms the page, dims the prose, and picks the ten-minute sleep timer unless the parent already chose one. |
| `test/features/kingdom/reading_rewards_test.dart` | Badge thresholds, finishing a story counting once with the badge reported, no badge between thresholds, deletion dropping a story from the reward history, and the reader celebrating the first badge once while My Kingdom shows the count and the next milestone. |

## Local PC bridge — `bridge/`

A standalone Dart `shelf` service (its own package, not part of the Flutter
app) that runs on the parent's PC and will connect the app to local Ollama,
ComfyUI, and the master story library. Milestone 1 ships the skeleton:
health/status probes, the SQLite master library, and secure device pairing.
Full setup, endpoint, and security documentation lives in `bridge/README.md`.

| Path | Responsibility |
| --- | --- |
| `bridge/bin/iam_hero_bridge.dart` | Entry point: loads config (creating defaults on first run), initializes the library, binds the server, and hands shutdown to `AppServer.close()` on SIGINT (SIGTERM too where the platform supports watching it). |
| `bridge/lib/iam_hero_bridge.dart` | The package's public face, kept to what an entry point needs: the config loader and its result, `MasterLibrary`, `AppServer`, and the version. Tests and the rest of the package import `src/` files directly. |
| `bridge/lib/src/config/` | `bridge_config.dart` (typed, validated settings; **every top-level key is now strict** — one that is not in `BridgeConfig.knownKeys` is refused at startup by name, so a misspelled setting can no longer run silently on the default), `bridge_config_loader.dart` (`--config` arg → env var → working-directory file; machine-specific paths live only in the gitignored `bridge_config.json`), and `illustration_settings.dart` (the optional `illustration` section: checkpoint, size, sampler, LoRA chain, upscale and face-detail passes, every field defaulting to the compiled-in value so an untouched config renders what it always did, unknown keys refused, and the finished page size checked against the client's image download cap at load time). Both schemas describe themselves to the shared `JsonReader` — field names, bounds, and which exception to raise — and hold no field-reading code of their own. The configuration also **hands out endpoints rather than fields**: `config.ollama` builds the generate and unload requests, and `config.comfyUi` the `control` and `transfer` endpoints (with the control call's 30-second cap as the target's own policy), so the renderer, the story queue and the two health probes never assemble a URL, a model tag and a duration into an outbound call themselves. |
| `bridge/lib/src/library/` | `master_library.dart` (folder skeleton, SQLite in WAL mode, versioned schema migration), `device_store.dart` (paired devices; only SHA-256 token hashes stored, constant-time lookup), `db_transactions.dart` (BEGIN IMMEDIATE/COMMIT/ROLLBACK helper). |
| `bridge/lib/src/pairing/` | In-memory pairing ceremony: rate-limited 6-digit codes shown only on the PC console, hashed at rest, expiring after 2 minutes, invalidated after 5 wrong attempts. |
| `bridge/lib/src/probes/` | Health probes for Ollama (version + configured model present), ComfyUI, and the library, behind an injectable HTTP client with bounded timeouts. The two network probes take `config.ollama` / `config.comfyUi` and use only the base URL from them — a probe answers `/health` and must never inherit a fifteen-minute generation budget. |
| `bridge/lib/src/sync/` | Device synchronization: the metadata-only manifest (profiles, stories with timestamps, illustration statuses, deletion records, the device's last sync), full story downloads, and the per-device sync-state store. Schema v2 added persisted scene descriptions with a stepped, tested v1→v2 migration. |
| `bridge/lib/src/backup/` | Encrypted master-library backup and restore: a bespoke binary `.ihmb` format (AES-256-GCM, PBKDF2 200k, header authenticated as AAD) deliberately incompatible with the app's Argon2id backup files. Backups carry no device token hashes, so devices re-pair after a restore. |
| `bridge/lib/src/generation/` | Real story generation: validated request model (now carrying the child's optional saved `favoriteTopics` and `recurringWorld`), the story queue — a `JobQueue` that adds only the whole-job turn at the shared GPU gate and the retry policy (the gate performs the model unload on the way out; the queue only supplies the Ollama tenant) — the Ollama client (UTF-8, enforced JSON schema, bounded timeout, abort on cancel), the **two-pass** prompt/schema builder — `story_outline.dart` plans a title, one beat per page and a one-line hero appearance sheet, then `story_prompt.dart` writes the pages from that approved plan with story-arc, age-band and per-language rules — `language_purity.dart` (pure script-level check refusing Arabic answered in Latin letters and the reverse), full structural validation of model output with retry on invalid output only, `withHeroAppearance` propagating the appearance sheet into every scene description, and the one-transaction library writer (profile upsert + story + pages + pending illustration rows). Both passes share one attempt budget and an approved outline is reused across retries, so a retry reproduces the story instead of drifting. Prompts and story text are never logged. |
| `bridge/lib/src/illustration/` | Page rendering against the local ComfyUI: the `ComfyUiClient` boundary (submit, poll, download with a 16 MB ceiling, ask whether a custom node class exists), the node-graph builders for a page and for the two-stage reference portrait, the page queue — the same `JobQueue`, differing only in what it does per job: one turn at the shared GPU gate per page instead of per job (the gate, not the queue, decides what has to be freed between turns), and a failed page that marks its own row and lets the book carry on — and the typed failure codes. The graphs follow `BridgeConfig.illustration`, so the LoRA chain, the upscale pass and the Impact-Pack face-detail pass are configuration rather than code — except the child-safety negative prompt, which is deliberately a constant. |
| `bridge/lib/src/server/` | Shelf wiring: router, bearer-token auth middleware (including `requireOwnJob`, the one ownership check behind both job APIs — another device's job and an id that never existed answer identically, so job ids cannot be probed), CORS consent (loopback origins always, via the shared `isLoopbackHost`; LAN origins only via `allowedWebOrigins`), typed JSON errors, bounded request bodies, and the health/pairing/devices/generation handlers. `AppServer` owns its lifecycle — `start()` binds, `close()` abandons unfinished jobs, closes the socket and the library — and keeps both queues private; `awaitStoryJob` and `awaitIllustrationJob` are the only doors tests get into them. |
| `bridge/lib/src/common/` | Secrets (secure token generation, SHA-256 helpers, constant-time comparison), atomic file writes, path joining, `gpu_gate.dart` — the FIFO gate over the machine's single card, which owns more than mutual exclusion: each queue hands it a `GpuTenant`, and the gate evicts the departing one (Ollama unloads its model; ComfyUI's eviction is a documented no-op until the bridge learns to free the checkpoint) before the card changes hands or goes idle, skipping the eviction when the same tenant runs again, and logging rather than blocking when an eviction fails or overruns — `job_queue.dart` — the generic `JobQueue<TJob, TPlan>` both the story and the illustration queue *are*: FIFO admission, queue positions, cancellation (queued, running, already-terminal, idempotent), `whenSettled`, the settle and 100-job retention bookkeeping, content-free log lines and the single-worker pump; a concrete queue adds only how to run one job and what a cancelled snapshot looks like — and the three pieces every boundary shares: `json_reader.dart` (one validating field reader — bounds, types, absence, dotted paths, unknown-key rejection — with a per-schema `JsonFieldFailures` deciding the vocabulary and the exception type, so a config file still fails as a `FormatException` and an HTTP body still as a typed `400`), `base_url.dart` (the one place a base URL is parsed, normalized and has a path resolved against it), and `local_network.dart` (`isLoopbackHost` and `isPrivateOrLoopbackHost` over one parsed address, so CORS's narrow question and the configuration's wide one cannot disagree). |
| `bridge/test/` | Behavior tests through the real HTTP handler with mocked probe boundaries and temp-directory libraries: health shapes, idempotent initialization, the full pairing flow, auth rejection cases, and oversized-body rejection. `gpu_gate_test.dart` states the card's residency rule in-process — eviction between different tenants and on idle, none between two turns of the same tenant, a hung or failing eviction still handing over. `job_queue_test.dart` drives the shared queue in-process with a fake run held open by a `Completer`: positions with and without a running job, cancel while queued, while running and after the fact, `whenSettled` for a job that already settled, the retention cap, a shutdown that abandons the line, and a pump that never re-enters. `json_reader_test.dart` proves the shared field reader once — absence, bounds, types, length limits that never quote the value, unknown keys, dotted paths, and each schema's own exception type — `local_network_test.dart` pins both host predicates (loopback in every spelling, the private and Tailscale ranges, the addresses just outside each one, hostnames), `bridge_config_test.dart` covers the strict top level, base-URL normalization, and the endpoints the configuration hands out — including the control-timeout cap that used to hide untested in a private renderer getter — `illustration_config_test.dart` covers the rendering section — defaults, every range, unknown-key rejection, and a page size the download cap could not carry — and `illustration_workflow_test.dart` asserts exact node wiring for the LoRA chain, the upscale pass and the face detailer, on and off. `story_quality_test.dart` is the pure-function suite for the two-pass pipeline: outline validation, the language-purity checker per language, hero-sheet propagation inside the scene length cap, and what each prompt actually demands. `story_generation_test.dart` additionally proves the pass split over HTTP — a bad plan is re-planned and never reaches pass two, a bad page answer is retried against the same plan, the appearance sheet lands in every stored scene, and saved preferences reach both prompts. |

## Documentation — `docs/`

| File | Responsibility |
| --- | --- |
| `docs/CODEBASE.md` | This file. |
| `docs/LOCAL_AI_INTEGRATION.md` | The contract the local Ollama and ComfyUI integration is held to: the `StoryGenerator` boundary, failure semantics, and privacy and network constraints. |
| `docs/ILLUSTRATION_QUALITY_UPGRADE.md` | Work order for the AI PC, completed September 2026: which free model files to download and which `illustration` settings to change so the pictures improve. Kept as the record of what runs there. |
| `docs/STORY_QUALITY_UPGRADE.md` | The same for the words, also completed: why `gemma3:4b` is the floor rather than a recommendation, a free-model table by system RAM (Qwen chosen for Arabic), the one `ollamaModel` line to change, why `think: false` is required, and a verification section that ends with reading the Arabic aloud with a native speaker. |
| `docs/REMOTE_FAMILY_ACCESS.md` | Work order for publishing the bridge to the internet with Tailscale Funnel so a family member abroad can pair from the hosted web app, completed on the AI PC in September 2026: install, funnel, allowed origin, pairing walkthrough, verification, keep-awake, rollback, and the security limits the owner accepted. |
| `docs/design/iam-hero-redesign.html` | Static HTML design reference for the phone redesign (Home, Library, Create, Reader): palette tokens, Outfit interface type, serif story prose, mosaic tiles, tap-once chips. Open it in a browser; it is not part of the Flutter build. |
| `docs/research/ollama-arabic-models.md` | Research note for issue #8 (2026-09-03): Arabic- and Somali-capable free Ollama models per RAM band with the measurements behind each pick (`qwen3.5:9b` at 16 GB, `gemma3:27b` at 32 GB), why `-cloud` tags must never be used, and the evidence the story work order's model table was corrected from. |
| `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, `docs/agents/domain.md` | How an agent session works this repo's GitHub issues, the five triage labels, and where domain glossary and decision records would live. Referenced from `CLAUDE.md`. |

## Feature → file quick reference

| Feature | Main files |
| --- | --- |
| Child profiles, birth dates, and photos | `core/models/child_profile.dart`, `features/profile/*` |
| Per-child themes | `app/app_theme.dart`, `features/kingdom/my_kingdom_page.dart`, `features/profile/profile_controller.dart` |
| Mosaic layout and story tiles | `shared/screen_layout.dart`, `shared/story_card.dart`, `features/home/*`, `docs/design/iam-hero-redesign.html` |
| Palette tokens and interface typeface | `app/app_theme.dart`, `assets/fonts/Outfit-Variable.ttf`, `assets/fonts/README.md`, `docs/design/iam-hero-redesign.html` |
| Story creation (demo and local AI) | `features/story_creation/*`, `core/generation/*` |
| PC bridge client and pairing | `core/ai_connection/*`, `features/settings/ai_connection_controller.dart`, `ai_connection_card.dart`, `shared/local_ai_messages.dart` |
| Durable generation queue | `core/models/generation_job.dart`, `features/story_creation/generation_queue_controller.dart`, `generation_center_page.dart` |
| Parent review of drafts | `core/models/story_models.dart` (`StoryReviewStatus`), `features/review/story_review_page.dart` |
| Library, favorites, collections | `features/library/*`, `shared/story_card.dart` |
| Reader and narration | `features/reader/story_reader_page.dart`, `features/reader/narration_controller.dart`, `core/narration/*` |
| My Kingdom personalization | `core/models/kingdom_theme.dart`, `features/kingdom/kingdom_style_card.dart`, `kingdom_decorations.dart`, `features/profile/profile_controller.dart` |
| PDF export (storybook layout, fonts, RTL) | `core/export/story_pdf_service.dart`, `story_pdf_layout.dart`, `story_pdf_symbols.dart`, `pdf_file_service.dart`, `features/reader/story_export_controller.dart`, `assets/fonts/` |
| Story quality (two passes, arc, Arabic) | `bridge/lib/src/generation/story_outline.dart`, `story_prompt.dart`, `language_purity.dart`, `story_generation_queue.dart`, `docs/STORY_QUALITY_UPGRADE.md` |
| Parent PIN | `core/security/*`, `features/settings/parent_access_controller.dart`, `parent_security_settings_card.dart`, `shared/parent_access_gate.dart` |
| Encrypted backup and restore | `core/backup/*`, `features/settings/backup_controller.dart`, `backup_settings_card.dart`, `shared/encryption_password_dialog.dart` |
| Single-story sharing | `core/models/shared_story.dart`, `core/backup/story_share_codec.dart`, `story_share_file_service.dart`, `features/library/story_share_controller.dart`, `story_share_actions.dart` |
| Reading comfort | `core/models/child_reading_settings.dart`, `shared/reading_text_style.dart`, `features/kingdom/story_preferences_card.dart`, `features/reader/story_reader_page.dart`, `features/review/story_review_page.dart`, `assets/fonts/` |
| Reading rewards | `core/models/reading_badge.dart`, `shared/reading_badge_view.dart`, `features/kingdom/reading_rewards_card.dart`, `features/profile/profile_controller.dart`, `features/reader/story_reader_page.dart` |
| Bedtime mode | `features/reader/story_reader_page.dart`, `app/app_theme.dart`, `core/narration/narration_options.dart` |
| Schema versioning and migrations | `core/models/app_state.dart`, `core/storage/local_repository.dart` |
| One library transaction (persist, then publish) | `core/storage/library_transaction.dart`, `core/storage/library_store.dart`, `core/models/app_state.dart`, `app/app_controller.dart` |
| Per-child story preferences and safety topics | `core/models/child_story_preferences.dart`, `features/kingdom/story_preferences_card.dart` |
| Localization (en/ar/sv/so) | `lib/l10n/*` |
| Local AI text generation | `docs/LOCAL_AI_INTEGRATION.md`, `core/generation/story_generator.dart`, `core/generation/local_ai_story_generator.dart`, `core/ai_connection/*`, `bridge/` |
| Offline library synchronization | `core/ai_connection/bridge_sync_models.dart`, `library_sync.dart`, `library_sync_state.dart`, `features/settings/library_sync_controller.dart`, `library_sync_section.dart`, `bridge/lib/src/sync/` |
| The two kinds of story deletion | `features/library/story_delete_actions.dart`, `features/settings/library_sync_controller.dart`, `core/ai_connection/library_sync_state.dart` |
