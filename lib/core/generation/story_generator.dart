import 'package:miko_hero/core/models/story_models.dart';

/// Boundary implemented by demo generation and by local AI generation.
abstract interface class StoryGenerator {
  /// Produces a complete book or propagates a generation failure to the UI.
  Future<StoryBook> generate(StoryRequest request);
}

/// Generator whose work runs elsewhere and can be stopped after it started.
///
/// The offline demo finishes immediately and needs none of this; a generator
/// waiting on the family PC must be able to tell that PC to stop, so that
/// cancelling in the app never leaves a job running on the other machine.
abstract interface class CancellableStoryGenerator implements StoryGenerator {
  /// Stops the generation currently in flight, if there is one.
  ///
  /// Safe to call when nothing is running, so a queue command never has to
  /// know whether generation already started.
  Future<void> cancelActiveGeneration();
}
