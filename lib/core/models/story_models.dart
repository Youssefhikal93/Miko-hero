import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';

/// Supported story sizes and their exact number of illustrated pages.
enum StoryLength {
  /// A six-page story.
  short(6),

  /// An eight-page story.
  medium(8),

  /// A ten-page story.
  long(10);

  /// Associates a selection with the number of pages it produces.
  const StoryLength(this.pageCount);

  /// Number of reader pages generated for this option.
  final int pageCount;
}

/// Illustration directions understood by the future ComfyUI adapter.
enum IllustrationStyle {
  /// Gentle, rounded children's picture-book art.
  pictureBook,

  /// Traditional watercolor texture and color blending.
  watercolor,

  /// Bright, dimensional animated-film-inspired art.
  colorful3d,
}

/// Parent review state controlling child-library visibility.
enum StoryReviewStatus {
  /// Generated content waiting for explicit parent approval.
  draft,

  /// Parent-approved content visible on normal shelves and recent stories.
  approved,
}

/// Maximum number of collection labels assigned to one story.
const maximumStoryCollections = 6;

/// Maximum characters accepted in one collection label.
const maximumStoryCollectionNameLength = 40;

/// Story presentation settings that travel together to a generator.
class StoryPresentation {
  /// Creates the language, length, and visual style selection.
  const StoryPresentation({
    required this.language,
    required this.length,
    required this.style,
  });

  /// Language used for every page of story text.
  final AppLanguage language;

  /// Requested number of pages.
  final StoryLength length;

  /// Illustration direction for the future image pipeline.
  final IllustrationStyle style;

  /// Converts the presentation selection to a JSON-compatible object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'language': language.code,
      'length': length.name,
      'style': style.name,
    };
  }

  /// Validates and restores presentation settings from local storage.
  factory StoryPresentation.fromJson(Map<String, Object?> json) {
    final language = json['language'];
    final length = json['length'];
    final style = json['style'];
    if (language is! String || length is! String || style is! String) {
      throw const FormatException('Malformed story presentation.');
    }
    try {
      return StoryPresentation(
        language: AppLanguage.requireCode(language),
        length: StoryLength.values.byName(length),
        style: IllustrationStyle.values.byName(style),
      );
    } on ArgumentError {
      throw const FormatException('Unsupported story presentation value.');
    }
  }
}

/// Stable child identity and parent-selected character context for a story.
class StoryHero {
  /// Creates a hero after profile and gender selection have been validated.
  const StoryHero({
    required this.profileId,
    required this.name,
    required this.gender,
  });

  /// Stable child identity used to group stories even when names are edited.
  final String profileId;

  /// Child's name used as the story protagonist.
  final String name;

  /// Girl/Boy context used by prose and future illustration prompts.
  final ChildGender gender;

  /// Converts hero context to fields retained by the existing storage schema.
  Map<String, Object> toJson() {
    return <String, Object>{
      'profileId': profileId,
      'heroName': name,
      'gender': gender.name,
    };
  }

  /// Restores hero fields with explicit fallbacks for older stored stories.
  factory StoryHero.fromJson(
    Map<String, Object?> json, {
    String? fallbackProfileId,
    ChildGender? fallbackGender,
  }) {
    final storedProfileId = json['profileId'];
    if (storedProfileId != null && storedProfileId is! String) {
      throw const FormatException('Malformed story profile identity.');
    }
    final profileId = storedProfileId as String? ?? fallbackProfileId;
    final heroName = json['heroName'];
    if (profileId == null ||
        profileId.trim().isEmpty ||
        heroName is! String ||
        heroName.trim().isEmpty) {
      throw const FormatException('Malformed story hero.');
    }
    return StoryHero(
      profileId: profileId,
      name: heroName,
      gender: _storyGender(json['gender'], fallbackGender: fallbackGender),
    );
  }
}

