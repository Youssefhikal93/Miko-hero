import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/illustrations/reference_photo.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// Verifies which stored photos are allowed to reach the family PC at all.
///
/// A photo of a child is the most private thing this app moves, so the type is
/// read from the bytes rather than trusted, and anything the bridge would refuse
/// is dropped here instead of being sent and rejected.
void main() {
  test('a real JPEG is recognized from its magic bytes', () {
    final jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

    final photo = readReferencePhoto(base64Encode(jpeg));

    expect(photo, isNotNull);
    expect(photo!.contentType, bridgeJpegContentType);
    expect(photo.bytes, jpeg);
  });

  test('a real PNG is recognized from its magic bytes', () {
    final png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 13, 10, 26]);

    final photo = readReferencePhoto(base64Encode(png));

    expect(photo, isNotNull);
    expect(photo!.contentType, bridgePngContentType);
  });

  test('no stored photo means no photo is sent', () {
    expect(readReferencePhoto(''), isNull);
  });

  test('a photo in another format is left out rather than sent', () {
    final webp = Uint8List.fromList(utf8.encode('RIFF????WEBPVP8 '));
    final gif = Uint8List.fromList(utf8.encode('GIF89a'));

    expect(readReferencePhoto(base64Encode(webp)), isNull);
    expect(readReferencePhoto(base64Encode(gif)), isNull);
  });

  test('a photo past the size the bridge accepts is left out', () {
    final oversized = Uint8List(maximumReferencePhotoBytes + 1)
      ..[0] = 0xFF
      ..[1] = 0xD8
      ..[2] = 0xFF;
    final largestAccepted = Uint8List(maximumReferencePhotoBytes)
      ..[0] = 0xFF
      ..[1] = 0xD8
      ..[2] = 0xFF;

    expect(readReferencePhoto(base64Encode(oversized)), isNull);
    expect(readReferencePhoto(base64Encode(largestAccepted)), isNotNull);
  });

  test('an unreadable stored value is left out rather than thrown', () {
    expect(readReferencePhoto('not base64 at all!'), isNull);
  });

  test('a truncated file is too short to claim a type', () {
    expect(
      sniffImageContentType(Uint8List.fromList(<int>[0xFF, 0xD8])),
      isNull,
    );
    expect(sniffImageContentType(Uint8List(0)), isNull);
  });
}
