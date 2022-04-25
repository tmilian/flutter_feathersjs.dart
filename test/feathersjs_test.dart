import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_feathersjs/flutter_feathersjs.dart';

import 'fixtures.dart';
import 'mock_token_storage.dart';

var tokenStorage = MockTokenStorage();
FlutterFeathersjs flutterFeathersjs = FlutterFeathersjs(
  baseUrl: BASE_URL,
  tokenStorage: tokenStorage,
);

void main() async {
  test('Authenticate user', () async {
    try {
      var response = await flutterFeathersjs.authenticate(
        userName: user["email"],
        password: user["password"],
      );
      print(response);
      expect(response['accessToken'], await tokenStorage.getAccessToken());
    } catch (e) {
      print(e);
    }
  });

  test('Refresh token', () async {
    try {
      var response = await flutterFeathersjs.rest.refreshToken();
      print(response);
      expect(response['refreshToken'], await tokenStorage.getRefreshToken());
    } catch (e) {
      print(e);
    }
  });

  test('User service via Socket', () async {
    try {
      var user = await tokenStorage.getUser();
      var response = await flutterFeathersjs.socketio.get(
        serviceName: 'users',
        objectId: user?['_id'],
      );
      print(response);
      expect(response['_id'], user?['_id']);
    } catch (e) {
      print(e);
    }
  });

  test('User service via Rest', () async {
    try {
      var user = await tokenStorage.getUser();
      var response = await flutterFeathersjs.rest.get(
        serviceName: 'users',
        objectId: user?['_id'],
      );
      print(response);
      expect(response['_id'], user?['_id']);
    } catch (e) {
      print(e);
    }
  });
}
