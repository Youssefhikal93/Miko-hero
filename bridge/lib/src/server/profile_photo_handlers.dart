import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/image_bytes.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the two authenticated reference-photo endpoints.
///
/// The photo is the single most private thing the bridge stores: it is a
/// picture of a child. It arrives as raw bytes rather than base64 JSON so it
/// is never held twice in memory, it is checked against its own magic bytes
/// before it is written, and it is never logged, echoed, or included in an
/// error message.
class ProfilePhotoHandlers {
  /// Creates handlers over [store].
  const ProfilePhotoHandlers({required this._store});

  final ProfilePhotoStore _store;

  /// Handles `PUT /profiles/<profileId>/photo`.
  ///
  /// The body is the image itself. `Content-Type` must be `image/jpeg` or
  /// `image/png`, the bytes must actually be that format, and the whole
  /// upload must stay under [maxReferencePhotoBytes].
  Future<Response> putPhoto(Request request, String profileId) async {
    requireAuthenticatedDevice(request);
    _requireUsableProfileId(profileId);
    final ReferenceImageFormat declared = _requireDeclaredFormat(request);
    final Uint8List bytes = await _readPhotoBytes(request);
    final ReferenceImageFormat? detected = detectReferenceImageFormat(bytes);
    if (detected == null || detected != declared) {
      throw ApiError(
        400,
        ApiErrorCode.invalidImage,
        'The uploaded bytes are not a valid ${declared.contentType} image.',
      );
    }
    final ProfileReferencePhoto stored;
    try {
      stored = await _store.savePhoto(
        profileId: profileId,
        format: declared,
        bytes: bytes,
        nowUtc: DateTime.now().toUtc(),
      );
    } on UnknownProfileException {
      throw _unknownProfile();
    }
    return jsonResponse(200, stored.toJson());
  }

  /// Handles `DELETE /profiles/<profileId>/photo`.
  ///
  /// Idempotent: a profile that has no photo answers `200` with
  /// `"removed": false`. Only an unknown profile answers `404`.
  Future<Response> deletePhoto(Request request, String profileId) async {
    requireAuthenticatedDevice(request);
    _requireUsableProfileId(profileId);
    final bool removed;
    try {
      removed = await _store.deletePhoto(
        profileId: profileId,
        nowUtc: DateTime.now().toUtc(),
      );
    } on UnknownProfileException {
      throw _unknownProfile();
    }
    return jsonResponse(200, <String, Object?>{
      'profileId': profileId,
      'removed': removed,
    });
  }

  void _requireUsableProfileId(String profileId) {
    if (!ProfilePhotoStore.isValidProfileId(profileId)) {
      // A malformed id is reported as unknown rather than invalid: it names
      // no profile either way, and one answer means one thing to probe.
      throw _unknownProfile();
    }
  }

  ReferenceImageFormat _requireDeclaredFormat(Request request) {
    final header = request.headers[HttpHeaders.contentTypeHeader];
    final mimeType = header == null ? '' : header.split(';').first.trim();
    final format = ReferenceImageFormat.fromContentType(mimeType);
    if (format == null) {
      throw ApiError(
        400,
        ApiErrorCode.unsupportedImageType,
        'Content-Type must be image/jpeg or image/png.',
      );
    }
    return format;
  }

  Future<Uint8List> _readPhotoBytes(Request request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > maxReferencePhotoBytes) {
        throw ApiError(
          413,
          ApiErrorCode.photoTooLarge,
          'A reference photo may not exceed '
          '${maxReferencePhotoBytes ~/ (1024 * 1024)} MB.',
        );
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw ApiError(
        400,
        ApiErrorCode.invalidImage,
        'The request body carried no image bytes.',
      );
    }
    return bytes;
  }

  ApiError _unknownProfile() {
    return ApiError(
      404,
      ApiErrorCode.profileNotFound,
      'No profile exists under this id.',
    );
  }
}
