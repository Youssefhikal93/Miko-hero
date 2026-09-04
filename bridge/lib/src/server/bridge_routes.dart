/// One HTTP route the bridge answers, exactly as the router registers it.
class BridgeRoute {
  /// Describes the route [method] [path], guarded by auth when [requiresAuth].
  const BridgeRoute({
    required this.method,
    required this.path,
    required this.requiresAuth,
  });

  /// Uppercase HTTP verb.
  final String method;

  /// `shelf_router` pattern; path parameters are written `<name>`.
  final String path;

  /// Whether the route sits behind the bearer-token middleware.
  ///
  /// Only `/health` and the two pairing endpoints answer without a token.
  final bool requiresAuth;

  /// `METHOD path` — the key a route's handler is looked up under.
  String get key => '$method $path';
}

/// Every route the bridge serves, in registration order.
///
/// This list is the single description of the bridge's HTTP surface.
/// `AppServer.buildHandler` builds both of its routers *from* it instead of
/// repeating it, and `test/postman_collection_test.dart` checks the committed
/// Postman collection against it — so a new endpoint that is not added here is
/// not served at all, and one added here without a Postman request fails the
/// suite. Neither the router nor the collection can quietly drift from the
/// other.
const List<BridgeRoute> bridgeRoutes = <BridgeRoute>[
  BridgeRoute(method: 'GET', path: '/health', requiresAuth: false),
  BridgeRoute(method: 'POST', path: '/pair/request', requiresAuth: false),
  BridgeRoute(method: 'POST', path: '/pair/confirm', requiresAuth: false),
  BridgeRoute(method: 'GET', path: '/devices', requiresAuth: true),
  BridgeRoute(
    method: 'DELETE',
    path: '/devices/<deviceId>',
    requiresAuth: true,
  ),
  BridgeRoute(method: 'POST', path: '/stories/generate', requiresAuth: true),
  BridgeRoute(method: 'GET', path: '/stories/jobs/<jobId>', requiresAuth: true),
  BridgeRoute(
    method: 'POST',
    path: '/stories/jobs/<jobId>/cancel',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'POST',
    path: '/stories/<storyId>/illustrate',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'GET',
    path: '/illustrations/jobs/<jobId>',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'POST',
    path: '/illustrations/jobs/<jobId>/cancel',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'PUT',
    path: '/profiles/<profileId>/photo',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'DELETE',
    path: '/profiles/<profileId>/photo',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'POST',
    path: '/stories/<storyId>/delete',
    requiresAuth: true,
  ),
  BridgeRoute(method: 'GET', path: '/sync/manifest', requiresAuth: true),
  BridgeRoute(
    method: 'GET',
    path: '/sync/stories/<storyId>',
    requiresAuth: true,
  ),
  BridgeRoute(
    method: 'GET',
    path: '/sync/illustrations/<illustrationId>',
    requiresAuth: true,
  ),
  BridgeRoute(method: 'POST', path: '/sync/complete', requiresAuth: true),
  BridgeRoute(method: 'POST', path: '/library/backup', requiresAuth: true),
  BridgeRoute(method: 'POST', path: '/library/restore', requiresAuth: true),
];