/// Parent idea plus the selected child's saved prompt and safety context.
class StoryPrompt {
  /// Creates immutable prompt context for one generated story.
  const StoryPrompt({
    required this.theme,
    required this.moral,
    required this.preferences,
  });

  /// Parent-entered setting or adventure idea.
  final String theme;

  /// Parent-entered lesson woven into the plot.
  final String moral;

  /// Per-child preferences copied at story creation time.
  final ChildStoryPreferences preferences;

  /// Converts prompt context into current story JSON.
  Map<String, Object> toJson() {
    return <String, Object>{
      'theme': theme,
      'moral': moral,
      'preferences': preferences.toJson(),
    };
  }

  /// Validates current prompt JSON and embedded child preferences.
  factory StoryPrompt.fromJson(Map<String, Object?> json) {
    final theme = json['theme'];
    final moral = json['moral'];
    final preferences = json['preferences'];
    if (theme is! String ||
        theme.trim().isEmpty ||
        moral is! String ||
        moral.trim().isEmpty ||
        preferences is! Map<String, Object?>) {
      throw const FormatException('Malformed story prompt.');
    }
    return StoryPrompt(
      theme: theme.trim(),
      moral: moral.trim(),
      preferences: ChildStoryPreferences.fromJson(preferences),
    );
  }

  /// Migrates the original flat theme and moral fields with safe defaults.
  factory StoryPrompt.fromLegacyJson(Map<String, Object?> json) {
    final theme = json['theme'];
    final moral = json['moral'];
    if (theme is! String ||
        theme.trim().isEmpty ||
        moral is! String ||
        moral.trim().isEmpty) {
      throw const FormatException('Malformed story request.');
    }
    return StoryPrompt(
      theme: theme.trim(),
      moral: moral.trim(),
      preferences: const ChildStoryPreferences(),
    );
  }
}

/// Parent-authored inputs supplied to a story generator.
class StoryRequest {
  /// Creates an immutable request after user input validation.
  const StoryRequest({
    required this.hero,
    required this.prompt,
    required this.presentation,
  });

  /// Selected child identity, name, and Girl/Boy story context.
  final StoryHero hero;

  /// Stable child identity used by library grouping.
  String get profileId => hero.profileId;

  /// Child's name used as the story protagonist.
  String get heroName => hero.name;

  /// Parent-confirmed gender context used by generation.
  ChildGender get gender => hero.gender;

  /// Parent idea and the child's saved prompt boundaries.
  final StoryPrompt prompt;

  /// Parent-entered setting or adventure idea.
  String get theme => prompt.theme;

  /// Parent-entered lesson woven into the plot.
  String get moral => prompt.moral;

  /// Language, length, and illustration choices.
  final StoryPresentation presentation;

  /// Converts the request into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      ...hero.toJson(),
      'prompt': prompt.toJson(),
      'presentation': presentation.toJson(),
    };
  }

  /// Restores local JSON with optional identity and gender migration context.
  factory StoryRequest.fromJson(
    Map<String, Object?> json, {
    String? fallbackProfileId,
    ChildGender? fallbackGender,
  }) {
    final encodedPrompt = json['prompt'];
    final presentation = json['presentation'];
    if (presentation is! Map<String, Object?>) {
      throw const FormatException('Malformed story presentation.');
    }
    return StoryRequest(
      hero: StoryHero.fromJson(
        json,
        fallbackProfileId: fallbackProfileId,
        fallbackGender: fallbackGender,
      ),
      prompt: encodedPrompt == null
          ? StoryPrompt.fromLegacyJson(json)
          : StoryPrompt.fromJson(_storyPromptJson(encodedPrompt)),
      presentation: StoryPresentation.fromJson(presentation),
    );
  }
}

/// Requires a current story prompt field to be a JSON object.
Map<String, Object?> _storyPromptJson(Object? encodedPrompt) {
  if (encodedPrompt is! Map<String, Object?>) {
    throw const FormatException('Malformed story prompt.');
  }
  return encodedPrompt;
}

