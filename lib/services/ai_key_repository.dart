import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiKeyRepository {
  const AiKeyRepository(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> readKey() => _storage.read(key: _kAiApiKey);

  Future<void> writeKey(String value) => _storage.write(key: _kAiApiKey, value: value);

  Future<void> deleteKey() => _storage.delete(key: _kAiApiKey);
}

const _kAiApiKey = 'aiApiKey';

