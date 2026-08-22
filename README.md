# Iam - hero

Iam - hero is a private Flutter storybook for one parent and multiple children.
It runs without accounts, payments, analytics, advertising, or a required cloud
service.

Stories are written by a local Ollama model and page illustrations are drawn
by a local ComfyUI, both running on the family's own PC and reached over the
home network through the bridge in [`bridge/`](bridge/README.md). Devices pair
with a one-time console code, synchronize the shared library, and keep read
stories and pictures offline. An offline demo generator remains available and
its books are clearly labeled as demo content. The integration is documented
in [Local AI integration](docs/LOCAL_AI_INTEGRATION.md); a file-by-file map of
the source tree lives in [Codebase map](docs/CODEBASE.md).

## Current features

- Android, iOS, and web Flutter targets
- Application identifier `com.youssefhikal.mikohero`
- English, Arabic, Swedish, and Somali application interfaces
- Story text in the same four languages
- Right-to-left interface and story layouts for Arabic
- Multiple private child profiles with reference photos capped at 2 MB each
- Birth date per child, so the age used in the app is never a stale number
- Required Girl/Boy choice stored with each profile
- Rose theme for a new girl profile and cyan theme for a new boy profile
- My Kingdom profile switching with a separately saved color for each child
- Golden, rose, purple, cyan, and green palettes plus a local custom color picker
- Per-child kingdom personalization: castle style, photo frame, backdrop, and a
  favourite symbol, all drawn on the device with no extra image files
- Persistent mobile drawer, bottom navigation, and desktop rail on detail screens
- Optional local parent PIN for profiles, My Kingdom, settings, and deletion
- PIN attempt throttling, automatic re-lock on backgrounding, and Change PIN
- Password-protected `.iamhero` backup and restore across supported devices
- Required hero-profile selection before every story is created
- Personalized labels such as `Miko hero` and `Abbas hero`
- Story theme, moral, length, language, and illustration-style selection
- Explicit offline demo generation for 6-, 8-, or 10-page stories
- Per-child story preferences: favorite topics, a recurring story world, a
  default story language, and parent-selected safety-topic exclusions
- Parent review queue: every generated story is a hidden draft until the
  parent reads and approves it or deletes it
- Durable generation queue that survives restarts with retry and cancel
  controls in a parent-only generation center
- Per-profile story-library tabs when more than one child profile exists
- Story favorites and named collections such as bedtime or adventures, with
  library filtering
- Device-local story library and permanent deletion behind the parent gate
- Responsive phone, tablet, and desktop reader
- Per-child reading comfort: four reader text sizes and an optional bundled
  easy-reading font for English, Swedish, and Somali prose, both applied in the
  reader and the parent review preview
- Bedtime mode in the reader: a moon toggle that dims and warms the page for one
  reading session and starts narration with the 10 minute sleep timer
- Local reading badges at 1, 5, 10, and 25 finished stories per child, with
  progress toward the next badge on My Kingdom and no streaks or daily goals
- Single-story sharing: export one story as an encrypted `.iamhero-story` file
  and import it into a chosen profile on another device
- Free narration through voices installed on the current device, spoken one
  sentence at a time with the sentence being read highlighted on the page
- Narration play, pause, resume, and stop, with selectable speed, a
  current-page or rest-of-story scope that turns pages by itself, and an
  optional 5, 10, or 20 minute sleep timer
- Offline PDF export of any approved story with embedded fonts, including
  right-to-left Arabic script, with a per-export choice of whether the cover
  carries the child's photo
- Full removal of all profiles, reference photos, and story libraries

## Privacy and storage

`LocalRepository` stores the interface locale, profiles, each profile's
Girl/Boy choice, theme color, kingdom decoration, reading comfort and finished-story
badges, the active profile, base64-encoded reference photos, and story JSON through
`shared_preferences`; downloaded page illustrations live in files (or IndexedDB
on the web). The app's only network client talks to the family's own PC bridge
on the home network: the child's reference photo travels only there, and no
profile or story content is ever sent to an external service.

Local app storage is not an encrypted vault. It relies on the operating system
and device account for access control. The optional parent PIN is an app-level
barrier: only a salted Argon2id verifier is stored, but it does not replace a
device passcode or full-device encryption. Wrong PINs are throttled after five
consecutive attempts, and an unlocked parent session re-locks as soon as the app
leaves the foreground.

There is deliberately no PIN recovery, because the app has no accounts and no
server. If the PIN is forgotten, the only option is deleting all app data; an
encrypted backup then restores the family content, because a backup never
contains the PIN.

The parent can export a portable `.iamhero` file. Backup content is encrypted
and authenticated with AES-256-GCM using a key derived from the parent-entered
backup password with Argon2id. The password is never stored and cannot be
recovered. A backup includes profiles, photos, stories, the active hero, and the
interface language; it deliberately does not replace the parent PIN configured
on the destination device.

A single story can also be exported on its own as a `.iamhero-story` file. It
uses the same Argon2id and AES-256-GCM protection as a backup, with its own
password, but a distinct container format and authenticated header, so a story
file and a full backup can never be opened as each other. The file contains only
the story itself and the hero's display name for the import preview: never the
child's reference photo, birth date, or the parent PIN. Importing asks which
existing profile receives the story, keeps the story's review status, and refuses
a story the device already has instead of creating a duplicate.

An exported PDF storybook is a plain, unencrypted file saved wherever the
parent chooses. It contains the story title, the hero's first name, and the
story text. Each export asks whether the cover should also carry the child's
reference photo; the checkbox starts selected and the photo never appears on
inner pages. Either way the file leaves the app's control once saved, so treat
it like any other family document — and leave the photo out when the PDF will be
shared outside the family.

