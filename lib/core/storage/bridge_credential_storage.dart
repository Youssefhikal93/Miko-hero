import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the serialized bridge credential outside general app preferences.
abstract class BridgeCredentialStorage {
  /// Reads the serialized credential, or `null` when this device is unpaired.
  Future<String?> read();

  /// Replaces the serialized credential after a successful pairing.
  Future<void> write(String value);

  /// Deletes the serialized credential from this device.
  Future<void> delete();
}

/// Persists the bridge credential in the platform's protected storage.
class SecureBridgeCredentialStorage implements BridgeCredentialStorage {
  /// Creates a credential store backed by the platform plugin.
  const SecureBridgeCredentialStorage();

  static const _key = 'bridge_device';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// In-memory credential store for tests and other plugin-free environments.
class InMemoryBridgeCredentialStorage implements BridgeCredentialStorage {
  /// Creates a store that optionally starts with one serialized credential.
  InMemoryBridgeCredentialStorage({String? initialValue})
    : _value = initialValue;

  String? _value;

  /// Current serialized value, exposed for migration assertions.
  String? get value => _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> delete() async {
    _value = null;
  }
}
