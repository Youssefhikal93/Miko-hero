import 'package:miko_hero/core/models/story_models.dart';

/// Boundary implemented by demo generation now and local AI generation later.
abstract interface class StoryGenerator {
  /// Produces a complete book or propagates a generation failure to the UI.
  Future<StoryBook> generate(StoryRequest request);
}
