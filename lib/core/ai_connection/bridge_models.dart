import 'package:miko_hero/core/ai_connection/bridge_exception.dart';

/// Health of the PC bridge and of the local services it depends on.
///
/// Only the availability flags cross this boundary: the bridge's own `detail`
/// sentences are English, and every status shown to a parent is localized in
/// the app instead.
class BridgeHealth {
  /// Creates one health snapshot from a validated `GET /health` answer.
  const BridgeHealth({
    required this.version,
    required this.isOllamaAvailable,
    required this.isComfyUiAvailable,
    required this.isLibraryAvailable,
  });

  /// Bridge build version, shown only as diagnostic detail.
  final String version;

  /// Whether the configured Ollama model answered its probe.
  final bool isOllamaAvailable;

  /// Whether the local ComfyUI install answered its probe.
  final bool isComfyUiAvailable;

  /// Whether the master library database and folders are usable.
  final bool isLibraryAvailable;

  /// Validates the health payload the bridge returns without authentication.
  factory BridgeHealth.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final statuses = json['statuses'];
    if (version is! String || statuses is! Map<String, Object?>) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeHealth(
      version: version,
      isOllamaAvailable: _available(statuses['ollama']),
      isComfyUiAvailable: _available(statuses['comfyui']),
      isLibraryAvailable: _available(statuses['library']),
    );
  }
}

/// Reads one dependency status without trusting an absent or foreign shape.
bool _available(Object? encodedStatus) {
  if (encodedStatus is! Map<String, Object?>) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  final available = encodedStatus['available'];
  if (available is! bool) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return available;
}

/// Lifecycle of one generation job as the bridge reports it.
enum BridgeJobStatus {
  /// Accepted and waiting for the single worker; reports a queue position.
  queued,

  /// The model is writing the story right now.
  generating,

  /// The bridge is checking the model's structured output.
  validating,

  /// The story was written to the master library and travels with the job.
  completed,

  /// Generation ran and failed; no story exists on the PC.
  failed,

  /// Generation stopped on request; the bridge never persists a partial story.
  cancelled;

  /// Whether this state can still change on the next poll.
  bool get isRunning =>
      this == queued || this == generating || this == validating;
}

/// Accepted job identity plus its position in the bridge's single-worker queue.
class BridgeJobSubmission {
  /// Creates the `202 Accepted` answer of `POST /stories/generate`.
  const BridgeJobSubmission({required this.jobId, required this.queuePosition});

  /// Identity used to poll and to cancel this job.
  final String jobId;

  /// Place in line, where `1` means next or already starting.
  final int queuePosition;

  /// Validates the queued-job answer before any polling begins.
  factory BridgeJobSubmission.fromJson(Map<String, Object?> json) {
    final jobId = json['jobId'];
    final queuePosition = json['queuePosition'];
    if (jobId is! String || jobId.isEmpty || queuePosition is! int) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeJobSubmission(jobId: jobId, queuePosition: queuePosition);
  }
}

/// One polled generation job and, once completed, the whole story payload.
class BridgeJob {
  /// Creates a job snapshot from a validated `GET /stories/jobs/<id>` answer.
  const BridgeJob({
    required this.jobId,
    required this.status,
    this.queuePosition,
    this.story,
    this.errorCode,
  });

  /// Identity of the polled job.
  final String jobId;

  /// Current lifecycle state on the PC.
  final BridgeJobStatus status;

  /// Place in line, present only while the job is still queued.
  final int? queuePosition;

  /// Complete story, present only once the job completed.
  final BridgeStory? story;

  /// Typed bridge failure code, present only on a failed job.
  final String? errorCode;

  /// Validates one job answer, including the story of a completed job.
  factory BridgeJob.fromJson(Map<String, Object?> json) {
    final jobId = json['jobId'];
    final status = json['status'];
    final queuePosition = json['queuePosition'];
    final story = json['story'];
    if (jobId is! String ||
        jobId.isEmpty ||
        status is! String ||
        (queuePosition != null && queuePosition is! int)) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    final jobStatus = _jobStatus(status);
    if (jobStatus == BridgeJobStatus.completed &&
        story is! Map<String, Object?>) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeJob(
      jobId: jobId,
      status: jobStatus,
      queuePosition: queuePosition as int?,
      story: story is Map<String, Object?> ? BridgeStory.fromJson(story) : null,
      errorCode: _errorCode(json['error']),
    );
  }
}

