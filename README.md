# Iam - hero

Iam - hero is a private Flutter storybook for one parent and multiple children.
It runs without accounts, payments, analytics, advertising, or a required cloud
service.

The current application provides the complete local user flow while clearly
labeling generated books as demo content. Ollama and ComfyUI are intentionally
not connected yet; their integration boundary is documented in
[Local AI integration](docs/LOCAL_AI_INTEGRATION.md).

## Current features

- Android, iOS, and web Flutter targets
- Application identifier `com.youssefhikal.mikohero`
- English, Arabic, Swedish, and Somali application interfaces
- Story text in the same four languages
- Right-to-left interface and story layouts for Arabic
- Multiple private child profiles with reference photos capped at 2 MB each
- Required hero-profile selection before every story is created
- Personalized labels such as `Miko hero` and `Abbas hero`
- Story theme, moral, length, language, and illustration-style selection
- Explicit offline demo generation for 6-, 8-, or 10-page stories
- Per-profile story-library tabs when more than one child profile exists
- Device-local story library and permanent deletion
- Responsive phone, tablet, and desktop reader
- Free narration through voices installed on the current device
- Full removal of all profiles, reference photos, and story libraries

## Privacy and storage

`LocalRepository` stores the interface locale, profiles, base64-encoded
reference photos, and story JSON through `shared_preferences`. The app contains
no network client and sends no profile or story content to an external service.

This storage is local but not an encrypted vault. It relies on the operating
system and device account for access control. Browser storage belongs to the
specific browser profile and origin; clearing site data also clears Iam - hero
content. Export and encrypted backup are not implemented in this version.

Never add a real child photo to Git. Photos are selected at runtime and the
repository contains no family data.

## Demo behavior

`DemoStoryGenerator` creates deterministic language-specific sample prose and
gradient placeholders. Every placeholder cover and page displays a demo label.
It does not call an LLM or image model and must not be presented as AI output.

`StoryGenerator` is the application boundary that a later local adapter will
implement. Screens depend on that boundary rather than Ollama or ComfyUI APIs.

## Project structure

```text
lib/
  app/                 routing, theme, providers, and persisted state commands
  core/
    generation/        StoryGenerator boundary and demo implementation
    models/            validated child-profile and story value objects
    narration/         device text-to-speech boundary and implementation
    storage/           local SharedPreferences repository
  features/            home, profile, creation, library, reader, and settings
  l10n/                ARB translations and generated localization classes
  shared/              responsive layout and reusable story widgets
test/
  app/                 localized widget and vertical-flow tests
  core/                generator and real persistence-seam tests
```

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
- Somali narration depends on whether the device has a compatible voice.
- Stories and profile data do not sync between devices.
- Export, restore, and encrypted backup are not implemented.
- The Flutter TTS web plugin currently prevents a WebAssembly build; the
  standard JavaScript web release compiles successfully.