/// One page of text and its future illustration direction.
class StoryPage {
  /// Creates a reader page with a stable one-based number.
  const StoryPage({
    required this.number,
    required this.text,
    required this.sceneDescription,
  });

  /// One-based page number displayed to the reader.
  final int number;

  /// Page prose in the selected story language.
  final String text;

  /// Non-user-facing input reserved for the future ComfyUI workflow.
  final String sceneDescription;

  /// Converts this page into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'number': number,
      'text': text,
      'sceneDescription': sceneDescription,
    };
  }

  /// Validates and restores a page from local storage.
  factory StoryPage.fromJson(Map<String, Object?> json) {
    final number = json['number'];
    final text = json['text'];
    final sceneDescription = json['sceneDescription'];
    if (number is! int || text is! String || sceneDescription is! String) {
      throw const FormatException('Malformed story page.');
    }
    return StoryPage(
      number: number,
      text: text,
      sceneDescription: sceneDescription,
    );
  }
}

/// Generated story content independent of its storage identity.
class StoryContent {
  /// Creates the title, request context, and ordered reader pages.
  const StoryContent({
    required this.title,
    required this.request,
    required this.pages,
  });

  /// Localized title shown on the cover and in the library.
  final String title;

  /// Inputs that produced the story.
  final StoryRequest request;

  /// Ordered pages displayed by the reader.
  final List<StoryPage> pages;

  /// Converts content into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'title': title,
      'request': request.toJson(),
      'pages': pages.map((page) => page.toJson()).toList(),
    };
  }

  /// Restores content while forwarding legacy hero context to its request.
  factory StoryContent.fromJson(
    Map<String, Object?> json, {
    String? fallbackProfileId,
    ChildGender? fallbackGender,
  }) {
    final title = json['title'];
    final request = json['request'];
    final pages = json['pages'];
    if (title is! String ||
        request is! Map<String, Object?> ||
        pages is! List) {
      throw const FormatException('Malformed story content.');
    }
    final decodedPages = pages.map(_decodeStoryPage).toList(growable: false);
    if (decodedPages.isEmpty) {
      throw const FormatException('Story content requires at least one page.');
    }
    return StoryContent(
      title: title,
      request: StoryRequest.fromJson(
        request,
        fallbackProfileId: fallbackProfileId,
        fallbackGender: fallbackGender,
      ),
      pages: decodedPages,
    );
  }
}

/// A locally stored book with stable identity and creation time.
class StoryBook {
  /// Creates a complete book ready for the local library.
  const StoryBook({
    required this.id,
    required this.createdAt,
    required this.content,
    this.reviewStatus = StoryReviewStatus.approved,
    this.isFavorite = false,
    this.collections = const <String>[],
  });

  /// Device-local identity used in routes and deletion commands.
  final String id;

  /// UTC timestamp used to sort the library newest first.
  final DateTime createdAt;

  /// Title, generation request, and reader pages.
  final StoryContent content;

  /// Whether this book still needs review or is visible to the child.
  final StoryReviewStatus reviewStatus;

  /// Child-facing favorite marker retained with the local book.
  final bool isFavorite;

  /// Parent-managed collection labels used to filter one child's shelf.
  final List<String> collections;

