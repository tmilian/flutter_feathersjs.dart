import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_feathersjs/flutter_feathersjs.dart';

class RestClient {
  Dio dio;
  Storage tokenStorage;

  RestClient({
    required String baseUrl,
    Map<String, dynamic>? extraHeaders,
    required this.tokenStorage,
  }) : dio = Dio(BaseOptions(baseUrl: baseUrl, headers: extraHeaders)) {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) async {
        var token = await tokenStorage.getAccessToken();
        this.dio.options.headers["Authorization"] = "Bearer $token";
        return handler.next(options);
      }, onResponse: (response, handler) {
        return handler.next(response);
      }, onError: (DioError error, handler) async {
        if (error.response?.statusCode == 401 &&
            error.requestOptions.path != '/authentication') {
          dio.lock();
          dio.interceptors.requestLock.lock();
          try {
            await refreshToken();
          } catch (e) {
            String? accessToken = await tokenStorage.getAccessToken();
            var requestOptions = error.requestOptions;
            requestOptions.headers['Authorization'] = 'Bearer $accessToken';
            final opts = Options(method: requestOptions.method);
            final response = await dio.request(
              '${error.requestOptions.baseUrl}/${requestOptions.path}',
              options: opts,
              cancelToken: requestOptions.cancelToken,
              onReceiveProgress: requestOptions.onReceiveProgress,
              data: requestOptions.data,
              queryParameters: requestOptions.queryParameters,
            );
            return handler.resolve(response);
          }
          dio.unlock();
          dio.interceptors.requestLock.unlock();
        }
        return handler.next(error);
      }),
    );
  }

  /// Authenticate with username & password
  ///
  /// @params `username` can be : email, phone, etc;
  ///
  /// But ensure that `userNameFieldName` is correct with your `strategy`
  ///
  /// By default this will be `email`and the strategy `local`
  Future<dynamic> authenticate({
    strategy = "local",
    required String? username,
    required String? password,
    String usernameFieldName = "email",
  }) async {
    try {
      var resp = await this.dio.post(
        "/authentication",
        data: {
          "$usernameFieldName": username,
          "password": password,
          "strategy": strategy,
        },
      );
      if (resp.data['accessToken'] != null && resp.data['user'] != null) {
        await tokenStorage.setAccessToken(token: resp.data['accessToken']);
        await tokenStorage.setUser(user: resp.data['user']);
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.UNKNOWN_ERROR,
            error: resp.data["message"]);
      }
      if (resp.data['refreshToken'] != null) {
        await tokenStorage.setRefreshToken(token: resp.data['refreshToken']);
      }
      return resp.data;
    } on DioError catch (e) {
      if (e.response != null) {
        if (e.response?.statusCode == 401) {
          if (e.response?.data["message"] == "Invalid login") {
            throw FeatherJsError(
                type: FeatherJsErrorType.INVALID_CREDENTIALS_ERROR,
                error: e.response?.data["message"]);
          } else {
            throw FeatherJsError(
                type: FeatherJsErrorType.INVALID_STRATEGY_ERROR,
                error: e.response?.data["message"]);
          }
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.UNKNOWN_ERROR, error: e);
        }
      } else {
        throw FeatherJsError(
          error: e.message,
          type: FeatherJsErrorType.CANNOT_SEND_REQUEST,
        );
      }
    }
  }

  /// Authenticate with username & password
  ///
  /// @params `username` can be : email, phone, etc;
  ///
  /// But ensure that `userNameFieldName` is correct with your chosed `strategy`
  ///
  /// By default this will be `email`and the strategy `local`
  Future<Map<String, dynamic>> refreshToken() async {
    var refreshToken = await tokenStorage.getRefreshToken();
    try {
      var response = await this.dio.post(
        "/authentication",
        data: {
          "refreshToken": refreshToken,
          "action": "refresh",
        },
      );
      if (response.data['accessToken'] != null &&
          response.data['refreshToken'] != null) {
        await tokenStorage.setAccessToken(token: response.data['accessToken']);
        await tokenStorage.setRefreshToken(
          token: response.data['refreshToken'],
        );
        await tokenStorage.setUser(user: response.data['user']);
      } else {
        throw "Malformed refresh token";
      }
      return response.data;
    } catch (e) {
      throw e;
    }
  }

  /// `GET /serviceName`
  ///
  /// Retrieves a list of all matching the `query` resources from the service
  ///
  Future<dynamic> find({
    required String serviceName,
    required Map<String, dynamic> query,
  }) async {
    try {
      var response = await this.dio.get(
            "/$serviceName",
            queryParameters: query,
          );
      if (response.data != null) {
        return response.data;
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.SERVER_ERROR,
            error: "Response body is empty");
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw errorCode2FeatherJsError(e.response?.data);
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.UNKNOWN_ERROR, error: e.message);
      }
    }
  }

  /// `GET /serviceName/_id`
  ///
  /// Retrieve a single resource from the service with an `_id`
  ///
  Future<dynamic> get({
    required String serviceName,
    required String objectId,
  }) async {
    try {
      var response = await this.dio.get("/$serviceName/$objectId");

      if (response.data != null) {
        return response.data;
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.SERVER_ERROR,
            error: "Response body is empty");
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw errorCode2FeatherJsError(e.response?.data);
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.UNKNOWN_ERROR, error: e.message);
      }
    }
  }

  /// `POST /serviceName`
  ///
  /// Create a new resource with data.
  ///
  /// The below is important if you have file to upload [containsFile == true]
  ///
  /// @ `fileFieldName`: the file | files field which must be send to the server
  ///
  /// @var `files`: a Map of `{"filename": <File Bytes>}`
  ///
  ///
  Future<dynamic> create({
    required String serviceName,
    required Map<String, dynamic> data,
    fileFieldName = "file",
    Map<String, List<int>> files = const {},
  }) async {
    if (files.isEmpty) {
      try {
        var response = await this.dio.post("/$serviceName", data: data);
        if (response.data != null) {
          return response.data;
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw FeatherJsError(
            type: FeatherJsErrorType.SERVER_ERROR, error: e.response);
      }
    } else {
      try {
        var formData = await this.makeFormData(
            dataFields: data, fileFieldName: fileFieldName, files: files);
        var response = await this.dio.post("/$serviceName", data: formData);
        if (response.data != null) {
          return response.data;
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw e.featherJsError;
      }
    }
  }

  /// `PUT /serviceName/_id`
  ///
  /// Completely replace a single resource with the `_id = objectId`
  ///
  /// @ `fileFieldName`: the file | files field which must be send to the server
  ///
  /// @var `files`: a Map of `{"filename": <File Bytes>}`
  ///
  Future<dynamic> update({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
    String fileFieldName = "file",
    Map<String, List<int>> files = const {},
  }) async {
    if (files.isEmpty) {
      try {
        var response =
            await this.dio.put("/$serviceName" + "/$objectId", data: data);
        if (response.data != null) {
          return response.data;
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw e.featherJsError;
      }
    } else {
      try {
        var formData = await this.makeFormData(
            dataFields: data, fileFieldName: fileFieldName, files: files);
        var response = await this
            .dio
            .patch("/$serviceName" + "/$objectId", data: formData);
        if (response.data != null) {
          return response.data;
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw e.featherJsError;
      }
    }
  }

  /// `PATCH /serviceName/_id`
  ///
  /// Merge the existing data of a single (`_id = objectId`) resource with the new `data`
  ///
  /// @ `fileFieldName`: the file | files field which must be send to the server
  ///
  /// @var `files`: a Map of `{"filename": <File Bytes>}`
  ///
  Future<dynamic> patch<T>({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
    String fileFieldName = "file",
    Map<String, List<int>> files = const {},
  }) async {
    if (files.isEmpty) {
      try {
        var response =
            await this.dio.patch("/$serviceName" + "/$objectId", data: data);
        if (response.data != null) {
          return response.data;
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw e.featherJsError;
      }
    } else {
      try {
        var formData = await this.makeFormData(
            dataFields: data, fileFieldName: fileFieldName, files: files);
        var response = await this
            .dio
            .patch("/$serviceName" + "/$objectId", data: formData);
        if (response.data != null) {
          return response.data;
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw e.featherJsError;
      }
    }
  }

  /// `DELETE /serviceName/_id`
  ///
  /// Remove a single  resource with `_id = objectId `:
  Future<dynamic> remove({
    required String serviceName,
    required String objectId,
  }) async {
    try {
      var response = await this.dio.delete(
            "/$serviceName/$objectId",
          );
      if (response.data != null) {
        return response.data;
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.SERVER_ERROR,
            error: "Response body is empty");
      }
    } on DioError catch (e) {
      throw e.featherJsError;
    }
  }

  /// @params `dataFields`: form data fields that are not files
  ///
  /// @params `fileFieldName`: the file | files field which must be send to the server
  ///
  /// @var `files`: a Map of `{"filename": <File Bytes>}`
  ///
  Future<FormData> makeFormData({
    required fileFieldName,
    required Map<String, List<int>> files,
    Map<String, dynamic>? dataFields,
  }) async {
    Map<String, dynamic> data = {};
    if (dataFields != null) {
      dataFields.forEach((key, value) {
        data["$key"] = value;
      });
    }
    var formData = FormData.fromMap(data);
    files.forEach((key, value) {
      formData.files.add(MapEntry(
        fileFieldName,
        MultipartFile.fromBytes(value, filename: key),
      ));
    });
    return formData;
  }
}
