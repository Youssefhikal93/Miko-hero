import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';

/// Asks the family PC how one child's name is written in each language.
///
/// A thin seam over the bridge client so the editor never builds one itself,
/// and so a widget test can answer without a socket. Returns the four
/// spellings, or throws a [BridgeException] the section turns into one line.
typedef NameSpellingSuggester =
    Future<Map<AppLanguage, String>> Function({
      required String heroName,
      String? genderContext,
    });

/// Supplies the suggester bound to whatever bridge this device is paired with.
///
/// Throws [BridgeFailure.notPaired] when there is no PC and no token, which is
/// the same refusal every other bridge call makes — the section never has to
/// decide what "paired" means, it only has to show the answer.
final nameSpellingSuggesterProvider = Provider<NameSpellingSuggester>((ref) {
  return ({required String heroName, String? genderContext}) async {
    final connection = ref.read(aiConnectionControllerProvider).value;
    if (connection == null || !connection.isPaired) {
      throw const BridgeException(BridgeFailure.notPaired);
    }
    final client = bridgeClientFor(
      connection,
      ref.read(bridgeHttpClientProvider),
    );
    return client.suggestNameSpellings(
      heroName: heroName,
      genderContext: genderContext,
    );
  };
});

/// One box per story language, and a way to have the PC fill them in.
///
/// Self-contained on purpose: it owns its four controllers, publishes the
/// current values through [onChanged], and knows nothing about how the profile
/// is saved. The parent may always type the spellings — the PC is a
/// convenience, and a family with no PC loses nothing but the typing.
class NameSpellingsSection extends ConsumerStatefulWidget {
  /// Creates the section over the editor's current unsaved values.
  const NameSpellingsSection({
    required this.heroName,
    required this.gender,
    required this.spellings,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  /// Name currently typed in the editor, which is what gets spelled.
  final String heroName;

  /// Girl/Boy choice so far, refining the suggestion when one is made.
  final ChildGender? gender;

  /// Spellings the editor holds right now; seeds the boxes once.
  final Map<AppLanguage, String> spellings;

  /// Whether the form is accepting input at all.
  final bool enabled;

  /// Publishes every edit back to the editor, blanks included.
  final ValueChanged<Map<AppLanguage, String>> onChanged;

  @override
  ConsumerState<NameSpellingsSection> createState() =>
      _NameSpellingsSectionState();
}

class _NameSpellingsSectionState extends ConsumerState<NameSpellingsSection> {
  late final Map<AppLanguage, TextEditingController> _controllers;
  bool _asking = false;
  bool _askedOnce = false;

  @override
  void initState() {
    super.initState();
    _controllers = <AppLanguage, TextEditingController>{
      for (final language in AppLanguage.values)
        language: TextEditingController(text: widget.spellings[language] ?? ''),
    };
    // A profile opened with no spellings asks the PC once, by itself: the
    // parent should not have to know this feature exists to benefit from it.
    // Silently, because a PC that is off is not something to interrupt an edit
    // over — the boxes simply stay empty and typable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.spellings.isNotEmpty) return;
      _suggest(silently: true);
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final heroName = widget.heroName.trim();
    final paired =
        ref.watch(aiConnectionControllerProvider).value?.isPaired ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.nameSpellingsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              text.nameSpellingsBody(
                heroName.isEmpty ? text.childName : heroName,
              ),
            ),
            const SizedBox(height: 16),
            for (final language in AppLanguage.values) ...<Widget>[
              TextFormField(
                key: ValueKey<String>('name-spelling-${language.code}'),
                controller: _controllers[language],
                enabled: widget.enabled,
                // The box is read in the language it is for, so an Arabic
                // spelling is typed and shown right to left even while the
                // interface around it is English.
                textDirection: language.usesLatinScript
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: _languageName(text, language),
                  hintText: text.nameSpellingsHint,
                ),
                validator: _validateSpelling,
                onChanged: (_) => _publish(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('suggest-name-spellings'),
                  onPressed: widget.enabled && paired && !_asking
                      ? _suggest
                      : null,
                  icon: _asking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.suggest),
                  label: Text(text.suggestNameSpellings),
                ),
                const SizedBox(width: 12),
                if (_asking || !paired)
                  Expanded(
                    child: Text(
                      _asking
                          ? text.nameSpellingsSuggesting
                          : text.nameSpellingsNeedPc,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Refuses a value no profile could store, in the parent's own words.
  String? _validateSpelling(String? value) {
    if (value != null && value.trim().length > maximumChildNameSpellingLength) {
      return AppLocalizations.of(context).nameSpellingTooLong;
    }
    return null;
  }

  /// Hands the editor everything typed so far, blanks included.
  ///
  /// Blanks travel on purpose: clearing a box is how a parent says "use the
  /// name as I typed it", and the storage boundary is what drops them.
  void _publish() {
    widget.onChanged(<AppLanguage, String>{
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    });
  }

  /// Fills every box from the PC, or says in one line why it could not.
  ///
  /// Never partial: the bridge answers with four spellings or with a failure,
  /// so the parent is never left checking two boxes and typing two others
  /// without knowing which is which.
  /// [silently] is the automatic ask made when the editor opens with no
  /// spellings saved: it asks once and says nothing either way, so an absent
  /// PC never interrupts an edit the parent came here to make.
  Future<void> _suggest({bool silently = false}) async {
    if (_asking || (silently && _askedOnce)) return;
    final text = AppLocalizations.of(context);
    final heroName = widget.heroName.trim();
    if (heroName.isEmpty) {
      if (!silently) _report(text.nameSpellingsNeedName);
      return;
    }
    _askedOnce = true;
    setState(() => _asking = true);
    try {
      final suggested = await ref.read(nameSpellingSuggesterProvider)(
        heroName: heroName,
        genderContext: widget.gender?.isSpecified == true
            ? widget.gender!.name
            : null,
      );
      if (!mounted) return;
      for (final entry in suggested.entries) {
        _controllers[entry.key]?.text = entry.value;
      }
      _publish();
      setState(() => _asking = false);
      if (!silently) _report(text.nameSpellingsSuggested);
    } on BridgeException {
      if (!mounted) return;
      setState(() => _asking = false);
      if (!silently) _report(text.nameSpellingsSuggestFailed);
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The label of one language, in the interface's own words.
  String _languageName(AppLocalizations text, AppLanguage language) {
    return switch (language) {
      AppLanguage.english => text.english,
      AppLanguage.arabic => text.arabic,
      AppLanguage.swedish => text.swedish,
      AppLanguage.somali => text.somali,
    };
  }
}
