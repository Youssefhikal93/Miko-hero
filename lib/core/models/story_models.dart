import 'package:miko_hero/core/models/app_language.dart';

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
        language: AppLanguage.fromCode(language),
        length: StoryLength.values.byName(length),
        style: IllustrationStyle.values.byName(style),
      );
    } on ArgumentError {
      throw const FormatException('Unsupported story presentation value.');
    }
  }
}

/// Parent-authored inputs supplied to a story generator.
class StoryRequest {
  /// Creates an immutable request after user input validation.
  const StoryRequest({
    required this.heroName,
    required this.theme,
    required this.moral,
    required this.presentation,
  });

  /// Child's name used as the story protagonist.
  final String heroName;

  /// Parent-entered setting or adventure idea.
  final String theme;

  /// Parent-entered lesson woven into the plot.
  final String moral;

  /// Language, length, and illustration choices.
  final StoryPresentation presentation;

  /// Converts the request into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'heroName': heroName,
      'theme': theme,
      'moral': moral,
      'presentation': presentation.toJson(),
    };
  }

  /// Validates and restores a request from local storage.
  factory StoryRequest.fromJson(Map<String, Object?> json) {
    final heroName = json['heroName'];
    final theme = json['theme'];
    final moral = json['moral'];
    final presentation = json['presentation'];
    if (heroName is! String || theme is! String || moral is! String) {
      throw const FormatException('Malformed story request.');
    }
    if (presentation is! Map<String, Object?>) {
      throw const FormatException('Malformed story presentation.');
    }
    return StoryRequest(
      heroName: heroName,
      theme: theme,
      moral: moral,
      presentation: StoryPresentation.fromJson(presentation),
    );
  }
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

  /// Validates and restores story content from local storage.
  factory StoryContent.fromJson(Map<String, Object?> json) {
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
      request: StoryRequest.fromJson(request),
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
  });

  /// Device-local identity used in routes and deletion commands.
  final String id;

  /// UTC timestamp used to sort the library newest first.
  final DateTime createdAt;

  /// Title, generation request, and reader pages.
  final StoryContent content;

  /// Converts a book into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'content': content.toJson(),
    };
  }

  /// Validates and restores a complete book from local storage.
  factory StoryBook.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final createdAt = json['createdAt'];
    final content = json['content'];
    if (id is! String ||
        createdAt is! String ||
        content is! Map<String, Object?>) {
      throw const FormatException('Malformed story book.');
    }
    return StoryBook(
      id: id,
      createdAt: DateTime.parse(createdAt).toUtc(),
      content: StoryContent.fromJson(content),
    );
  }
}

/// Decodes one page while preserving a precise format error at the boundary.
StoryPage _decodeStoryPage(Object? encodedPage) {
  if (encodedPage is! Map<String, Object?>) {
    throw const FormatException('Malformed story page.');
  }
  return StoryPage.fromJson(encodedPage);
}
