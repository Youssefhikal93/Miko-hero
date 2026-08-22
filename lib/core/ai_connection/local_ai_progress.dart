/// Stage of one local-AI generation, reported while the parent waits.
///
/// Deliberately an enum rather than the bridge's `progress` sentence: that
/// sentence is English, and the waiting screen must speak the parent's
/// interface language.
enum LocalAiStage {
  /// The request is being handed to the PC bridge.
  submitting,

  /// The PC accepted the request and it is waiting for the single worker.
  queued,

  /// The local model is writing the story.
  writing,

  /// The PC is checking the finished pages before saving them.
  checking,
}

/// One progress snapshot of the generation currently running on the PC.
class LocalAiProgress {
  /// Creates a stage report, with the queue position when there is one.
  const LocalAiProgress(this.stage, {this.queuePosition});

  /// What the PC is doing right now.
  final LocalAiStage stage;

  /// Place in the bridge queue, present only while the job is waiting.
  final int? queuePosition;
}
