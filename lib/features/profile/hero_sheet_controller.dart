import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

/// Supplies the three hero-sheet commands the profile editor needs.
final heroSheetControllerProvider = Provider<HeroSheetController>(
  HeroSheetController.new,
);

/// Reads and changes how the PC draws one child's hero.
///
/// The sheet lives on the PC and only on the PC — this device never stores a
/// copy, because a description of how one child looks has no reason to sit in
/// a phone's preferences waiting to be backed up somewhere. Every command here
/// is therefore a live call, and every one of them answers `null` when this
/// device is not paired: the editor hides the whole section in that case, and a
/// call that slipped through anyway must not raise at the parent.
class HeroSheetController {
  /// Retains the provider scope the connection and HTTP boundary come from.
  HeroSheetController(this._ref);

  final Ref _ref;

  /// Reads the sheet the PC keeps for [profileId].
  Future<BridgeHeroSheet?> readSheet(String profileId) async {
    final client = await _pairedClient();
    return client?.readHeroSheet(profileId);
  }

  /// Saves what [profileId]'s hero always wears and carries.
  ///
  /// Both values are sent together because both belong to the parent: sending
  /// only the one that changed would leave the PC guessing what the other
  /// means.
  Future<BridgeHeroSheet?> saveWardrobe({
    required String profileId,
    required String outfit,
    required String prop,
  }) async {
    final client = await _pairedClient();
    return client?.saveHeroSheetWardrobe(
      profileId: profileId,
      outfit: outfit,
      prop: prop,
    );
  }

  /// Asks the PC to read [profileId]'s reference photo again.
  Future<BridgeHeroSheet?> rereadFromPhoto(String profileId) async {
    final client = await _pairedClient();
    return client?.rereadHeroSheetFromPhoto(profileId);
  }

  /// A client for this device's pairing, or null while it holds no token.
  Future<BridgeClient?> _pairedClient() async {
    final connection = await _ref.read(aiConnectionControllerProvider.future);
    if (!connection.isPaired) return null;
    return bridgeClientFor(connection, _ref.read(bridgeHttpClientProvider));
  }
}
