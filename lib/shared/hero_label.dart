import 'package:flutter/widgets.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// How a child's name is written on the screen that is asking.
///
/// The whole point of the per-language spellings is that a name is one name
/// written several ways: Malika reads مليكة in an Arabic interface and Malika
/// in the other three. Every localized surface that puts a child's name in
/// front of a reader goes through here, so none of them has to know that the
/// interface language and the profile's spellings ever met.
///
/// The parent's own profile editor is deliberately *not* one of those surfaces:
/// there the entered name is the thing being edited, and showing it spelled
/// another way would hide what the parent typed.
extension HeroLabel on BuildContext {
  /// The language this screen is currently drawn in.
  AppLanguage get interfaceLanguage =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);

  /// [profile]'s name as this screen's language writes it.
  String heroDisplayName(ChildProfile profile) =>
      profile.nameIn(interfaceLanguage);

  /// [profile]'s personalized hero label in this screen's language.
  String heroDisplayLabel(ChildProfile profile) =>
      profile.heroNameIn(interfaceLanguage);
}
