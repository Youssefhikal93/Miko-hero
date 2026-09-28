import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';

import '../../support/seeded_device.dart';

/// Verifies what a reader sees while a story is being narrated to them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await seedDevice(
      profiles: <ChildProfile>[child()],
      stories: <StoryBook>[_story()],
      activeProfileId: 'miko',
    );
  });

  testWidgets('starting narration highlights the first spoken sentence', (
    tester,
  ) async {
    final voice = _FakeVoice();
    await _pumpReader(tester, voice);

    expect(_highlighted(tester), isNull);

    await tester.tap(find.byTooltip('Play narration'));
    await tester.pumpAndSettle();

    expect(_highlighted(tester), 'Miko woke up.');
    expect(find.byTooltip('Pause narration'), findsOneWidget);
    expect(find.byTooltip('Stop narration'), findsOneWidget);

    voice.finishUtterance();
    await tester.pumpAndSettle();

    expect(_highlighted(tester), 'The garden glowed.');
  });

  testWidgets('pausing keeps the sentence and resuming speaks it again', (
    tester,
  ) async {
    final voice = _FakeVoice();
    await _pumpReader(tester, voice);
    await tester.tap(find.byTooltip('Play narration'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pause narration'));
    await tester.pumpAndSettle();

    expect(_highlighted(tester), 'Miko woke up.');
    expect(find.byTooltip('Continue narration'), findsOneWidget);
    expect(voice.spokenText, <String>['Miko woke up.']);

    await tester.tap(find.byTooltip('Continue narration'));
    await tester.pumpAndSettle();

    expect(voice.spokenText, <String>['Miko woke up.', 'Miko woke up.']);
    expect(find.byTooltip('Pause narration'), findsOneWidget);
  });

  testWidgets('stopping clears the highlight and hides the stop control', (
    tester,
  ) async {
    final voice = _FakeVoice();
    await _pumpReader(tester, voice);
    await tester.tap(find.byTooltip('Play narration'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Stop narration'));
    await tester.pumpAndSettle();

    expect(_highlighted(tester), isNull);
    expect(find.byTooltip('Stop narration'), findsNothing);
    expect(find.byTooltip('Play narration'), findsOneWidget);
  });

  testWidgets('the narration dialog offers a sleep timer', (tester) async {
    final voice = _FakeVoice();
    await _pumpReader(tester, voice);

    await tester.tap(find.byTooltip('Sleep timer'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
  });
}

/// Opens the reader on the seeded story with a controllable device voice.
Future<void> _pumpReader(WidgetTester tester, _FakeVoice voice) {
  return pumpApp(
    tester,
    route: '/story/story-1',
    overrides: [narrationServiceProvider.overrideWithValue(voice)],
  );
}

/// Reads the sentence the reader is currently tinting, if any.
String? _highlighted(WidgetTester tester) {
  final prose = tester.widget<Text>(
    find.byKey(const ValueKey<String>('story-prose')),
  );
  String? highlighted;
  prose.textSpan?.visitChildren((span) {
    if (span is TextSpan && span.style?.backgroundColor != null) {
      highlighted = span.text;
      return false;
    }
    return true;
  });
  return highlighted;
}

/// One approved two-page book whose sentences are easy to assert on.
StoryBook _story() {
  return book(
    profileId: 'miko',
    pages: <StoryPage>[
      storyPage(1, 'Miko woke up. The garden glowed.'),
      storyPage(2, 'She ran outside. The stars sang.', scene: 'singing stars'),
    ],
  );
}

/// Device voice whose utterances complete only when the test says so.
class _FakeVoice implements NarrationService {
  /// Requests handed to the platform boundary, in the order they arrived.
  final spoken = <NarrationRequest>[];

  Completer<void>? _utterance;

  /// Text of every request, which is what sentence order is asserted on.
  List<String> get spokenText {
    return spoken.map((request) => request.text).toList(growable: false);
  }

  @override
  /// Reports an installed voice so the reader never shows the missing-voice notice.
  Future<bool> supports(AppLanguage language) async => true;

  @override
  /// Holds the utterance open until [finishUtterance] reports completion.
  Future<void> speak(NarrationRequest request) {
    spoken.add(request);
    final utterance = Completer<void>();
    _utterance = utterance;
    return utterance.future;
  }

  @override
  /// Accepts cancellation without completing the outstanding utterance.
  Future<void> stop() async {}

  /// Completes the pending utterance the way a real engine reports it.
  void finishUtterance() {
    final utterance = _utterance;
    _utterance = null;
    utterance?.complete();
  }
}
