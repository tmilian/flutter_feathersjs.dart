import 'package:flutter_feathersjs/flutter_feathersjs.dart';
import 'dart:async';

import 'package:flutter_feathersjs/src/storage/default_token_storage_impl.dart';

class FlutterFeathersjs {
  RestClient rest;
  SocketioClient socketio;
  Storage tokenStorage;

  FlutterFeathersjs({
    required String baseUrl,
    Map<String, dynamic>? extraHeaders,
    this.tokenStorage = const DefaultTokenStorageImpl(),
  })  : rest = RestClient(
          baseUrl: baseUrl,
          extraHeaders: extraHeaders,
          tokenStorage: tokenStorage,
        ),
        socketio = SocketioClient(
          baseUrl: baseUrl,
          tokenStorage: tokenStorage,
        );

  Future<Map<String, dynamic>> authenticate({
    String strategy = "local",
    required String? username,
    required String? password,
    String usernameFieldName = "email",
  }) async {
    try {
      var restAuthResponse = await rest.authenticate(
          strategy: strategy,
          username: username,
          usernameFieldName: usernameFieldName,
          password: password);
      bool isAuthenticated = await socketio.authWithJWT();
      if (restAuthResponse != null && isAuthenticated == true) {
        return restAuthResponse;
      } else {
        throw new FeatherJsError(
          type: FeatherJsErrorType.AUTH_FAILED_ERROR,
          error: "Auth failed with unknown reason",
        );
      }
    } on FeatherJsError catch (e) {
      throw new FeatherJsError(type: e.type, error: e);
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      var restAuthResponse = await rest.refreshToken();
      var isAuthenticated = await socketio.authWithJWT();
      if (isAuthenticated) {
        return restAuthResponse;
      } else {
        throw new FeatherJsError(
            type: FeatherJsErrorType.AUTH_FAILED_ERROR,
            error: "Auth failed with unknown reason");
      }
    } on FeatherJsError catch (e) {
      throw new FeatherJsError(type: e.type, error: e);
    }
  }

  Future<dynamic> find({
    required String serviceName,
    required Map<String, dynamic> query,
  }) async {
    return this.socketio.find(
          serviceName: serviceName,
          query: query,
        );
  }

  Future<dynamic> create({
    required String serviceName,
    required Map<String, dynamic> data,
  }) {
    return this.socketio.create(
          serviceName: serviceName,
          data: data,
        );
  }

  Future<dynamic> update({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
  }) {
    return this.socketio.update(
          serviceName: serviceName,
          objectId: objectId,
          data: data,
        );
  }

  Future<dynamic> get({
    required String serviceName,
    required String objectId,
  }) {
    return this.socketio.get(
          serviceName: serviceName,
          objectId: objectId,
        );
  }

  Future<dynamic> patch({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
  }) {
    return this.socketio.patch(
          serviceName: serviceName,
          objectId: objectId,
          data: data,
        );
  }

  Future<dynamic> remove({
    required String serviceName,
    required String objectId,
  }) {
    return this.socketio.remove(
          serviceName: serviceName,
          objectId: objectId,
        );
  }

  Stream<FeathersJsEventData<T>> listen<T>(
      {required String serviceName, required Function fromJson}) {
    return this.socketio.listen(serviceName: serviceName, fromJson: fromJson);
  }
}
