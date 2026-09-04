import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:iam_hero_bridge/src/library/library_catalog.dart';
import 'package:iam_hero_bridge/src/library/profile_deleter.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:iam_hero_bridge/src/server/sync_handlers.dart';
import 'package:iam_hero_bridge/src/sync/sync_reader.dart';
import 'package:shelf/shelf.dart';

/// Longest accepted `profileId` filter value.
///
/// The same limit the photo store puts on an id it has to turn into a file
/// name, so a filter can never be longer than the thing it filters on.
const int maxProfileIdFilterLength = 64;

/// Serves the four endpoints the owner manages the library from.
///
/// Everything here is deliberately dull: two listings, one whole story, one
/// deletion. What it must never be is chatty — no page prose in a listing, no
/// photo bytes, no name in a log line, because every one of these answers is
/// about a named child.
class ManagementHandlers {
  /// Creates handlers over the catalogue, the profile deleter, and the sync
  /// reader whose story serializer this shares.
  const ManagementHandlers({
    required this._catalog,
    required this._deleter,
    required this._stories,
  });

  final LibraryCatalog _catalog;
  final ProfileDeleter _deleter;
  final SyncReader _stories;

  /// Handles `GET /profiles`.
  ///
  /// Metadata for every child in the master library: who they are, whether
  /// they have a reference photo, and how many books they own.
  Future<Response> listProfiles(Request request) async {
    requireAuthenticatedDevice(request);
    final profiles = _catalog
        .listProfiles()
        .map((profile) => profile.toJson())
        .toList(growable: false);
    return jsonResponse(200, <String, Object?>{'profiles': profiles});
  }

  /// Handles `DELETE /profiles/<profileId>`.
  ///
  /// Removes the child and everything the library holds for them. Answers the
  /// same `404 profile_not_found` the app already gets for an unknown
  /// profile, malformed ids included: an id that names no child names none
  /// whichever way it is wrong.
  Future<Response> deleteProfile(Request request, String profileId) async {
    final device = requireAuthenticatedDevice(request);
    final deletion = await _deleter.deleteProfile(
      profileId: profileId,
      requestedByDeviceId: device.id,
      nowUtc: DateTime.now().toUtc(),
    );
    if (deletion == null) {
      throw ApiError(
        404,
        ApiErrorCode.profileNotFound,
        'No profile exists under this id.',
      );
    }
    return jsonResponse(200, deletion.toJson());
  }

  /// Handles `GET /stories`, optionally filtered by `?profileId=`.
  ///
  /// The filter goes through the same reader every body field does — one
  /// known parameter, a length limit, and never the value in the message. A
  /// filter naming no profile is a `400 invalid_field` rather than an empty
  /// list: an empty shelf and a mistyped id look identical otherwise, and the
  /// owner would read the wrong one as an answer.
  Future<Response> listStories(Request request) async {
    requireAuthenticatedDevice(request);
    final reader = JsonReader.root(<String, Object?>{
      ...request.url.queryParameters,
    }, failures: apiQueryFailures);
    reader.rejectUnknownKeys(const <String>{'profileId'});
    final profileId = reader.optionalString(
      'profileId',
      maxLength: maxProfileIdFilterLength,
    );
    if (profileId != null && !_catalog.profileExists(profileId)) {
      reader.fail('profileId', 'must name a profile in this library.');
    }
    final stories = _catalog
        .listStories(profileId: profileId)
        .map((story) => story.toJson())
        .toList(growable: false);
    return jsonResponse(200, <String, Object?>{'stories': stories});
  }

  /// Handles `GET /stories/<storyId>`.
  ///
  /// The same body, down to the byte, that a paired device downloads from
  /// `GET /sync/stories/<storyId>`.
  Future<Response> readStory(Request request, String storyId) async {
    requireAuthenticatedDevice(request);
    return storyDownloadResponse(_stories, storyId);
  }
}
