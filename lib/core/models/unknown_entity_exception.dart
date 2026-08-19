/// Reports a command aimed at a profile, story, or job that no longer exists.
///
/// Deliberately an `Exception` and not an `Error`: a parent can reach these
/// states without a programming mistake, for example by retrying a request that
/// another screen already cancelled, so the calling surface is expected to
/// catch it and show recoverable feedback.
class UnknownEntityException implements Exception {
  /// Creates the error naming the kind of missing local entity.
  const UnknownEntityException(this.entity);

  /// Short, non-private description such as `story` or `generation job`.
  final String entity;

  /// Keeps diagnostics concise without exposing stored family content.
  @override
  String toString() => 'Unknown $entity.';
}
