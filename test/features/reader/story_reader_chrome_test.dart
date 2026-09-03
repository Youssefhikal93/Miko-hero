import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

import '../../support/seeded_device.dart';

/// Verifies the reader chrome a child reads the book through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Three pages, so a middle page has a dot on both sides.
    await seedDevice(
      profiles: <ChildProfile>[child()],
      stories: <StoryBook>[book(profileId: 'miko', pageCount: 3)],
      activeProfileId: 'miko',
    );
  });

  testWidgets('turning a page with the button moves the counter and the dot', (
    tester,
  ) async {
    await pumpApp(tester, route: '/story/story-1');

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(_openDot(0), findsOneWidget);
    expect(_openDot(1), findsNothing);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(_openDot(1), findsOneWidget);
    expect(_openDot(0), findsNothing);

    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(_openDot(0), findsOneWidget);
  });

  testWidgets('swiping the book moves the counter and the dot', (tester) async {
    await pumpApp(tester, route: '/story/story-1');

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(_openDot(1), findsOneWidget);
  });

  testWidgets('the reader offers its top row and its tool row', (tester) async {
    await pumpApp(tester, route: '/story/story-1');

    expect(find.text('Read to me'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Bedtime mode'), findsOneWidget);
    expect(find.byTooltip('Reading speed'), findsOneWidget);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    expect(find.byTooltip('Text size'), findsOneWidget);
    expect(find.byTooltip('Save PDF'), findsOneWidget);
  });

  testWidgets('the text size icon opens the hero saved prose size', (
    tester,
  ) async {
    await pumpApp(tester, route: '/story/story-1');

    await tester.tap(find.byTooltip('Text size'));
    await tester.pumpAndSettle();

    expect(_sizeSelected(tester, 'medium'), isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('reader-prose-size-large')),
    );
    await tester.pumpAndSettle();

    expect(_sizeSelected(tester, 'large'), isTrue);
    expect(_sizeSelected(tester, 'medium'), isFalse);
  });
}

/// The dot marking the page that is currently open.
Finder _openDot(int index) {
  return find.byKey(ValueKey<String>('page-dot-$index'));
}

/// Reports whether one prose size currently shows as selected.
bool _sizeSelected(WidgetTester tester, String size) {
  return tester
      .widget<ChoiceChip>(
        find.byKey(ValueKey<String>('reader-prose-size-$size')),
      )
      .selected;
}
