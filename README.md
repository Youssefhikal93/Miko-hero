# Iam - hero

Iam - hero is a private Flutter storybook for one parent and multiple children.
It runs without accounts, payments, analytics, advertising, or a required cloud
service.

The current application provides the complete local user flow while clearly
labeling generated books as demo content. Ollama and ComfyUI are intentionally
not connected yet; their integration boundary is documented in
[Local AI integration](docs/LOCAL_AI_INTEGRATION.md). A file-by-file map of the
source tree lives in [Codebase map](docs/CODEBASE.md).

## Current features

- Android, iOS, and web Flutter targets
- Application identifier `com.youssefhikal.mikohero`
- English, Arabic, Swedish, and Somali application interfaces
- Story text in the same four languages
- Right-to-left interface and story layouts for Arabic
- Multiple private child profiles with reference photos capped at 2 MB each
- Required Girl/Boy choice stored with each profile
- Rose theme for a new girl profile and cyan theme for a new boy profile
- My Kingdom profile switching with a separately saved color for each child
- Golden, rose, purple, cyan, and green palettes plus a local custom color picker
- Persistent mobile drawer, bottom navigation, and desktop rail on detail screens
- Optional local parent PIN for profiles, My Kingdom, settings, and deletion
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
- Free narration through voices installed on the current device, with
  selectable speed and a current-page or rest-of-story scope
- Offline PDF export of any approved story with embedded fonts, including
  right-to-left Arabic script; the child's photo is never placed in the PDF
- Full removal of all profiles, reference photos, and story libraries

## Privacy and storage

`LocalRepository` stores the interface locale, profiles, each profile's
Girl/Boy choice and theme color, the active profile, base64-encoded reference
photos, and story JSON through `shared_preferences`. The app contains no network
client and sends no profile or story content to an external service.

Local app storage is not an encrypted vault. It relies on the operating system
and device account for access control. The optional parent PIN is an app-level
barrier: only a salted Argon2id verifier is stored, but it does not replace a
device passcode or full-device encryption.

The parent can export a portable `.iamhero` file. Backup content is encrypted
and authenticated with AES-256-GCM using a key derived from the parent-entered
backup password with Argon2id. The password is never stored and cannot be
recovered. A backup includes profiles, photos, stories, the active hero, and the
interface language; it deliberately does not replace the parent PIN configured
on the destination device.

An exported PDF storybook is a plain, unencrypted file saved wherever the
parent chooses. It contains the story title, the hero's first name, and the
story text — never the reference photo — and leaves the app's control once
saved, so treat it like any other family document.

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

`StoryGenerator` is the application boundary that a later local adapter will
implement. Screens depend on that boundary rather than Ollama or ComfyUI APIs.

## Project structure

```text
lib/
  app/                 routing, shell, theme, service providers, state loading
  core/
    backup/            encrypted portable backup codec and platform file flow
    export/            offline PDF rendering and the platform save flow
    generation/        StoryGenerator boundary and demo implementation
    models/            validated profile, preference, story, and queue models
    narration/         device text-to-speech boundary, options, implementation
    security/          parent-PIN verifier model and Argon2id service
    storage/           local SharedPreferences repository
  features/
    home/              personalized dashboard
    kingdom/           hero switching, per-child colors, story preferences
    library/           per-child shelves, favorites, collections
    profile/           child profile management
    reader/            story reader, narration controls, PDF export
    review/            parent-only draft review and approval
    settings/          language, backup, parent PIN, data deletion
    story_creation/    request form, generation queue, generation center
  l10n/                ARB translations and generated localization classes
  shared/              parent access gate, layout, and reusable story widgets
assets/
  fonts/               Noto fonts bundled only for offline PDF export (OFL)
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

- Cover and page illustrations are demo placeholders until local ComfyUI work.
- Stories use sample templates until the local Ollama adapter is implemented.
- Safety-topic exclusions are stored and displayed but are only enforced once
  local AI generation is connected; the demo generator is inherently safe.
- The parent PIN has no attempt throttling yet and unlocks for the whole app
  session until it is manually re-locked in settings.
- PIN hashing and backup encryption currently run on the UI thread, so those
  actions briefly pause the interface, most noticeably on web.
- Somali narration depends on whether the device has a compatible voice.
- Stories and profiles do not sync automatically; moving them requires a manual
  encrypted backup and its separate password.
- The Flutter TTS web plugin currently prevents a WebAssembly build; the
  standard JavaScript web release compiles successfully.
