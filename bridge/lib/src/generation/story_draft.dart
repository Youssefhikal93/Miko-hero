import 'dart:convert';

import 'package:iam_hero_bridge/src/generation/generation_errors.dart';

/// Longest accepted title from the model.
const int maximumDraftTitleLength = 200;

/// Longest accepted page prose from the model.
const int maximumDraftPageTextLength = 5000;

/// Longest accepted illustration scene description from the model.
const int maximumDraftSceneLength = 2000;

/// One validated page of model output.
class StoryDraftPage {
  /// Creates a validated page.
  const StoryDraftPage({
    required this.pageNumber,
    required this.text,
    required this.illustrationScene,
  });

  /// One-based page number; always equal to the page's position.
  final int pageNumber;

  /// Page prose in the requested language.
  final String text;

  /// English scene description reserved for the illustration milestone.
  final String illustrationScene;
}

/// A complete, validated story as returned by the model.
///
/// A draft only ever exists when every rule passed; partial drafts are never
/// constructed, so nothing partial can reach the master library.
class StoryDraft {
  /// Creates a validated draft.
  const StoryDraft({required this.title, required this.pages});

  /// Story title in the requested language.
  final String title;

  /// Ordered pages, exactly as many as were requested.
  final List<StoryDraftPage> pages;
}

/// Extracts the model answer from one Ollama `/api/generate` envelope.
///
/// Throws a [GenerationException] with
/// [GenerationFailureCode.invalidModelOutput] when the envelope is not the
/// expected non-streaming shape.
String readOllamaResponseText(String bodyText) {
  final Object? envelope = _decodeJson(
    bodyText,
    'Ollama did not answer with JSON.',
  );
  if (envelope is! Map<String, Object?>) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'Ollama did not answer with a JSON object.',
    );
  }
  final Object? response = envelope['response'];
  if (response is! String || response.trim().isEmpty) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'Ollama answered without a story payload.',
    );
  }
  return response;
}

/// Validates one model answer against every structural rule.
///
/// Rules: valid JSON object, non-empty title, exactly [expectedPageCount]
/// pages, page numbers running 1..N in order, and non-empty text plus scene
/// on every page. Any violation raises a [GenerationException] with
/// [GenerationFailureCode.invalidModelOutput], which the job engine retries.
StoryDraft parseStoryDraft(
  String responseText, {
  required int expectedPageCount,
}) {
  final Object? decoded = _decodeJson(
    responseText,
    'The model answer was not valid JSON.',
  );
  if (decoded is! Map<String, Object?>) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model answer was not a JSON object.',
    );
  }
  final title = _requireText(
    decoded['title'],
    field: 'title',
    maxLength: maximumDraftTitleLength,
  );
  final Object? rawPages = decoded['pages'];
  if (rawPages is! List) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model answer had no page list.',
    );
  }
  if (rawPages.length != expectedPageCount) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model returned ${rawPages.length} pages instead of '
      '$expectedPageCount.',
    );
  }
  final pages = <StoryDraftPage>[];
  for (var index = 0; index < rawPages.length; index++) {
    final Object? rawPage = rawPages[index];
    if (rawPage is! Map<String, Object?>) {
      throw GenerationException(
        GenerationFailureCode.invalidModelOutput,
        'Page ${index + 1} was not a JSON object.',
      );
    }
    final Object? rawNumber = rawPage['pageNumber'];
    if (rawNumber is! int || rawNumber != index + 1) {
      throw GenerationException(
        GenerationFailureCode.invalidModelOutput,
        'Page numbers must run 1 to $expectedPageCount in order.',
      );
    }
    pages.add(
      StoryDraftPage(
        pageNumber: rawNumber,
        text: _requireText(
          rawPage['text'],
          field: 'text on page ${index + 1}',
          maxLength: maximumDraftPageTextLength,
        ),
        illustrationScene: _requireText(
          rawPage['illustrationScene'],
          field: 'illustrationScene on page ${index + 1}',
          maxLength: maximumDraftSceneLength,
        ),
      ),
    );
  }
  return StoryDraft(
    title: title,
    pages: List<StoryDraftPage>.unmodifiable(pages),
  );
}

Object? _decodeJson(String raw, String failureMessage) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      failureMessage,
    );
  }
}

String _requireText(
  Object? value, {
  required String field,
  required int maxLength,
}) {
  if (value is! String || value.trim().isEmpty) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model answer was missing $field.',
    );
  }
  final trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model answer exceeded the accepted length for $field.',
    );
  }
  return trimmed;
}
