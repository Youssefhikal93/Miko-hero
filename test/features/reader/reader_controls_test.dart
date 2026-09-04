import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/features/reader/narration_controller.dart';
import 'package:miko_hero/features/reader/reader_controls.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/hero_face.dart';

import '../../support/seeded_device.dart';

/// Verifies the reader's chrome as the value round-trip it is.
///
/// Nothing here builds a reader, a story, or a seeded device: the rows are
/// handed a [ReaderStatus] and a [ReaderActions] and then driven, so what they
/// draw and which callback they call is the whole of what they do.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('position', () {
    testWidgets('the counter and the open dot follow the page index', (
      tester,
    ) async {
      await _pumpControls(tester, status: _status(pageIndex: 1, pageCount: 3));

      expect(find.text('Page 2 of 3'), findsOneWidget);
      expect(_openDot(1), findsOneWidget);
      expect(_openDot(0), findsNothing);
      expect(_openDot(2), findsNothing);
    });

    testWidgets('the first page cannot be turned back from', (tester) async {
      await _pumpControls(
        tester,
        actions: _actions(
          navigation: const ReaderNavigation(previous: null, next: _ignore),
        ),
      );

      expect(_enabled(tester, 'Previous'), isFalse);
      expect(_enabled(tester, 'Next'), isTrue);
    });

    testWidgets('the last page cannot be turned on from', (tester) async {
      await _pumpControls(
        tester,
        status: _status(pageIndex: 2),
        actions: _actions(
          navigation: const ReaderNavigation(previous: _ignore, next: null),
        ),
      );

      expect(_enabled(tester, 'Next'), isFalse);
      expect(_enabled(tester, 'Previous'), isTrue);
    });

    testWidgets('a page turn calls only the direction it was asked for', (
      tester,
    ) async {
      final called = <String>[];
      await _pumpControls(
        tester,
        actions: _actions(
          navigation: ReaderNavigation(
            previous: () => called.add('previous'),
            next: () => called.add('next'),
          ),
        ),
      );

      await _tap(tester, find.byTooltip('Next'));
      await _tap(tester, find.byTooltip('Previous'));

      expect(called, <String>['next', 'previous']);
    });
  });

  group('narration', () {
    testWidgets('a silent book invites the child to listen', (tester) async {
      await _pumpControls(tester);

      expect(find.text('Read to me'), findsOneWidget);
      expect(find.byTooltip('Play narration'), findsOneWidget);
      expect(find.byTooltip('Stop narration'), findsNothing);
    });

    testWidgets('a book being read offers pause and stop', (tester) async {
      await _pumpControls(
        tester,
        status: _status(playback: NarrationPlayback.playing),
      );

      expect(find.text('Pause narration'), findsOneWidget);
      expect(find.byTooltip('Stop narration'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('a paused book offers to continue and still to stop', (
      tester,
    ) async {
      await _pumpControls(
        tester,
        status: _status(playback: NarrationPlayback.paused),
      );

      expect(find.text('Continue narration'), findsOneWidget);
      expect(find.byTooltip('Stop narration'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('the read control and the stop control are separate commands', (
      tester,
    ) async {
      final called = <String>[];
      await _pumpControls(
        tester,
        status: _status(playback: NarrationPlayback.playing),
        actions: _actions(
          narration: () => called.add('narration'),
          stopNarration: () => called.add('stop'),
        ),
      );

      await _tap(tester, find.text('Pause narration'));
      await _tap(tester, find.byTooltip('Stop narration'));

      expect(called, <String>['narration', 'stop']);
    });

    testWidgets('speed and sleep timer both open the one narration dialog', (
      tester,
    ) async {
      var opened = 0;
      await _pumpControls(
        tester,
        actions: _actions(narrationSettings: () => opened++),
      );

      await _tap(tester, find.byTooltip('Reading speed'));
      await _tap(tester, find.byTooltip('Sleep timer'));

      expect(opened, 2);
    });
  });

  group('tools', () {
    testWidgets('the prose size opens for a hero who still has a profile', (
      tester,
    ) async {
      var opened = 0;
      await _pumpControls(tester, actions: _actions(textSize: () => opened++));

      await _tap(tester, find.byTooltip('Text size'));

      expect(opened, 1);
    });

    testWidgets('a story whose hero is gone cannot change the prose size', (
      tester,
    ) async {
      await _pumpControls(tester, actions: _actions(textSize: null));

      expect(_enabled(tester, 'Text size'), isFalse);
    });

    testWidgets('the PDF can be asked for while none is being written', (
      tester,
    ) async {
      var exported = 0;
      await _pumpControls(tester, actions: _actions(export: () => exported++));

      await _tap(tester, find.byTooltip('Save PDF'));

      expect(exported, 1);
    });

    testWidgets('a PDF being written cannot be asked for again', (
      tester,
    ) async {
      await _pumpControls(tester, status: _status(exporting: true));

      expect(_enabled(tester, 'Creating PDF…'), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Save PDF'), findsNothing);
    });
  });

  group('top row', () {
    testWidgets('the hero, the exit, and the bedtime toggle are offered', (
      tester,
    ) async {
      await _pumpTopRow(tester);

      expect(find.byType(HeroFace), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Bedtime mode'), findsOneWidget);
    });

    testWidgets('a bedtime session offers to turn itself off', (tester) async {
      await _pumpTopRow(tester, bedtime: true);

      expect(find.byTooltip('Turn off bedtime mode'), findsOneWidget);
      expect(find.byTooltip('Bedtime mode'), findsNothing);
    });

    testWidgets('a story whose hero is gone still draws its row', (
      tester,
    ) async {
      await _pumpTopRow(tester, heroless: true);

      expect(find.byType(HeroFace), findsNothing);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('the exit and the toggle are separate commands', (
      tester,
    ) async {
      final called = <String>[];
      await _pumpTopRow(
        tester,
        onClose: () => called.add('close'),
        onBedtime: () => called.add('bedtime'),
      );

      await _tap(tester, find.byTooltip('Close'));
      await _tap(tester, find.byTooltip('Bedtime mode'));

      expect(called, <String>['close', 'bedtime']);
    });
  });
}

/// Where the child is in the book, defaulting to the first page of a silent one.
ReaderStatus _status({
  int pageIndex = 0,
  int pageCount = 3,
  NarrationPlayback playback = NarrationPlayback.idle,
  bool exporting = false,
}) {
  return ReaderStatus(
    pageIndex: pageIndex,
    pageCount: pageCount,
    playback: playback,
    exporting: exporting,
  );
}

/// What may be done to the open book, defaulting to every command allowed.
ReaderActions _actions({
  ReaderNavigation navigation = const ReaderNavigation(
    previous: _ignore,
    next: _ignore,
  ),
  VoidCallback narration = _ignore,
  VoidCallback stopNarration = _ignore,
  VoidCallback narrationSettings = _ignore,
  VoidCallback? textSize = _ignore,
  VoidCallback export = _ignore,
}) {
  return ReaderActions(
    navigation: navigation,
    narration: narration,
    stopNarration: stopNarration,
    narrationSettings: narrationSettings,
    textSize: textSize,
    export: export,
  );
}

/// A command a test is not watching, which still has to be offered.
void _ignore() {}

/// Draws the control bar alone, with nothing else on screen to tap.
Future<void> _pumpControls(
  WidgetTester tester, {
  ReaderStatus? status,
  ReaderActions? actions,
}) {
  return _pumpChrome(
    tester,
    ReaderControls(status: status ?? _status(), actions: actions ?? _actions()),
  );
}

/// Draws the top row alone, for the hero whose book is open.
Future<void> _pumpTopRow(
  WidgetTester tester, {
  bool heroless = false,
  bool bedtime = false,
  VoidCallback onClose = _ignore,
  VoidCallback onBedtime = _ignore,
}) {
  return _pumpChrome(
    tester,
    ReaderTopRow(
      profile: heroless ? null : child(),
      bedtime: bedtime,
      onClose: onClose,
      onBedtime: onBedtime,
    ),
  );
}

/// Hosts one row of reader chrome inside a bare localized application.
Future<void> _pumpChrome(WidgetTester tester, Widget chrome) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Column(children: <Widget>[chrome])),
    ),
  );
  // A single frame, never a settle: the export spinner turns for as long as a
  // PDF is being written, so a settled chrome could never include one.
  await tester.pump();
}

/// Presses one control and lets the frame it caused settle.
Future<void> _tap(WidgetTester tester, Finder control) async {
  await tester.tap(control);
  await tester.pump();
}

/// The dot marking the page that is currently open.
Finder _openDot(int index) {
  return find.byKey(ValueKey<String>('page-dot-$index'));
}

/// Reports whether the control behind one tooltip can still be pressed.
bool _enabled(WidgetTester tester, String tooltip) {
  final button = find.ancestor(
    of: find.byTooltip(tooltip),
    matching: find.byType(IconButton),
  );
  return tester.widget<IconButton>(button).onPressed != null;
}
