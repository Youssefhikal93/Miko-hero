# Local AI integration boundary

This document defines the constraints for the Ollama and ComfyUI phases.

Text generation is connected: `LocalAiStoryGenerator` talks to the PC bridge
through `core/ai_connection`, device pairing exists, and the parent selects the
generator in the settings AI connection card. ComfyUI illustrations and local
image-file persistence are still unimplemented, so the reader keeps its
gradient placeholder.

## Existing application boundary

`StoryGenerator.generate(StoryRequest)` is the only generation operation used
by `AppController`. It returns a complete `StoryBook`. The `storyGeneratorProvider`
in `app_controller.dart` supplies whichever generator the parent selected:
`DemoStoryGenerator`, which creates labeled sample content without network
access, or `LocalAiStoryGenerator`, which asks the paired family PC. The demo is
a deliberate choice, never a silent fallback for a failed local AI call.

Relevant source files:

- `lib/core/generation/story_generator.dart`
- `lib/core/generation/demo_story_generator.dart`
- `lib/core/generation/local_ai_story_generator.dart`
- `lib/core/ai_connection/`
- `lib/core/models/story_models.dart`
- `lib/app/app_controller.dart`

`StoryRequest` contains the selected profile identity, hero name, the
parent-confirmed Girl/Boy context, theme, moral, language, story length, and
illustration style. Each generated `StoryPage` contains reader prose and a
`sceneDescription` reserved for the later image workflow.

## Required local implementation

The later adapter must implement `StoryGenerator` and preserve its failure
contract: successful calls return a complete book; failed generation must throw
an error that the creation screen can report. It must not return a partial or
hardcoded success value.

The local workflow should perform these operations:

1. Send the validated story request, including the Girl/Boy context, to an
   Ollama model on the parent's PC.
2. Validate structured model output before constructing `StoryPage` objects.
3. Create one ComfyUI prompt per page using the private reference photo and the
   parent-confirmed character context.
4. Write generated image files into application-controlled local storage.
5. Return a complete `StoryBook` only after required pages are available.
6. Preserve the selected language and page order exactly.

The story model will need an explicit local illustration reference before the
reader can replace its current gradient placeholder. Add that field only when
the file-storage implementation exists in the same change. Until then the
bridge's story and illustration identities travel inside
`StoryPage.sceneDescription`, the model's existing non-user-facing slot for the
image workflow; `BridgeStoryProvenance` writes and reads them, so already saved
stories will not need migrating.

## Implemented order of operations

1. `POST /stories/generate` with the validated request, including the
   Girl/Boy context and the hero's age today.
2. Poll `GET /stories/jobs/<id>` every two seconds; report the queued,
   writing, and checking stage in the app's own language.
3. Validate the completed payload — requested language, exact page count,
   page numbers 1..N in order — before any `StoryPage` is constructed.
4. Return the complete `StoryBook`, which the story controller persists as one
   draft in a single transaction.
5. On cancellation, `POST /stories/jobs/<id>/cancel`; the poll then observes
   `cancelled` and reports it as cancelled, never as failed.

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
- the parent-confirmed Girl/Boy context survives text and image generation;
- cancellation stops the active job and does not report success.

Tests must not assert exact prompt wording, model prose, internal call counts,
or implementation-private helper calls.

## Implementation order

1. ~~Implement a private PC bridge with health reporting and device pairing.~~ Done.
2. ~~Implement and validate Ollama structured story output.~~ Done.
3. ~~Connect the app to the bridge behind a parent-selected generator mode.~~ Done.
4. Add local image-file storage for Android, iOS, and web-compatible metadata.
5. Implement ComfyUI reference-photo and page-illustration jobs.
6. Keep `DemoStoryGenerator` selectable and available to automated tests, never
   as an invisible fallback for failed local AI calls.
