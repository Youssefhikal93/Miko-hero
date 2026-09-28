import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/parent_gated_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the one sequence every parent-only story action now runs through.
///
/// The steps are stand-ins on purpose: deleting a story, making its pictures
/// and writing a story file differ only in what their steps do, so the order,
/// the gate and the outcome message are proved once here instead of once per
/// action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parentPin = '4729';
  final service = ParentSecurityService(deriver: _fakeDeriver);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('a refused gate never asks the parent to confirm anything', (
    tester,
  ) async {
    await _configurePin(service, parentPin);
    final action = _RecordedAction();
    await tester.pumpWidget(_app(service, action));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Parent area locked'), findsOneWidget);

    // Walking away from the PIN prompt is the refusal a parent gives most.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Confirm the action?'), findsNothing);
    expect(action.runs, 0);
    expect(action.stored, <String>['the moon garden']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a cancelled confirmation runs nothing and says nothing', (
    tester,
  ) async {
    final action = _RecordedAction();
    await tester.pumpWidget(_app(service, action));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm the action?'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(action.runs, 0);
    expect(action.stored, <String>['the moon garden']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a confirmed action reports the outcome it returns', (
    tester,
  ) async {
    final action = _RecordedAction();
    await tester.pumpWidget(_app(service, action));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(action.runs, 1);
    expect(action.stored, <String>['the moon garden', 'the sea garden']);
    expect(find.text('The action finished'), findsOneWidget);
  });

  testWidgets('a failed action reports it and leaves the data untouched', (
    tester,
  ) async {
    final action = _RecordedAction(fails: true);
    await tester.pumpWidget(_app(service, action));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(action.runs, 1);
    expect(action.stored, <String>['the moon garden']);
    expect(find.text('Something went wrong.'), findsOneWidget);
    expect(find.text('The action finished'), findsNothing);
  });
}

/// Builds one localized screen holding a single parent-gated action.
Widget _app(ParentSecurityService service, _RecordedAction action) {
  return ProviderScope(
    overrides: [parentSecurityServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _ActionScreen(action: action),
    ),
  );
}

/// Saves a verifier the way settings would, before the screen is first built.
Future<void> _configurePin(ParentSecurityService service, String pin) async {
  final repository = await LocalRepository.open();
  await repository.saveParentSecurity(await service.createRecord(pin));
}

/// A screen whose only control starts the shared parent-gated sequence.
class _ActionScreen extends ConsumerWidget {
  /// Creates the screen around one recorded action.
  const _ActionScreen({required this.action});

  /// The action whose steps this test inspects afterwards.
  final _RecordedAction action;

  @override
  /// Renders the single control that starts the sequence.
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => runParentGatedAction<bool, String>(
            context,
            ref,
            confirm: confirmedByDialog(
              (context) => AlertDialog(
                title: const Text('Confirm the action?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            ),
            run: (context, _) => action.run(),
            report: (text, outcome) => outcome,
          ),
          child: const Text('Start'),
        ),
      ),
    );
  }
}

/// Stands in for a controller command, remembering what was asked of it.
class _RecordedAction {
  /// Creates an action that either changes the stored data or refuses to.
  _RecordedAction({this.fails = false});

  /// Whether the action fails the way an offline PC or a full disk would.
  final bool fails;

  /// The data this action changes, kept so a failure can be shown not to.
  final List<String> stored = <String>['the moon garden'];

  /// How many times the action itself was reached.
  int runs = 0;

  /// Performs the action, or fails before touching anything.
  Future<String> run() async {
    runs++;
    if (fails) throw Exception('the action could not finish');
    stored.add('the sea garden');
    return 'The action finished';
  }
}

/// Stands in for Argon2id so this suite stays fast.
///
/// The real derivation is covered by `parent_security_service_test.dart`.
Future<Uint8List> _fakeDeriver(ParentPinDerivation derivation) async {
  final pinBytes = utf8.encode(derivation.pin);
  return Uint8List.fromList(
    List<int>.generate(
      parentSecurityHashLength,
      (index) =>
          (pinBytes[index % pinBytes.length] +
              derivation.salt[index % derivation.salt.length]) &
          0xFF,
    ),
  );
}
