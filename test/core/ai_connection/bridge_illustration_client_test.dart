import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies the photo, illustration job, and image endpoints of the client.
///
/// Only the HTTP boundary is replaced, so the raw photo body, the ETag round
/// trip, and the mapping from the bridge's typed error codes all stay honest.
void main() {
  final baseUrl = Uri.parse(defaultBridgeBaseUrl);

  /// Builds a paired client over one scripted PC boundary.
  BridgeClient pairedClient(FakeBridgeHttpClient httpClient) {
    return BridgeClient(
      httpClient: httpClient,
      baseUrl: baseUrl,
      deviceToken: 'device-token',
    );
  }

  test('a reference photo travels as raw bytes, never as JSON', () async {
    final photo = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0x01, 0x02]);
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'profileId': 'miko',
        'relativePath': 'profiles/miko/photo.jpg',
        'contentType': 'image/jpeg',
        'sizeBytes': 5,
      });
    });

    final stored = await pairedClient(httpClient).uploadProfilePhoto(
      profileId: 'miko',
      bytes: photo,
      contentType: bridgeJpegContentType,
    );

    expect(stored.relativePath, 'profiles/miko/photo.jpg');
    expect(stored.contentType, 'image/jpeg');
    expect(stored.sizeBytes, 5);
    final sent = httpClient.requests.single;
    expect(sent.method, 'PUT');
    expect(sent.url.path, '/profiles/miko/photo');
    expect(sent.headers['content-type'], 'image/jpeg');
    expect(sent.headers['authorization'], 'Bearer device-token');
    expect(sent.bodyBytes, photo);
    // A base64 JSON envelope would have made the body larger than the image
    // and would have put a child's face into a text field.
    expect(sent.bodyBytes, hasLength(photo.length));
  });

  test('a refused photo becomes its own typed failure', () async {
    for (final testCase in <(String, int, BridgeFailure)>[
      ('profile_not_found', 404, BridgeFailure.profileNotFound),
      ('photo_too_large', 413, BridgeFailure.photoTooLarge),
      ('invalid_image', 400, BridgeFailure.unsupportedImage),
      ('unsupported_image_type', 400, BridgeFailure.unsupportedImage),
    ]) {
      final client = pairedClient(
        FakeBridgeHttpClient((request) async {
          return bridgeErrorResponse(testCase.$1, testCase.$2);
        }),
      );

      await expectLater(
        client.uploadProfilePhoto(
          profileId: 'miko',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          contentType: bridgePngContentType,
        ),
        throwsA(_failure(testCase.$3)),
        reason: testCase.$1,
      );
    }
  });

  test('a stored photo can be removed again', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'profileId': 'miko',
        'removed': true,
      });
    });

    final removed = await pairedClient(httpClient).deleteProfilePhoto('miko');

    expect(removed, isTrue);
    expect(httpClient.requests.single.method, 'DELETE');
    expect(httpClient.requests.single.url.path, '/profiles/miko/photo');
  });

  test('one illustrate request carries the style and the gender', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'illustration-job-1',
        'pageCount': 6,
        'queuePosition': 2,
      }, statusCode: 202);
    });

    final submission = await pairedClient(httpClient).illustrateStory(
      'story-a',
      illustrationStyle: 'watercolor',
      genderContext: 'girl',
    );

    expect(submission.jobId, 'illustration-job-1');
    expect(submission.pageCount, 6);
    expect(submission.queuePosition, 2);
    final body = httpClient.jsonBodiesFor('/stories/story-a/illustrate').single;
    expect(body['illustrationStyle'], 'watercolor');
    expect(body['genderContext'], 'girl');
  });

  test('a story the PC forgot is reported as such, not as a job', () async {
    final client = pairedClient(
      FakeBridgeHttpClient((request) async {
        return bridgeErrorResponse('story_not_found', 404);
      }),
    );

    await expectLater(
      client.illustrateStory('story-a'),
      throwsA(_failure(BridgeFailure.storyNotFound)),
    );
  });

  test('a polled job reports its counts, failures included', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'illustration-job-1',
        'storyId': 'story-a',
        'status': 'completed',
        'progress': 'Drew 5 of 6 pages.',
        'pageCount': 6,
        'completedPageCount': 5,
        'failedPageCount': 1,
      });
    });

    final job = await pairedClient(
      httpClient,
    ).readIllustrationJob('illustration-job-1');

    expect(job.storyId, 'story-a');
    expect(job.status, BridgeIllustrationJobStatus.completed);
    expect(job.isRunning, isFalse);
    expect(job.pageCount, 6);
    expect(job.completedPageCount, 5);
    expect(job.failedPageCount, 1);
    expect(
      httpClient.requests.single.url.path,
      '/illustrations/jobs/illustration-job-1',
    );
  });

  test('a queued job still reports its place in line', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'illustration-job-1',
        'storyId': 'story-a',
        'status': 'queued',
        'pageCount': 6,
        'completedPageCount': 0,
        'failedPageCount': 0,
        'queuePosition': 3,
      });
    });

    final job = await pairedClient(
      httpClient,
    ).readIllustrationJob('illustration-job-1');

    expect(job.isRunning, isTrue);
    expect(job.queuePosition, 3);
  });

  test('cancelling one drawing job reports the state it ended in', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'illustration-job-1',
        'status': 'cancelled',
      });
    });

    final status = await pairedClient(
      httpClient,
    ).cancelIllustrationJob('illustration-job-1');

    expect(status, BridgeIllustrationJobStatus.cancelled);
    expect(
      httpClient.requests.single.url.path,
      '/illustrations/jobs/illustration-job-1/cancel',
    );
  });

  test('an image download carries its bytes and its ETag', () async {
    final png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 9, 9]);
    final httpClient = FakeBridgeHttpClient((request) async {
      return http.Response.bytes(
        png,
        200,
        headers: <String, String>{
          'content-type': 'image/png',
          'etag': '"page-1-v2"',
        },
      );
    });

    final download = await pairedClient(
      httpClient,
    ).downloadIllustration('illustration-1');

    expect(download.isUnchanged, isFalse);
    expect(download.bytes, png);
    expect(download.eTag, '"page-1-v2"');
    final sent = httpClient.requests.single;
    expect(sent.url.path, '/sync/illustrations/illustration-1');
    expect(sent.headers.containsKey('if-none-match'), isFalse);
  });

  test('a known ETag asks the PC and gets no bytes back', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      expect(request.headers['if-none-match'], '"page-1-v2"');
      return http.Response.bytes(Uint8List(0), 304);
    });

    final download = await pairedClient(
      httpClient,
    ).downloadIllustration('illustration-1', knownETag: '"page-1-v2"');

    expect(download.isUnchanged, isTrue);
    expect(download.bytes, isNull);
    expect(download.eTag, '"page-1-v2"', reason: 'the cached copy stays valid');
  });

  test('a picture the PC has not drawn yet is not a failure', () async {
    final client = pairedClient(
      FakeBridgeHttpClient((request) async {
        return bridgeErrorResponse('illustration_not_ready', 409);
      }),
    );

    await expectLater(
      client.downloadIllustration('illustration-1'),
      throwsA(_failure(BridgeFailure.illustrationNotReady)),
    );
  });

  test('a picture the PC does not have is told apart from that', () async {
    final client = pairedClient(
      FakeBridgeHttpClient((request) async {
        return bridgeErrorResponse('illustration_not_found', 404);
      }),
    );

    await expectLater(
      client.downloadIllustration('illustration-1'),
      throwsA(_failure(BridgeFailure.illustrationNotFound)),
    );
  });

  test('an unpaired device never sends a photo anywhere', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{});
    });
    final client = BridgeClient(httpClient: httpClient, baseUrl: baseUrl);

    await expectLater(
      client.uploadProfilePhoto(
        profileId: 'miko',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentType: bridgeJpegContentType,
      ),
      throwsA(_failure(BridgeFailure.notPaired)),
    );
    expect(httpClient.requests, isEmpty);
  });

  test('an answer that is not the agreed job shape is refused', () async {
    final client = pairedClient(
      FakeBridgeHttpClient((request) async {
        return bridgeJsonResponse(<String, Object>{
          'jobId': 'illustration-job-1',
          'storyId': 'story-a',
          'status': 'daydreaming',
          'pageCount': 6,
          'completedPageCount': 0,
          'failedPageCount': 0,
        });
      }),
    );

    await expectLater(
      client.readIllustrationJob('illustration-job-1'),
      throwsA(_failure(BridgeFailure.invalidResponse)),
    );
  });

  test('an empty image body is refused instead of cached', () async {
    final client = pairedClient(
      FakeBridgeHttpClient((request) async {
        return http.Response.bytes(
          Uint8List(0),
          200,
          headers: <String, String>{'content-type': 'image/png'},
        );
      }),
    );

    await expectLater(
      client.downloadIllustration('illustration-1'),
      throwsA(_failure(BridgeFailure.invalidResponse)),
    );
  });

  test('a photo body is never echoed into a diagnostic string', () async {
    final secret = utf8.encode('a child photo');
    final client = pairedClient(
      FakeBridgeHttpClient((request) async {
        return bridgeErrorResponse('photo_too_large', 413);
      }),
    );

    try {
      await client.uploadProfilePhoto(
        profileId: 'miko',
        bytes: Uint8List.fromList(secret),
        contentType: bridgeJpegContentType,
      );
      fail('the refused upload should have thrown');
    } on BridgeException catch (error) {
      expect(error.toString(), isNot(contains('child photo')));
      expect(
        error.toString(),
        'BridgeException(photoTooLarge, photo_too_large)',
      );
    }
  });
}

/// Matches one typed bridge failure regardless of its diagnostic code.
Matcher _failure(BridgeFailure failure) {
  return isA<BridgeException>().having(
    (error) => error.failure,
    'failure',
    failure,
  );
}
