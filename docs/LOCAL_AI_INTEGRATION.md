# Local AI integration boundary

This document defines the constraints for the later Ollama and ComfyUI phase.
No local model process, HTTP client, pairing protocol, or image-file persistence
is implemented in the current source.

## Existing application boundary

`StoryGenerator.generate(StoryRequest)` is the only generation operation used
by `AppController`. It returns a complete `StoryBook`. The active provider in
`app_controller.dart` supplies `DemoStoryGenerator`, which creates labeled
sample content without network access.

Relevant source files:

- `lib/core/generation/story_generator.dart`
- `lib/core/generation/demo_story_generator.dart`
- `lib/core/models/story_models.dart`
- `lib/app/app_controller.dart`

`StoryRequest` contains the hero name, theme, moral, language, story length,
and illustration style. Each generated `StoryPage` contains reader prose and a
`sceneDescription` reserved for the later image workflow.

## Required local implementation

The later adapter must implement `StoryGenerator` and preserve its failure
contract: successful calls return a complete book; failed generation must throw
an error that the creation screen can report. It must not return a partial or
hardcoded success value.

The local workflow should perform these operations:

1. Send the validated story request to an Ollama model on the parent's PC.
2. Validate structured model output before constructing `StoryPage` objects.
3. Create one ComfyUI prompt per page using the private reference photo.
4. Write generated image files into application-controlled local storage.
5. Return a complete `StoryBook` only after required pages are available.
6. Preserve the selected language and page order exactly.

The story model will need an explicit local illustration reference before the
reader can replace its current gradient placeholder. Add that field only when
the file-storage implementation exists in the same change.

## Security constraints

- Bind the PC service to localhost or the private home network by default.
- Add device pairing before allowing requests from phones or tablets.
- Never embed an unrestricted service token in the Flutter bundle.
- Validate photo type, decoded size, request size, and model output at the
  process boundary.
- Never log photo bytes or generated family content.
- Never send the photo, prompt, or output to a third-party model service.
- Provide bounded timeouts and cancellation for text and image jobs.
- Keep the existing permanent local deletion behavior.

## Test contract for the later phase

Tests should replace only the PC process boundary. They should verify:

- valid structured output becomes the expected story state;
- malformed output fails without persisting a partial story;
- unavailable Ollama or ComfyUI leaves the existing library unchanged;
- requested language and page order survive the complete adapter flow;
- cancellation stops the active job and does not report success.

Tests must not assert exact prompt wording, model prose, internal call counts,
or implementation-private helper calls.

## Implementation order

1. Add local image-file storage for Android, iOS, and web-compatible metadata.
2. Implement a private PC bridge with health reporting and device pairing.
3. Implement and validate Ollama structured story output.
4. Implement ComfyUI reference-photo and page-illustration jobs.
5. Replace the demo provider only after adapter tests pass.
6. Keep `DemoStoryGenerator` available to automated tests, not as an invisible
   fallback for failed local AI calls.