Browser storage belongs to the specific browser profile and origin. Clearing
site data clears local Iam - hero content, so download an encrypted backup first
when the content must move to another browser or device.

Never add a real child photo to Git. Photos are selected at runtime and the
repository contains no family data.

## Demo behavior

`DemoStoryGenerator` creates deterministic, gender-aware, language-specific
sample prose and gender-colored gradient placeholders. Every placeholder cover
and page displays a demo label. It does not call an LLM or image model and must
not be presented as AI output.

`StoryGenerator` is the application boundary both generators implement: the
demo generator and the local AI generator that talks to the PC bridge. Screens
depend on that boundary rather than on Ollama or ComfyUI APIs directly.

## Project structure

```text
lib/
  app/                 routing, shell, theme, service providers, state loading
  core/
    backup/            encrypted portable backup codec and platform file flow
    export/            offline PDF rendering and the platform save flow
    generation/        StoryGenerator boundary and demo implementation
    models/            validated profile, preference, story, and queue models
    narration/         speech boundary, options, implementation, splitter
    security/          parent-PIN verifier model and Argon2id service
    storage/           local SharedPreferences repository
  features/
    home/              personalized dashboard
    kingdom/           hero switching, colors, decoration, story preferences
    library/           per-child shelves, favorites, collections
    profile/           child profile management
    reader/            story reader, narration queue and controls, PDF export
    review/            parent-only draft review and approval
    settings/          language, backup, parent PIN, data deletion
    story_creation/    request form, generation queue, generation center
  l10n/                ARB translations and generated localization classes
  shared/              parent access gate, layout, and reusable story widgets
assets/
  fonts/               Noto fonts for offline PDF export and the optional
                       easy-reading story font, all under the OFL
test/                  mirrors lib/ with behavior-focused suites
```

Every file's purpose is described in [docs/CODEBASE.md](docs/CODEBASE.md).

## Development

The Dart SDK constraint is defined in [pubspec.yaml](pubspec.yaml). Install a
compatible stable Flutter SDK, then run:

```powershell
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Run the web target:

```powershell
flutter run -d chrome
```

Run Android using a connected device or emulator:

```powershell
flutter run -d android
```

An iOS build requires macOS with Xcode. The iOS project and bundle identifier
are generated in this repository, but Windows cannot compile or sign that
target.

The checked-in Android release configuration currently uses Flutter's debug
signing key for private family installation. Create and protect a private
release keystore before any store distribution.

## Quality requirements

- `flutter analyze` must complete without issues.
- `flutter test` must pass before a push.
- Authored named functions and public APIs carry Dart documentation explaining
  behavior, constraints, side effects, or recovery semantics.
- Tests assert user-visible behavior and real local persistence rather than
  private helper calls.
- New services must remain free and local; no paid API or required cloud service
  may be introduced.
- Generated localization files are produced from the four ARB source files.

## Known limitations

- Demo stories keep gradient placeholder art; only stories from the PC library
  get real ComfyUI illustrations, and each page takes minutes to render on a
  home GPU.
- Face likeness from the reference photo is "recognizably similar", not
  photographic — a 4 GB GPU runs SD 1.5 with a face adapter, nothing larger.
- Somali story generation is noticeably weaker than the other three languages
  with the current local model; the parent review step matters most there.
- PIN hashing and backup encryption run on a background isolate on Android, iOS,
  and desktop. Flutter web has no isolates, so `compute` runs inline there and
  the interface still pauses briefly during those actions.
- Somali narration depends on whether the device has a compatible voice.
- Narration speaks one sentence per utterance so sentence progress, pausing,
  and the sleep timer behave identically on Android, iOS, and the web. Some
  speech engines insert a short gap between sentences, and resuming after a
  pause repeats the paused sentence from its beginning rather than relying on
  platform pause support.
- Library sync requires the PC bridge to be running and reachable on the home
  network; profiles themselves move between devices via the encrypted backup
  or a single encrypted story file, each with its own password.
- The easy-reading font covers Latin script only. Arabic story prose keeps the
  interface font, and PDF export always uses the bundled Noto fonts regardless of
  the setting.
- Bedtime mode is a reader-session state on purpose: it is not saved per child
  and is off again the next time a story is opened.
- The Flutter TTS web plugin currently prevents a WebAssembly build; the
  standard JavaScript web release compiles successfully.

## Deployment

Every push to `main` runs the GitHub Actions workflow in
[`.github/workflows/web-deploy.yml`](.github/workflows/web-deploy.yml):

1. **Build and test** — `flutter analyze`, the full app test suite, the bridge
   package's analyzer and tests, and a `flutter build web --release`. The
   built site is kept as a workflow artifact for 7 days.
2. **Deploy** — the same build is published to Vercel production. This step
   runs only when the repository has the three Vercel secrets configured
   under *Settings → Secrets and variables → Actions*: `VERCEL_TOKEN`,
   `VERCEL_ORG_ID`, and `VERCEL_PROJECT_ID`. Without them the deploy is
   skipped and the workflow still verifies the push.

So publishing an update is exactly one command:

```
git push origin main
```

Privacy note: the deployed site is static files only. Profiles, photos,
stories, and pictures live in each browser's local storage and IndexedDB;
nothing is uploaded to the hosting service. The PC bridge stays on the private
home network — a hosted page can reach it only on the PC itself (`localhost`
is exempt from mixed-content rules); phones on the LAN use the app served from
the bridge's own network instead.
