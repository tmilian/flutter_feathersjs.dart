import 'dart:async';

import 'package:flutter/foundation.dart' as Foundation;
import 'package:flutter_feathersjs/flutter_feathersjs.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:event_bus/event_bus.dart';

///Socketio client for the realtime communication
class SocketioClient {
  IO.Socket _socket;
  Storage tokenStorage;
  EventBus eventBus = EventBus(sync: true);

  SocketioClient({
    required String baseUrl,
    required this.tokenStorage,
  }) : _socket = IO.io(baseUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect':
              true, // Socketio will reconnect automatically when connection is lost
        }) {
    _socket.on('connect', (_) {
      eventBus.fire(Connected());
    });

    _socket.on('disconnect', (_) {
      eventBus.fire(DisConnected());
    });

    // Only print these when in debug mode, disable in release mode
    if (!Foundation.kReleaseMode) {
      _socket.on('connect', (_) {
        print("Socket connection established");
      });

      _socket.on('connect_error', (e) {
        print("Connection error");
        print(e);
      });

      _socket.on('connect_timeout', (data) {
        print("Timeout error");
        print(data);
      });

      _socket.on('connecting', (_) => print("Connecting..."));
      _socket.on('disconnect', (_) {});

      _socket.on('error', (e) {
        print("____An error occured____");
        print(e);
      });

      _socket.on('reconnect', (_) => print("Reconnected"));
      _socket.on('reconnect_error', (_) => print("Reconnection error..."));
      _socket.on(
          'reconnect_attempt', (_) => print("Attempting a reconnection"));
      _socket.on('reconnect_failed', (_) => print("A reconnection failed"));
      _socket.on('reconnecting', (_) => print("Reconnecting..."));
    }
  }

  ///
  /// Authenticate the user with realtime connection
  ///
  /// @Warning This function must be call afther auth with rest is OK
  ///
  /// Otherwise, you cannot be able to use socketio client because it won't be authed on the server
  ///
  /// @Warning: You don't need to use this directly in your code,
  /// use instead the global `flutterFeathersjs.authenticate({...})`
  ///
  Future<dynamic> authWithJWT() async {
    String? token = await tokenStorage.getAccessToken();
    Completer asyncTask = Completer<dynamic>();
    FeatherJsError? featherJsError;
    bool authenticated = false;
    _socket.emitWithAck('create', [
      'authentication',
      <String, dynamic>{
        'strategy': 'jwt',
        'accessToken': token,
      }
    ], ack: (dataResponse) {
      if (dataResponse is List) {
        authenticated = true;
        this._socket.io.options['extraHeaders'] = {
          'Authorization': "Bearer $token"
        };
      } else {
        featherJsError = FeatherJsError(
          type: FeatherJsErrorType.JWT_TOKEN_ERROR,
          error: dataResponse,
        );
      }
      if (featherJsError != null) {
        asyncTask.completeError(featherJsError!);
      } else {
        asyncTask.complete(authenticated);
      }
    });
    return asyncTask.future;
  }

  /// `EMIT find serviceName`
  ///
  /// Retrieves a list of all matching `query` resources from the service
  ///
  /// If no error is occured, you will get exactly feathersjs's data format
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised
  ///
  /// Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  ///
  Future<dynamic> find({
    required String serviceName,
    required Map<String, dynamic> query,
  }) async {
    Completer<dynamic> asyncTask = Completer<dynamic>();
    _socket.emitWithAck("find", [serviceName, query], ack: (response) {
      if (response is List) {
        asyncTask.complete(response[1]);
      } else {
        asyncTask.completeError(errorCode2FeatherJsError(response));
      }
    });
    return asyncTask.future;
  }

  /// `EMIT create serviceName`
  ///
  /// Create new ressource
  ///
  /// If no error is occured, you will get exactly feathersjs's data format
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised
  ///
  /// Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  Future<dynamic> create({
    required String serviceName,
    required Map<String, dynamic> data,
  }) {
    Completer<dynamic> asyncTask = Completer<dynamic>();
    _socket.emitWithAck("create", [serviceName, data], ack: (response) {
      if (response is List) {
        asyncTask.complete(response[1]);
      } else {
        asyncTask.completeError(errorCode2FeatherJsError(response));
      }
    });
    return asyncTask.future;
  }

  /// `EMIT update serviceName`
  ///
  /// Update a  ressource
  ///
  ///
  /// If no error is occured, you will get exactly feathersjs's data format
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised
  ///
  /// Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  Future<dynamic> update({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
  }) {
    Completer<dynamic> asyncTask = Completer<dynamic>();
    _socket.emitWithAck("update", [serviceName, objectId, data],
        ack: (response) {
      if (response is List) {
        asyncTask.complete(response[1]);
      } else {
        asyncTask.completeError(errorCode2FeatherJsError(response));
      }
    });
    return asyncTask.future;
  }

  /// `EMIT get serviceName`
  ///
  ///
  /// If no error is occured, you will get exactly feathersjs's data format
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised
  ///
  /// Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  Future<dynamic> get({
    required String serviceName,
    required String objectId,
  }) {
    Completer<dynamic> asyncTask = Completer<dynamic>();
    _socket.emitWithAck("get", [serviceName, objectId], ack: (response) {
      if (response is List) {
        asyncTask.complete(response[1]);
      } else {
        asyncTask.completeError(errorCode2FeatherJsError(response));
      }
    });
    return asyncTask.future;
  }

  /// `EMIT patch serviceName`
  ///
  /// Merge the existing data of a single or multiple resources with the new data
  ///
  /// If no error is occured, you will get exactly feathersjs's data format
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised
  ///
  /// Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  Future<dynamic> patch({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
  }) {
    Completer<dynamic> asyncTask = Completer<dynamic>();
    _socket.emitWithAck("patch", [serviceName, objectId, data],
        ack: (response) {
      if (response is List) {
        asyncTask.complete(response[1]);
      } else {
        asyncTask.completeError(errorCode2FeatherJsError(response));
      }
    });
    return asyncTask.future;
  }

  /// `EMIT remove serviceName`
  ///
  /// Delete a ressource on the server
  ///
  ///
  /// If no error is occured, you will get exactly feathersjs's data format
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised
  ///
  /// Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  Future<dynamic> remove({
    required String serviceName,
    required String objectId,
  }) {
    Completer<dynamic> asyncTask = Completer<dynamic>();
    _socket.emitWithAck("remove", [serviceName, objectId], ack: (response) {
      if (response is List) {
        asyncTask.complete(response[1]);
      } else {
        asyncTask.completeError(errorCode2FeatherJsError(response));
      }
    });
    return asyncTask.future;
  }

  /// Listen to On [` updated | patched | created | removed `] `serviceName`
  ///
  /// If no error is occured, you will get FeathersJsEventData<T>  feathersJsEventData
  ///
  ///     Then to retrieve the data send by feathers, do: feathersJsEventData.data
  ///
  ///     Event type send by feathers: feathersJsEventData.type
  ///
  /// Note: T is class that represent what feather js will send. You have to define it in your code
  ///
  ///
  /// Otherwise, an exception of type FeatherJsError will be raised that can be caught on the stream
  ///
  ///     Use FeatherJsErrorType.{ERROR} to known what happen
  ///
  Stream<FeathersJsEventData<T>> listen<T>({
    required String serviceName,
    required Function fromJson,
  }) {
    /// On updated event
    _socket.on('$serviceName updated', (updatedData) {
      try {
        T? object = fromJson(updatedData);
        eventBus.fire(FeathersJsEventData<T>(
          data: object,
          type: FeathersJsEventType.updated,
        ));
      } catch (e) {
        eventBus.fire(new FeatherJsError(
          type: FeatherJsErrorType.DESERIALIZATION_ERROR,
          error: e,
        ));
      }
    });

    /// On patched event
    _socket.on('$serviceName patched', (patchedData) {
      try {
        T? object = fromJson(patchedData);
        eventBus.fire(FeathersJsEventData<T>(
          data: object,
          type: FeathersJsEventType.patched,
        ));
      } catch (e) {
        eventBus.fire(new FeatherJsError(
          type: FeatherJsErrorType.DESERIALIZATION_ERROR,
          error: e,
        ));
      }
    });

    /// On removed event
    _socket.on('$serviceName removed', (removedData) {
      try {
        T? object = fromJson(removedData);
        eventBus.fire(FeathersJsEventData<T>(
            data: object, type: FeathersJsEventType.removed));
      } catch (e) {
        eventBus.fire(new FeatherJsError(
            type: FeatherJsErrorType.DESERIALIZATION_ERROR, error: e));
      }
    });

    /// On created event
    _socket.on('$serviceName created', (createdData) {
      try {
        T? object = fromJson(createdData);
        eventBus.fire(FeathersJsEventData<T>(
            data: object, type: FeathersJsEventType.created));
      } catch (e) {
        eventBus.fire(new FeatherJsError(
            type: FeatherJsErrorType.DESERIALIZATION_ERROR, error: e));
      }
    });
    return eventBus.on<FeathersJsEventData<T>>();
  }
}
