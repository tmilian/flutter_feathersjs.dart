import 'dart:convert';

import 'package:flutter_feathersjs/src/storage/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DefaultTokenStorageImpl implements Storage {
  const DefaultTokenStorageImpl();

  static const String ACCESS_TOKEN = "ACCESS_TOKEN";
  static const String REFRESH_TOKEN = "REFRESH_TOKEN";
  static const String USER = "USER";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> setAccessToken({required String token}) async {
    await _storage.write(key: ACCESS_TOKEN, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: ACCESS_TOKEN);
  }

  Future<void> setRefreshToken({required String token}) async {
    await _storage.write(key: REFRESH_TOKEN, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: REFRESH_TOKEN);
  }

  @override
  Future<Map<String, dynamic>?> getUser() async {
    var user = await _storage.read(key: USER);
    return user != null ? jsonDecode(user) : null;
  }

  @override
  Future<void> setUser({required Map<String, dynamic> user}) async {
    await _storage.write(key: USER, value: jsonEncode(user));
  }
}
