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
    this.profileId,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  /// Master-library identity of the story on the PC.
  final String id;

  /// Cover title written by the model in the requested language.
  final String title;

  /// ISO code of the language every page is written in.
  final String languageCode;

  /// Pages in the order the bridge validated them.
  final List<BridgeStoryPage> pages;

  /// Master-library profile owning the story, when the payload carries one.
  ///
  /// A generated story is already attached to the profile the request named,
  /// so only synchronization has to read it back: a downloaded story must be
  /// placed on the shelf of the child it belongs to.
  final String? profileId;

  /// When the PC first stored the story, when the payload carries it.
  final DateTime? createdAtUtc;

  /// When the PC last changed the story, when the payload carries it.
  final DateTime? updatedAtUtc;

  /// Validates the completed payload before it can become a local book.
  factory BridgeStory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final languageCode = json['languageCode'];
    final pages = json['pages'];
    final profileId = json['profileId'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        languageCode is! String ||
        pages is! List ||
        pages.isEmpty ||
        (profileId != null && (profileId is! String || profileId.isEmpty))) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeStory(
      id: id,
      title: title.trim(),
      languageCode: languageCode,
      pages: List<BridgeStoryPage>.unmodifiable(
        pages.map(BridgeStoryPage.fromEncodedPage),
      ),
      profileId: profileId as String?,
      createdAtUtc: _optionalTimestamp(json['createdAtUtc']),
      updatedAtUtc: _optionalTimestamp(json['updatedAtUtc']),
    );
  }
}

