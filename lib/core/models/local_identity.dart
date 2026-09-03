/// Builds a collision-free identity for one locally created entity.
///
/// Device-local on purpose: profiles and queued requests are created offline
/// and never coordinate with another machine, so a UTC microsecond stamp under
/// a per-kind prefix is enough. The taken identities are still checked, because
/// two saves inside the same microsecond are possible on a fast device and a
/// duplicate identity would fail snapshot validation rather than merely look
/// odd. Shared by child profiles and generation jobs so both kinds are shaped
/// the same way and neither can drift into its own scheme.
String newLocalId({
  required String prefix,
  required DateTime createdAt,
  required Iterable<String> takenIds,
}) {
  final baseId = '$prefix-${createdAt.toUtc().microsecondsSinceEpoch}';
  final taken = takenIds.toSet();
  var candidateId = baseId;
  var suffix = 1;
  while (taken.contains(candidateId)) {
    candidateId = '$baseId-${suffix++}';
  }
  return candidateId;
}