  /// Converts a book into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'content': content.toJson(),
      'reviewStatus': reviewStatus.name,
      'isFavorite': isFavorite,
      'collections': collections,
    };
  }

  /// Restores a complete book with optional legacy-profile migration context.
  factory StoryBook.fromJson(
    Map<String, Object?> json, {
    String? fallbackProfileId,
    ChildGender? fallbackGender,
  }) {
    final id = json['id'];
    final createdAt = json['createdAt'];
    final content = json['content'];
    final reviewStatus = json['reviewStatus'];
    final isFavorite = json['isFavorite'];
    final collections = json['collections'];
    if (id is! String ||
        createdAt is! String ||
        content is! Map<String, Object?> ||
        (reviewStatus != null && reviewStatus is! String) ||
        (isFavorite != null && isFavorite is! bool) ||
        (collections != null && collections is! List)) {
      throw const FormatException('Malformed story book.');
    }
    return StoryBook(
      id: id,
      createdAt: DateTime.parse(createdAt).toUtc(),
      content: StoryContent.fromJson(
        content,
        fallbackProfileId: fallbackProfileId,
        fallbackGender: fallbackGender,
      ),
      reviewStatus: _reviewStatus(reviewStatus),
      isFavorite: isFavorite as bool? ?? false,
      collections: _storyCollections(collections),
    );
  }

  /// Returns the same book after a parent review-state decision.
  StoryBook withReviewStatus(StoryReviewStatus status) {
    return _copy(reviewStatus: status);
  }

  /// Returns the same book after a child-facing favorite change.
  StoryBook withFavorite(bool favorite) {
    return _copy(isFavorite: favorite);
  }

  /// Returns the same book with validated parent-managed collection labels.
  StoryBook withCollections(List<String> savedCollections) {
    return _copy(collections: _storyCollections(savedCollections));
  }

  /// Returns generated content with the queue-derived idempotent identity.
  StoryBook withId(String savedId) {
    if (savedId.trim().isEmpty) throw ArgumentError.value(savedId, 'savedId');
    return StoryBook(
      id: savedId,
      createdAt: createdAt,
      content: content,
      reviewStatus: reviewStatus,
      isFavorite: isFavorite,
      collections: collections,
    );
  }

  /// Copies metadata without rebuilding nested generated story content.
  StoryBook _copy({
    StoryReviewStatus? reviewStatus,
    bool? isFavorite,
    List<String>? collections,
  }) {
    return StoryBook(
      id: id,
      createdAt: createdAt,
      content: content,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      isFavorite: isFavorite ?? this.isFavorite,
      collections: collections ?? this.collections,
    );
  }
}

/// Migrates older books to approved and rejects unknown review states.
StoryReviewStatus _reviewStatus(Object? encodedStatus) {
  if (encodedStatus == null) return StoryReviewStatus.approved;
  try {
    return StoryReviewStatus.values.byName(encodedStatus as String);
  } on ArgumentError {
    throw const FormatException('Unsupported story review status.');
  }
}

/// Normalizes collection labels while enforcing bounded unique metadata.
List<String> _storyCollections(Object? encodedCollections) {
  if (encodedCollections == null) return const <String>[];
  if (encodedCollections is! Iterable) {
    throw const FormatException('Malformed story collections.');
  }
  final collections = <String>[];
  for (final value in encodedCollections) {
    if (value is! String) {
      throw const FormatException('Malformed story collection name.');
    }
    final name = value.trim();
    if (name.isEmpty || name.length > maximumStoryCollectionNameLength) {
      throw const FormatException('Malformed story collection name.');
    }
    if (!collections.contains(name)) collections.add(name);
  }
  if (collections.length > maximumStoryCollections) {
    throw const FormatException('Too many story collections.');
  }
  return List<String>.unmodifiable(collections);
}

/// Decodes current gender names or preserves pre-gender stories as unspecified.
ChildGender _storyGender(Object? encodedGender, {ChildGender? fallbackGender}) {
  if (encodedGender == null) {
    return fallbackGender ?? ChildGender.unspecified;
  }
  if (encodedGender is! String) {
    throw const FormatException('Malformed story gender.');
  }
  try {
    return ChildGender.values.byName(encodedGender);
  } on ArgumentError {
    throw const FormatException('Unsupported story gender.');
  }
}

/// Decodes one page while preserving a precise format error at the boundary.
StoryPage _decodeStoryPage(Object? encodedPage) {
  if (encodedPage is! Map<String, Object?>) {
    throw const FormatException('Malformed story page.');
  }
  return StoryPage.fromJson(encodedPage);
}