/// Decodes a job state and refuses a state this build cannot reason about.
BridgeJobStatus _jobStatus(String encodedStatus) {
  try {
    return BridgeJobStatus.values.byName(encodedStatus);
  } on ArgumentError {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
}

/// Reads the typed failure code of a failed job without its English message.
String? _errorCode(Object? encodedError) {
  if (encodedError is! Map<String, Object?>) return null;
  final code = encodedError['code'];
  return code is String ? code : null;
}

/// One story exactly as the bridge stored it in the PC master library.
class BridgeStory {
  /// Creates a story payload with its ordered pages.
  const BridgeStory({
    required this.id,
    required this.title,
    required this.languageCode,
    required this.pages,
  });

  /// Master-library identity of the story on the PC.
  final String id;

  /// Cover title written by the model in the requested language.
  final String title;

  /// ISO code of the language every page is written in.
  final String languageCode;

  /// Pages in the order the bridge validated them.
  final List<BridgeStoryPage> pages;

  /// Validates the completed payload before it can become a local book.
  factory BridgeStory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final languageCode = json['languageCode'];
    final pages = json['pages'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        languageCode is! String ||
        pages is! List ||
        pages.isEmpty) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeStory(
      id: id,
      title: title.trim(),
      languageCode: languageCode,
      pages: List<BridgeStoryPage>.unmodifiable(
        pages.map(BridgeStoryPage.fromEncodedPage),
      ),
    );
  }
}

/// One generated page and the identity of its pending illustration.
class BridgeStoryPage {
  /// Creates a page with the scene text reserved for the image workflow.
  const BridgeStoryPage({
    required this.pageNumber,
    required this.text,
    required this.illustrationScene,
    required this.illustrationId,
  });

  /// One-based page number as validated by the bridge.
  final int pageNumber;

  /// Reader prose in the requested story language.
  final String text;

  /// English scene direction reserved for the later ComfyUI workflow.
  final String illustrationScene;

  /// Master-library identity of this page's pending illustration row.
  final String illustrationId;

  /// Validates one entry of the completed payload's page list.
  static BridgeStoryPage fromEncodedPage(Object? encodedPage) {
    if (encodedPage is! Map<String, Object?>) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    final pageNumber = encodedPage['pageNumber'];
    final text = encodedPage['text'];
    final scene = encodedPage['illustrationScene'];
    final illustrationId = encodedPage['illustrationId'];
    if (pageNumber is! int ||
        text is! String ||
        text.trim().isEmpty ||
        scene is! String ||
        illustrationId is! String) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeStoryPage(
      pageNumber: pageNumber,
      text: text,
      illustrationScene: scene,
      illustrationId: illustrationId,
    );
  }
}

/// Exact `POST /stories/generate` body accepted by the bridge.
class BridgeStoryRequest {
  /// Creates the request payload after the app validated every field.
  const BridgeStoryRequest({
    required this.profileId,
    required this.heroName,
    required this.ageYears,
    required this.genderContext,
    required this.languageCode,
    required this.theme,
    required this.moral,
    required this.pageCount,
    required this.illustrationStyle,
  });

  /// Stable local child identity, reused as the PC library profile key.
  final String profileId;

  /// Child's name used as the story protagonist.
  final String heroName;

  /// Child's age in whole years on the day the request is sent.
  final int ageYears;

  /// Parent-confirmed context, `girl` or `boy`; never the unspecified state.
  final String genderContext;

  /// ISO code of the requested story language: `ar`, `en`, `sv`, or `so`.
  final String languageCode;

  /// Parent-entered setting or adventure idea.
  final String theme;

  /// Parent-entered lesson woven into the plot.
  final String moral;

  /// Requested reader page count: 6, 8, or 10.
  final int pageCount;

  /// Requested illustration direction understood by the bridge.
  final String illustrationStyle;

  /// Converts the request into the bridge's JSON field names.
  Map<String, Object> toJson() {
    return <String, Object>{
      'profileId': profileId,
      'heroName': heroName,
      'ageYears': ageYears,
      'genderContext': genderContext,
      'languageCode': languageCode,
      'theme': theme,
      'moral': moral,
      'pageCount': pageCount,
      'illustrationStyle': illustrationStyle,
    };
  }
}
