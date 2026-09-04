import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:iam_hero_bridge/src/generation/hero_sheet_service.dart';
import 'package:iam_hero_bridge/src/library/character_sheet_store.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the three authenticated hero-sheet endpoints of one profile.
///
/// The sheet has two halves and they have two owners. The PC owns the derived
/// half — hair, skin tone, eye colour, and the hash of the photo they were read
/// from — because it is the only thing that ever looks at the photo. The parent
/// owns the wardrobe half: what their hero always wears and always carries.
/// `PUT` therefore accepts the wardrobe and nothing else, and the only way to
/// move the derived half is to ask the PC to read the photo again.
///
/// The sheet is how one named child's hero is drawn, so it is answered only for
/// a profile a paired device asked for by id, and not one word of it is ever
/// logged.
class HeroSheetHandlers {
  /// Creates handlers over the sheet service and the profile lookup.
  ///
  /// [profiles] is the same [ProfilePhotoStore] the photo endpoints use rather
  /// than a second one: whether a profile exists must not have two answers.
  const HeroSheetHandlers({required this._sheets, required this._profiles});

  final HeroSheetService _sheets;
  final ProfilePhotoStore _profiles;

  /// Handles `GET /profiles/<profileId>/hero-sheet`.
  ///
  /// Answers `200` with `"sheet": null` for a child whose photo has never been
  /// read: that is a state, not a failure. Only an unknown profile is `404`.
  Future<Response> readSheet(Request request, String profileId) async {
    requireAuthenticatedDevice(request);
    _requireKnownProfile(profileId);
    return _sheetResponse(200, profileId, _sheets.storedSheet(profileId));
  }

  /// Handles `PUT /profiles/<profileId>/hero-sheet`.
  ///
  /// Body carries `outfit` and `prop` only. Both are optional and a blank one
  /// means "nothing here", so a parent can clear a costume as deliberately as
  /// they typed it; anything longer than one short phrase is refused, because
  /// the line these join is repeated into every page's scene description.
  ///
  /// A child whose photo has not been read yet still gets their wardrobe
  /// stored: the derived half stays empty until there is a photo to read.
  Future<Response> saveWardrobe(Request request, String profileId) async {
    requireAuthenticatedDevice(request);
    _requireKnownProfile(profileId);
    final reader = JsonReader.root(
      await parseJsonObjectBody(request),
      failures: apiFieldFailures,
    );
    reader.rejectUnknownKeys(const <String>{'outfit', 'prop'});
    final String outfit = reader.optionalText(
      'outfit',
      maxLength: maximumCharacterSheetFieldLength,
    );
    final String prop = reader.optionalText(
      'prop',
      maxLength: maximumCharacterSheetFieldLength,
    );
    final HeroCharacterSheet saved = _sheets.saveWardrobe(
      profileId: profileId,
      outfit: outfit,
      prop: prop,
    );
    return _sheetResponse(200, profileId, saved);
  }

  /// Handles `POST /profiles/<profileId>/hero-sheet/rederive`.
  ///
  /// Answers `202`: the request is accepted, and the sheet in the body is the
  /// best the PC has by the time it answers. The re-read waits for the one GPU
  /// and runs through the same [HeroSheetService] every other path does, so a
  /// card that is busy drawing a book keeps it — and the answer is then the
  /// sheet as it stood, with `"started": true` saying the re-read is still
  /// coming. Nothing here fails the caller: there is no outcome a parent could
  /// act on beyond asking again.
  Future<Response> rederiveSheet(Request request, String profileId) async {
    requireAuthenticatedDevice(request);
    _requireKnownProfile(profileId);
    final HeroCharacterSheet? sheet = await _sheets.rereadFromPhoto(profileId);
    return _sheetResponse(202, profileId, sheet, started: true);
  }

  /// The one body shape all three endpoints answer with.
  Response _sheetResponse(
    int status,
    String profileId,
    HeroCharacterSheet? sheet, {
    bool started = false,
  }) {
    return jsonResponse(status, <String, Object?>{
      'profileId': profileId,
      if (started) 'started': true,
      'sheet': sheet?.toJson(),
    });
  }

  /// Refuses an id that names no child, malformed ids included.
  ///
  /// One answer for both, as the photo endpoints do: an id that names no
  /// profile names none whichever way it is wrong, and one answer means one
  /// thing to probe.
  void _requireKnownProfile(String profileId) {
    if (!ProfilePhotoStore.isValidProfileId(profileId) ||
        !_profiles.profileExists(profileId)) {
      throw ApiError(
        404,
        ApiErrorCode.profileNotFound,
        'No profile exists under this id.',
      );
    }
  }
}
