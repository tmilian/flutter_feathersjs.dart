import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' as Foundation;
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

  /// `Authenticate with JWT`
  ///
  /// The @params serviceName is used to test if the last token still validated
  ///
  /// It so assume that your api has at least a service called  `$serviceName`
  ///
  /// `$serviceName` may be a service which required authentication
  Future<dynamic> reAuthenticate({String serviceName = "users"}) async {
    Completer asyncTask = Completer<dynamic>();
    FeatherJsError? featherJsError;
    bool isReauthenticate = false;

    //Getting the early stored rest access token and send the request by using it
    var oldToken = await tokenStorage.getAccessToken();

    ///If an oldToken exist really, try to chect if it is still validated
    this.dio.options.headers["Authorization"] = "Bearer $oldToken";
    try {
      var response = await this.dio.get(
        "/$serviceName",
        queryParameters: {"\$limit": 1},
      );
      if (!Foundation.kReleaseMode) {
        print(response);
      }
      if (response.statusCode == 401) {
        if (!Foundation.kReleaseMode) {
          print("jwt expired or jwt malformed");
        }
        featherJsError = new FeatherJsError(
            type: FeatherJsErrorType.IS_JWT_EXPIRED_ERROR,
            error: "Must authenticate again because Jwt has expired");
      } else if (response.statusCode == 200) {
        if (!Foundation.kReleaseMode) {
          print("Jwt still validated");
          isReauthenticate = true;
        }
      } else {
        if (!Foundation.kReleaseMode) {
          print("Unknown error");
        }
        featherJsError = new FeatherJsError(
            type: FeatherJsErrorType.IS_UNKNOWN_ERROR,
            error:
                "Must authenticate again because unable to authenticate with the last token");
      }
    } on DioError catch (e) {
      // Error
      if (!Foundation.kReleaseMode) {
        print("Unable to connect to the server");
      }
      if (e.response != null) {
        featherJsError = new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR, error: e.response);
      } else {
        featherJsError = new FeatherJsError(
            type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e);
      }
    }

    if (featherJsError != null) {
      //Complete with error
      asyncTask.completeError(featherJsError);
    } else {
      // Complete with success
      asyncTask.complete(isReauthenticate);
    }
    return asyncTask.future;
  }

  /// Authenticate with username & password
  ///
  /// @params `username` can be : email, phone, etc;
  ///
  /// But ensure that `userNameFieldName` is correct with your chosed `strategy`
  ///
  /// By default this will be `email`and the strategy `local`
  Future<dynamic> authenticate({
    strategy = "local",
    required String? userName,
    required String? password,
    String userNameFieldName = "email",
  }) async {
    try {
      var resp = await this.dio.post(
        "/authentication",
        data: {
          "$userNameFieldName": userName,
          "password": password,
          "strategy": strategy,
        },
      );
      if (resp.data['accessToken'] != null && resp.data['user'] != null) {
        await tokenStorage.setAccessToken(token: resp.data['accessToken']);
        await tokenStorage.setUser(user: resp.data['user']);
      } else {
        throw FeatherJsError(
            type: FeatherJsErrorType.IS_UNKNOWN_ERROR,
            error: resp.data["message"]);
      }
      if (resp.data['refreshToken'] != null) {
        await tokenStorage.setRefreshToken(token: resp.data['refreshToken']);
      }
      return resp.data;
    } on DioError catch (e) {
      if (e.response != null) {
        if (e.response?.data["code"] == 401) {
          if (e.response?.data["message"] == "Invalid login") {
            throw FeatherJsError(
                type: FeatherJsErrorType.IS_INVALID_CREDENTIALS_ERROR,
                error: e.response?.data["message"]);
          } else {
            throw FeatherJsError(
                type: FeatherJsErrorType.IS_INVALID_STRATEGY_ERROR,
                error: e.response?.data["message"]);
          }
        } else {
          throw FeatherJsError(
              type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e);
        }
      } else {
        throw FeatherJsError(
          error: e.message,
          type: FeatherJsErrorType.IS_CANNOT_SEND_REQUEST,
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
  Future<dynamic> refreshToken() async {
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
          response.data['refreshToken'] != null &&
          response.data['user'] != null) {
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
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR,
            error: "Response body is empty");
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw errorCode2FeatherJsError(e.response?.data);
      } else {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e.message);
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
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR,
            error: "Response body is empty");
      }
    } on DioError catch (e) {
      if (e.response != null) {
        throw errorCode2FeatherJsError(e.response?.data);
      } else {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e.message);
      }
    }
  }

  /// `POST /serviceName`
  ///
  /// Create a new resource with data.
  ///
  /// The below is important if you have file to upload [containsFile == true]
  ///
  ///
  ///
  /// @ `fileFieldName`: the file | files field which must be send to the server
  ///
  /// [@var files: a List of map of {"filePath": the file path, "fileName": the file ame}]
  //      Or if multiple files
  ///     var files =
  ///     [
  ///
  ///     { 'filePath': '/data/shared/epatriote_logo.png', 'fileName': 'epatriote_logo.png' },
  ///     { 'filePath': '/data/shared/epatriote_bg.png', 'fileName': 'epatriote_bg.png' },
  ///     { 'filePath': '/data/shared/epatriote_log_dark.png', 'fileName': 'epatriote_log_dark.png' }
  ///
  ///     ]
  ///
  ///
  ///
  Future<dynamic> create({
    required String serviceName,
    required Map<String, dynamic> data,
    containsFile = false,
    fileFieldName = "file",
    List<Map<String, String>>? files,
  }) async {
    var response;

    if (!containsFile) {
      try {
        response = await this.dio.post("/$serviceName", data: data);
        if (response.data != null) {
          return response.data;
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR, error: e.response);
      }
    } else {
      // Making form Data
      FormData formData;
      try {
        formData = await this.makeFormData(
            nonFilesFieldsMap: data,
            fileFieldName: fileFieldName,
            files: files!);
      } catch (e) {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_FORM_DATA_ERROR, error: e);
      }

      // Making request
      try {
        response = await this.dio.post("/$serviceName", data: formData);
        if (response.data != null) {
          return response.data;
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        if (e.response != null) {
          throw errorCode2FeatherJsError(e.response?.data);
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e.message);
        }
      }
    }
  }

  /// `PUT /serviceName/_id`
  ///
  /// Completely replace a single resource with the `_id = objectId`
  ///
  /// The below is important if you have file to upload [containsFile == true]
  /// @ `fileFieldName`: the file | files field which must be send to the server
  ///
  /// [@var files: a List map of {"filePath": the file path, "fileName": the file ame}]
  ///      Or if multiple files
  ///     var files =
  ///     [
  ///
  ///     { 'filePath': '/data/shared/epatriote_logo.png', 'fileName': 'epatriote_logo.png' },
  ///     { 'filePath': '/data/shared/epatriote_bg.png', 'fileName': 'epatriote_bg.png' },
  ///     { 'filePath': '/data/shared/epatriote_log_dark.png', 'fileName': 'epatriote_log_dark.png' }
  ///
  ///     ]
  ///
  ///
  ///
  Future<dynamic> update({
    required String serviceName,
    required String objectId,
    required Map<String, dynamic> data,
    containsFile = false,
    fileFieldName = "file",
    List<Map<String, String>>? files,
  }) async {
    var response;

    if (!containsFile) {
      // Try making request with no file field
      try {
        response =
            await this.dio.put("/$serviceName" + "/$objectId", data: data);
        if (response.data != null) {
          return response.data;
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR, error: e.response);
      }
    } else {
      // Building form data
      FormData formData;
      try {
        formData = await this.makeFormData(
            nonFilesFieldsMap: data,
            fileFieldName: fileFieldName,
            files: files!);
      } catch (e) {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_FORM_DATA_ERROR, error: e);
      }

      // Try making request with  file field
      try {
        response = await this
            .dio
            .patch("/$serviceName" + "/$objectId", data: formData);
        if (response.data != null) {
          return response.data;
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        if (e.response != null) {
          throw errorCode2FeatherJsError(e.response?.data);
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e.message);
        }
      }
    }
  }

  /// `PATCH /serviceName/_id`
  ///
  /// Merge the existing data of a single (`_id = objectId`) resource with the new `data`
  ///
  /// The below is important if you have file to upload [containsFile == true]
  ///
  ///
  ///
  /// @ `fileFieldName`: the file | files field which must be send to the server
  ///
  /// [@var files: a List map of {"filePath": the file path, "fileName": the file ame}]
  ///
  ///     // Or if multiple files
  ///     var files =
  ///     [
  ///
  ///     { 'filePath': '/data/shared/epatriote_logo.png', 'fileName': 'epatriote_logo.png' },
  ///     { 'filePath': '/data/shared/epatriote_bg.png', 'fileName': 'epatriote_bg.png' },
  ///     { 'filePath': '/data/shared/epatriote_log_dark.png', 'fileName': 'epatriote_log_dark.png' }
  ///
  ///     ]
  ///
  ///
  ///
  Future<dynamic> patch<T>(
      {required String serviceName,
      required String objectId,
      required Map<String, dynamic> data,
      containsFile = false,
      fileFieldName = "file",
      List<Map<String, String>>? files}) async {
    var response;

    if (!containsFile) {
      // Try making request with no file field
      try {
        response =
            await this.dio.patch("/$serviceName" + "/$objectId", data: data);
        if (response.data != null) {
          return response.data;
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR, error: e.response);
      }
    } else {
      // Try building form data
      FormData formData;
      try {
        formData = await this.makeFormData(
            nonFilesFieldsMap: data,
            fileFieldName: fileFieldName,
            files: files!);
      } catch (e) {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_FORM_DATA_ERROR, error: e);
      }

      // Try to send response as feathers send or throw an error
      try {
        response = await this
            .dio
            .patch("/$serviceName" + "/$objectId", data: formData);
        if (response.data != null) {
          return response.data;
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_SERVER_ERROR,
              error: "Response body is empty");
        }
      } on DioError catch (e) {
        if (e.response != null) {
          throw errorCode2FeatherJsError(e.response?.data);
        } else {
          throw new FeatherJsError(
              type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e.message);
        }
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
      // Send only feathers js data
      if (response.data != null) {
        return response.data;
      } else {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_SERVER_ERROR,
            error: "Response body is empty");
      }
    } on DioError catch (e) {
      // Throw an exception with e
      if (e.response != null) {
        throw errorCode2FeatherJsError(e.response?.data);
      } else {
        throw new FeatherJsError(
            type: FeatherJsErrorType.IS_UNKNOWN_ERROR, error: e.message);
      }
    }
  }

  /// @params `nonFilesFieldsMap`: other field non file
  ///
  ///
  /// @params `fileFieldName`: the file | files field which must be send to the server
  ///
  /// @var `files`: a List map of `{"filePath": the file path, "fileName": the file name with extension}`
  ///
  /// `Example: { 'filePath': '/data/shared/epatriote_logo.png', 'fileName': 'epatriote_logo.png' }`
  ///
  ///     // Or if multiple files
  ///     var files =
  ///     [
  ///
  ///     { 'filePath': '/data/shared/epatriote_logo.png', 'fileName': 'epatriote_logo.png' },
  ///     { 'filePath': '/data/shared/epatriote_bg.png', 'fileName': 'epatriote_bg.png' },
  ///     { 'filePath': '/data/shared/epatriote_log_dark.png', 'fileName': 'epatriote_log_dark.png' }
  ///
  ///     ]
  ///
  ///
  ///
  Future<FormData> makeFormData(
      {Map<String, dynamic>? nonFilesFieldsMap,
      required fileFieldName,
      required List<Map<String, String>> files}) async {
    Map<String, dynamic> data = {};

    // logging
    if (!Foundation.kReleaseMode) {
      print("Building formData before sending it to feathers");
    }

    // Non file
    if (nonFilesFieldsMap != null) {
      print("Adding non null nonFilesFieldsMap");
      nonFilesFieldsMap.forEach((key, value) {
        data["$key"] = value;
      });
    }

    // Build now the request as a form data
    var formData = FormData.fromMap(data);
    for (var fileData in files) {
      formData.files.add(MapEntry(
        fileFieldName,
        await MultipartFile.fromFile(fileData["filePath"]!,
            filename: fileData["fileName"]!),
      ));
    }

    return formData;
  }
}
