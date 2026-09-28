import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/hero_name_spelling_service.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the one authenticated name-spelling endpoint.
///
/// Deliberately not a job: four short names are one small call, and the parent
/// asking for them is looking at the profile editor right now. It answers
/// inside the request or it does not answer at all, and the editor lets the
/// parent type the spellings either way.
class NameSpellingHandlers {
  /// Creates handlers over [service].
  const NameSpellingHandlers({required this._service});

  final HeroNameSpellingService _service;

  /// Handles `POST /profiles/spellings/suggest`.
  ///
  /// Takes `{heroName, gender?}` and answers `{spellings: {ar, en, sv, so}}`.
  /// No profile is named and nothing is written: this is a suggestion about a
  /// string, and where it ends up is the device's business.
  Future<Response> suggestSpellings(Request request) async {
    requireAuthenticatedDevice(request);
    final body = await parseJsonObjectBody(request);
    final reader = JsonReader.root(body, failures: apiFieldFailures);
    final heroName = reader.requireString(
      'heroName',
      maxLength: maximumHeroNameLength,
    );
    final gender = reader.optionalNamedChoice<StoryGenderContext>(
      'gender',
      resolve: StoryGenderContext.fromWireName,
      expected: '"girl" or "boy"',
    );
    final Map<StoryLanguage, String> spellings;
    try {
      spellings = await _service.suggest(heroName: heroName, gender: gender);
    } on GenerationException {
      // One answer for every cause: unreachable, too slow, or an answer that
      // was not four names. The message is fixed so it can never carry the
      // name the call was about.
      throw ApiError(
        503,
        ApiErrorCode.ollamaUnavailable,
        'The local model could not suggest name spellings.',
      );
    }
    return jsonResponse(200, <String, Object?>{
      'spellings': <String, Object?>{
        for (final entry in spellings.entries) entry.key.code: entry.value,
      },
    });
  }
}
