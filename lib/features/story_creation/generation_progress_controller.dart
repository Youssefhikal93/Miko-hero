import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/ai_connection/local_ai_progress.dart';

/// Exposes what the paired PC is doing during the current generation.
///
/// Null whenever nothing is running, and always null for the offline demo
/// generator, which finishes before a stage would be worth showing.
final generationProgressProvider =
    NotifierProvider<GenerationProgressController, LocalAiProgress?>(
      GenerationProgressController.new,
    );

/// Holds the latest local-AI stage without persisting anything.
class GenerationProgressController extends Notifier<LocalAiProgress?> {
  @override
  /// Starts every session with no generation in flight.
  LocalAiProgress? build() => null;

  /// Publishes the stage the generator just reached.
  void report(LocalAiProgress progress) {
    state = progress;
  }

  /// Clears progress once a request finished, failed, or was cancelled.
  void clear() {
    state = null;
  }
}