/// Parses one bridge timestamp and refuses a value this client cannot read.
///
/// Every moment in the contract is an ISO-8601 UTC string, and the app keeps
/// them in UTC so a device in another time zone compares them correctly.
DateTime parseBridgeTimestamp(String encodedMoment) {
  try {
    return DateTime.parse(encodedMoment).toUtc();
  } on FormatException {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
}

/// Reads an optional bridge timestamp without trusting a foreign shape.
DateTime? _optionalTimestamp(Object? encodedMoment) {
  if (encodedMoment == null) return null;
  if (encodedMoment is! String) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return parseBridgeTimestamp(encodedMoment);
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

/// Stored reference photo of one child exactly as the PC recorded it.
///
/// The photo itself never comes back: the app already holds the bytes it sent,
/// and the master library keeps its own copy on the PC. Only where the PC put
/// it, what it decided the type was, and how large it is cross this boundary.
class BridgeProfilePhoto {
  /// Creates one validated `PUT /profiles/<id>/photo` answer.
  const BridgeProfilePhoto({
    required this.relativePath,
    required this.contentType,
    required this.sizeBytes,
  });

  /// Where the photo lives inside the PC master library folder.
  final String relativePath;

  /// Image type the bridge accepted the bytes as.
  final String contentType;

  /// Number of bytes the PC stored.
  final int sizeBytes;

  /// Validates the upload answer before the flow continues to rendering.
  factory BridgeProfilePhoto.fromJson(Map<String, Object?> json) {
    final relativePath = json['relativePath'];
    final contentType = json['contentType'];
    final sizeBytes = json['sizeBytes'];
    if (relativePath is! String ||
        relativePath.isEmpty ||
        contentType is! String ||
        contentType.isEmpty ||
        sizeBytes is! int ||
        sizeBytes <= 0) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeProfilePhoto(
      relativePath: relativePath,
      contentType: contentType,
      sizeBytes: sizeBytes,
    );
  }
}

/// Lifecycle of one illustration job as the bridge reports it.
enum BridgeIllustrationJobStatus {
  /// Accepted and waiting for the single renderer; reports a queue position.
  queued,

  /// The PC is drawing pages right now.
  rendering,

  /// The job finished, which does not by itself mean every page succeeded.
  completed,

  /// The job stopped without finishing; earlier pages may still exist.
  failed,

  /// The job stopped because this device asked the bridge to cancel it.
  cancelled;

  /// Whether this state can still change on the next poll.
  bool get isRunning => this == queued || this == rendering;
}

/// Accepted illustration job identity plus how much work it queued.
class BridgeIllustrationSubmission {
  /// Creates the `202 Accepted` answer of `POST /stories/<id>/illustrate`.
  const BridgeIllustrationSubmission({
    required this.jobId,
    required this.pageCount,
    required this.queuePosition,
  });

  /// Identity used to poll and to cancel this job.
  final String jobId;

  /// Number of pages the PC is going to draw.
  final int pageCount;

  /// Place in line, where `1` means next or already starting.
  final int queuePosition;

  /// Validates the queued-job answer before any polling begins.
  factory BridgeIllustrationSubmission.fromJson(Map<String, Object?> json) {
    final jobId = json['jobId'];
    final pageCount = json['pageCount'];
    final queuePosition = json['queuePosition'];
    if (jobId is! String ||
        jobId.isEmpty ||
        pageCount is! int ||
        pageCount < 0 ||
        (queuePosition != null && queuePosition is! int)) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeIllustrationSubmission(
      jobId: jobId,
      pageCount: pageCount,
      queuePosition: queuePosition as int? ?? 1,
    );
  }
}

/// One polled illustration job and how far the PC has come with it.
class BridgeIllustrationJob {
  /// Creates a snapshot of a validated `GET /illustrations/jobs/<id>` answer.
  const BridgeIllustrationJob({
    required this.jobId,
    required this.storyId,
    required this.status,
    required this.pageCount,
    required this.completedPageCount,
    required this.failedPageCount,
    this.queuePosition,
    this.errorCode,
  });

  /// Identity of the polled job.
  final String jobId;

  /// Master-library story whose pages this job draws.
  final String storyId;

  /// Current lifecycle state on the PC.
  final BridgeIllustrationJobStatus status;

  /// Number of pages this job set out to draw.
  final int pageCount;

  /// Pages whose image file now exists on the PC.
  final int completedPageCount;

  /// Pages the PC tried and could not draw.
  ///
  /// A job reaches `completed` even when this is greater than zero, so every
  /// surface reads it rather than assuming a finished job produced every page.
  final int failedPageCount;

  /// Place in line, present only while the job is still queued.
  final int? queuePosition;

  /// Typed bridge failure code, present only on a failed job.
  final String? errorCode;

  /// Whether this state can still change on the next poll.
  bool get isRunning => status.isRunning;

  /// Validates one illustration job answer before it drives a waiting screen.
  factory BridgeIllustrationJob.fromJson(Map<String, Object?> json) {
    final jobId = json['jobId'];
    final storyId = json['storyId'];
    final status = json['status'];
    final queuePosition = json['queuePosition'];
    if (jobId is! String ||
        jobId.isEmpty ||
        storyId is! String ||
        storyId.isEmpty ||
        status is! String ||
        (queuePosition != null && queuePosition is! int)) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeIllustrationJob(
      jobId: jobId,
      storyId: storyId,
      status: _illustrationJobStatus(status),
      pageCount: _requiredCount(json['pageCount']),
      completedPageCount: _requiredCount(json['completedPageCount']),
      failedPageCount: _requiredCount(json['failedPageCount']),
      queuePosition: queuePosition as int?,
      errorCode: _illustrationErrorCode(json['error']),
    );
  }
}

/// Decodes an illustration state this build can reason about, or refuses it.
BridgeIllustrationJobStatus _illustrationJobStatus(String encodedStatus) {
  try {
    return BridgeIllustrationJobStatus.values.byName(encodedStatus);
  } on ArgumentError {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
}

/// Requires one non-negative page count of an illustration job answer.
int _requiredCount(Object? encodedCount) {
  if (encodedCount is! int || encodedCount < 0) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return encodedCount;
}

/// Reads the typed code of a failed illustration job, whatever shape it took.
///
/// The contract states only that a failed job carries an `error`, so both a
/// bare code and the bridge's usual `{code, message}` envelope are accepted.
/// The English message is never read.
String? _illustrationErrorCode(Object? encodedError) {
  if (encodedError is String) {
    return encodedError.isEmpty ? null : encodedError;
  }
  if (encodedError is! Map<String, Object?>) return null;
  final code = encodedError['code'];
  return code is String ? code : null;
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
    this.favoriteTopics = '',
    this.recurringWorld = '',
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

  /// The child's saved favorite things, so the story can weave them in.
  ///
  /// Optional on the wire: an empty value is left out of the body entirely,
  /// which is also what a bridge build from before this field existed sees.
  final String favoriteTopics;

  /// The child's saved recurring story world, when the parent named one.
  ///
  /// Optional on the wire for the same reason as [favoriteTopics].
  final String recurringWorld;

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
      if (favoriteTopics.isNotEmpty) 'favoriteTopics': favoriteTopics,
      if (recurringWorld.isNotEmpty) 'recurringWorld': recurringWorld,
    };
  }
}
