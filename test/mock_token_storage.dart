import 'package:flutter_feathersjs/flutter_feathersjs.dart';

class MockTokenStorage implements Storage {
  String _accessToken = '';
  String _refreshToken = '';
  Map<String, dynamic> _user = {};

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> setAccessToken({required String token}) async =>
      _accessToken = token;

  @override
  Future<void> setRefreshToken({required String token}) async =>
      _refreshToken = token;

  @override
  Future<Map<String, dynamic>?> getUser() async => _user;

  @override
  Future<void> setUser({required Map<String, dynamic> user}) async =>
      _user = user;
}
