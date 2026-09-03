import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Keeps the credential in the browser's preference store on the web.
///
/// The web build has no protected storage: the platform plugin encrypts the
/// value with a key it keeps in the same `localStorage`, so it adds no secrecy
/// while depending on a secure context and WebCrypto. In a release bundle that
/// dependency failed silently and left the AI connection state unresolved,
/// which disabled story creation. Plain preferences are honest about what a
/// browser can protect and always answer.
class PreferencesBridgeCredentialStorage implements BridgeCredentialStorage {
  /// Creates a store backed by the shared preferences instance.
  const PreferencesBridgeCredentialStorage();

  /// Distinct from the legacy plaintext key so the one-time migration in the
  /// repository still knows an old value from a current one.
  static const _key = 'bridge_device_store';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }

  @override
  Future<void> delete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
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
