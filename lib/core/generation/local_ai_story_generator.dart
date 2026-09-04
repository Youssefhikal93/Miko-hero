import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/ai_connection/local_ai_progress.dart';
import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// How often one queued job is polled while the PC works on it.
const defaultLocalAiPollInterval = Duration(seconds: 2);

/// Longest the app waits for one job before giving up on the PC.
///
/// A ten-page story on a small GPU takes minutes, so the bound is generous;
/// it exists only so a bridge that stops answering cannot hang a screen.
const defaultLocalAiJobTimeout = Duration(minutes: 30);

/// Generates stories on the paired family PC through the local bridge.
///
/// Failure is always visible: an unreachable bridge, a refused token, a failed
/// job, an unusable payload, or a timeout all throw a [BridgeException]. No
/// path here returns demo content, and no partial book ever leaves this class,
/// so a caller that persists the result cannot store half a story.
class LocalAiStoryGenerator implements CancellableStoryGenerator {
  /// Creates a generator bound to one configured and paired bridge client.
  LocalAiStoryGenerator({
    required this.client,
    required this.resolveAgeYears,
    required this.resolveNameSpelling,
    required this.currentTime,
    this.onProgress,
    this.pollInterval = defaultLocalAiPollInterval,
    this.jobTimeout = defaultLocalAiJobTimeout,
  });

  /// Typed HTTP boundary to the PC bridge.
  final BridgeClient client;

  /// Supplies the hero's age today, which the bridge requires per request.
  final int Function(StoryRequest request) resolveAgeYears;

  /// Supplies how the family writes the hero's name in the story's language.
  ///
  /// Answers an empty string when this child has no confirmed spelling for it,
  /// which is exactly what the bridge treats as "write the name as it came".
  /// Resolved at send time rather than carried in the request, for the same
  /// reason the age is: the profile is the family's current answer, and a
  /// request queued yesterday should be written with today's spelling.
  final String Function(StoryRequest request) resolveNameSpelling;

  /// Clock used for the local book's creation time.
  final DateTime Function() currentTime;

  /// Optional sink for waiting-screen progress; never carries story text.
  final void Function(LocalAiProgress progress)? onProgress;

  /// Delay between two polls of the same job.
  final Duration pollInterval;

  /// Bound on the complete wait for one job.
  final Duration jobTimeout;

  String? _activeJobId;

  @override
  /// Submits one request, waits for the PC, and maps the finished payload.
  Future<StoryBook> generate(StoryRequest request) async {
    if (!request.gender.isSpecified) {
      throw ArgumentError.value(request.gender, 'request.gender');
    }
    _report(const LocalAiProgress(LocalAiStage.submitting));
    final submission = await client.submitStory(_bridgeRequest(request));
    _activeJobId = submission.jobId;
    try {
      _report(
        LocalAiProgress(
          LocalAiStage.queued,
          queuePosition: submission.queuePosition,
        ),
      );
      final completed = await _awaitCompletion(submission.jobId);
      return _storyBook(completed, request);
    } finally {
      _activeJobId = null;
    }
  }

  @override
  /// Tells the bridge to stop the job this generator is waiting on.
  ///
  /// The waiting poll then observes `cancelled` and reports it as such, so a
  /// cancelled request is never mistaken for a failed one.
  Future<void> cancelActiveGeneration() async {
    final jobId = _activeJobId;
    if (jobId == null) return;
    await client.cancelJob(jobId);
  }

  /// Polls one job until it reaches a terminal state or the bound elapses.
  Future<BridgeStory> _awaitCompletion(String jobId) async {
    final deadline = currentTime().add(jobTimeout);
    while (true) {
      await Future<void>.delayed(pollInterval);
      final job = await client.readJob(jobId);
      _reportJob(job);
      switch (job.status) {
        case BridgeJobStatus.completed:
          final story = job.story;
          if (story == null) {
            throw const BridgeException(BridgeFailure.invalidResponse);
          }
          return story;
        case BridgeJobStatus.failed:
          throw BridgeException(
            BridgeFailure.generationFailed,
            code: job.errorCode,
          );
        case BridgeJobStatus.cancelled:
          throw const BridgeException(BridgeFailure.cancelled);
        case BridgeJobStatus.queued:
        case BridgeJobStatus.generating:
        case BridgeJobStatus.validating:
          break;
      }
      if (currentTime().isAfter(deadline)) {
        throw const BridgeException(BridgeFailure.timedOut);
      }
    }
  }

  /// Converts the validated request into the bridge's exact field names.
  BridgeStoryRequest _bridgeRequest(StoryRequest request) {
    final age = resolveAgeYears(request);
    return BridgeStoryRequest(
      profileId: request.profileId,
      heroName: request.heroName,
      heroNameSpelling: resolveNameSpelling(request),
      ageYears: age.clamp(minimumChildAge, maximumChildAge),
      genderContext: request.gender.name,
      languageCode: request.presentation.language.code,
      theme: request.theme,
      moral: request.moral,
      pageCount: request.presentation.length.pageCount,
      illustrationStyle: request.presentation.style.name,
      favoriteTopics: request.prompt.preferences.favoriteThings,
      recurringWorld: request.prompt.preferences.recurringWorld,
    );
  }

  /// Maps a completed payload onto the local model after full validation.
  ///
  /// Refuses a payload whose language, page count, or page order does not
  /// match what the parent asked for, because a book is only ever saved whole.
  StoryBook _storyBook(BridgeStory story, StoryRequest request) {
    final expectedPages = request.presentation.length.pageCount;
    if (story.languageCode != request.presentation.language.code ||
        story.pages.length != expectedPages) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    final pages = <StoryPage>[];
    for (final (index, page) in story.pages.indexed) {
      if (page.pageNumber != index + 1) {
        throw const BridgeException(BridgeFailure.invalidResponse);
      }
      pages.add(
        StoryPage(
          number: page.pageNumber,
          text: page.text,
          sceneDescription: BridgeStoryProvenance(
            scene: page.illustrationScene,
            storyId: story.id,
            illustrationId: page.illustrationId,
          ).toSceneDescription(),
        ),
      );
    }
    final createdAt = currentTime().toUtc();
    return StoryBook(
      id: story.id,
      createdAt: createdAt,
      content: StoryContent(
        title: story.title,
        request: request,
        pages: List<StoryPage>.unmodifiable(pages),
      ),
    );
  }

  /// Translates one polled job into the stage the waiting screen shows.
  void _reportJob(BridgeJob job) {
    switch (job.status) {
      case BridgeJobStatus.queued:
        _report(
          LocalAiProgress(
            LocalAiStage.queued,
            queuePosition: job.queuePosition,
          ),
        );
      case BridgeJobStatus.generating:
        _report(const LocalAiProgress(LocalAiStage.writing));
      case BridgeJobStatus.validating:
        _report(const LocalAiProgress(LocalAiStage.checking));
      case BridgeJobStatus.completed:
      case BridgeJobStatus.failed:
      case BridgeJobStatus.cancelled:
        break;
    }
  }

  /// Publishes one progress snapshot when a listener asked for them.
  void _report(LocalAiProgress progress) => onProgress?.call(progress);
}
