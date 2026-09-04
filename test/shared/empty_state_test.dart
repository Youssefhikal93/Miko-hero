import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/empty_state.dart';

/// Verifies the one shape every screen with nothing on it now takes.
///
/// The seven columns this replaced are asserted where they are used — the
/// shelf, Home, My Kingdom, the review queue, the profile list and the two
/// error panels each prove their own copy reaches the screen. What is proved
/// here is the shape itself: that the glyph, the line, the optional sentence
/// and the optional way out appear in that order and only when they were
/// given, and that a caller's key still names the state it wraps.
void main() {
  testWidgets('a full state draws the glyph, the line, the body and the way '
      'out, in that order', (tester) async {
    await _pumpState(
      tester,
      const EmptyState(
        icon: AppIcons.stories,
        title: 'The bookshelf is waiting',
        body: 'Create a first adventure and it will appear here.',
        action: Text('Create a story'),
      ),
    );

    expect(find.byIcon(AppIcons.stories), findsOneWidget);
    expect(find.text('The bookshelf is waiting'), findsOneWidget);
    expect(
      find.text('Create a first adventure and it will appear here.'),
      findsOneWidget,
    );
    expect(find.text('Create a story'), findsOneWidget);
    expect(
      _topOf(tester, find.byIcon(AppIcons.stories)),
      lessThan(_topOf(tester, find.text('The bookshelf is waiting'))),
    );
    expect(
      _topOf(tester, find.text('The bookshelf is waiting')),
      lessThan(
        _topOf(
          tester,
          find.text('Create a first adventure and it will appear here.'),
        ),
      ),
    );
    expect(
      _topOf(
        tester,
        find.text('Create a first adventure and it will appear here.'),
      ),
      lessThan(_topOf(tester, find.text('Create a story'))),
    );
  });

  testWidgets('a state with one sentence is a glyph and that sentence', (
    tester,
  ) async {
    await _pumpState(
      tester,
      const EmptyState(
        icon: AppIcons.search,
        title: 'No title on this shelf matches that search.',
      ),
    );

    expect(find.byIcon(AppIcons.search), findsOneWidget);
    expect(
      find.text('No title on this shelf matches that search.'),
      findsOneWidget,
    );
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets(
    'the line is set in the title slot and the body under it is not',
    (tester) async {
      await _pumpState(
        tester,
        const EmptyState(
          icon: AppIcons.error,
          title: 'Something went wrong.',
          body: 'Try again in a moment.',
        ),
      );

      final theme = Theme.of(tester.element(find.byType(EmptyState)));
      expect(
        tester.widget<Text>(find.text('Something went wrong.')).style,
        theme.textTheme.titleLarge,
      );
      expect(
        tester.widget<Text>(find.text('Try again in a moment.')).style,
        isNull,
        reason: 'the body keeps the surrounding body style',
      );
    },
  );

  testWidgets('a body given without an action leaves no room for one', (
    tester,
  ) async {
    await _pumpState(
      tester,
      const EmptyState(
        icon: AppIcons.factCheck,
        title: 'No stories are waiting for review.',
        body: 'Every draft has been decided.',
      ),
    );

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(Text), findsNWidgets(2));
  });

  testWidgets('a caller can key the state so its own tests can find it', (
    tester,
  ) async {
    await _pumpState(
      tester,
      const EmptyState(
        key: ValueKey<String>('empty-shelf'),
        icon: AppIcons.stories,
        title: 'The bookshelf is waiting',
      ),
    );

    expect(find.byKey(const ValueKey<String>('empty-shelf')), findsOneWidget);
  });
}

/// Places one empty state on a plain themed surface.
Future<void> _pumpState(WidgetTester tester, EmptyState state) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: state)),
    ),
  );
  await tester.pump();
}

/// Where one part of the state sits vertically on the surface.
double _topOf(WidgetTester tester, Finder finder) {
  return tester.getTopLeft(finder).dy;
}
