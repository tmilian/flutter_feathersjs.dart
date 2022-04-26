import 'package:dio/dio.dart';

/// FeatherJsErrorType
enum FeatherJsErrorType {
  SERVER_ERROR,
  REST_ERROR,
  SOCKETIO_ERROR,
  DESERIALIZATION_ERROR,
  UNKNOWN_ERROR,
  JWT_TOKEN_ERROR,
  FORM_DATA_ERROR,
  JWT_TOKEN_NOT_FOUND_ERROR,
  JWT_INVALID_ERROR,
  JWT_EXPIRED_ERROR,
  INVALID_CREDENTIALS_ERROR,
  INVALID_STRATEGY_ERROR,
  AUTH_FAILED_ERROR,
  BAD_REQUEST_ERROR,
  NOT_AUTHENTICATED_ERROR,
  PAYMENT_ERROR,
  FORBIDDEN_ERROR,
  NOT_FOUND_ERROR,
  METHOD_NOT_ALLOWED_ERROR,
  NOT_ACCEPTABLE_ERROR,
  TIMEOUT_ERROR,
  CONFLICT_ERROR,
  LENGTH_REQUIRED_ERROR,
  UNPROCESSABLE_ERROR,
  TOO_MANY_REQUESTS_ERROR,
  GENERAL_ERROR,
  NOT_IMPLEMENTED_ERROR,
  BAD_GATE_WAY_ERROR,
  UNAVAILABLE_ERROR,
  CANNOT_SEND_REQUEST,
}

class FeatherJsError implements Exception {
  FeatherJsError({
    this.type = FeatherJsErrorType.UNKNOWN_ERROR,
    this.error,
  });

  FeatherJsErrorType type;
  dynamic error;
  String get message => (error?.toString() ?? '');
}

extension DioErrorExt on DioError {
  FeatherJsError get featherJsError {
    var type;
    switch (this.response?.statusCode) {
      case 400:
        type = FeatherJsErrorType.BAD_REQUEST_ERROR;
        break;
      case 401:
        type = FeatherJsErrorType.NOT_AUTHENTICATED_ERROR;
        break;
      case 402:
        type = FeatherJsErrorType.PAYMENT_ERROR;
        break;
      case 403:
        type = FeatherJsErrorType.FORBIDDEN_ERROR;
        break;
      case 404:
        type = FeatherJsErrorType.NOT_FOUND_ERROR;
        break;
      case 405:
        type = FeatherJsErrorType.METHOD_NOT_ALLOWED_ERROR;
        break;
      case 406:
        type = FeatherJsErrorType.NOT_ACCEPTABLE_ERROR;
        break;
      case 408:
        type = FeatherJsErrorType.TIMEOUT_ERROR;
        break;
      case 409:
        type = FeatherJsErrorType.CONFLICT_ERROR;
        break;
      case 411:
        type = FeatherJsErrorType.LENGTH_REQUIRED_ERROR;
        break;
      case 422:
        type = FeatherJsErrorType.UNPROCESSABLE_ERROR;
        break;
      case 429:
        type = FeatherJsErrorType.TOO_MANY_REQUESTS_ERROR;
        break;
      case 500:
        type = FeatherJsErrorType.GENERAL_ERROR;
        break;
      case 501:
        type = FeatherJsErrorType.NOT_IMPLEMENTED_ERROR;
        break;
      case 502:
        type = FeatherJsErrorType.BAD_GATE_WAY_ERROR;
        break;
      case 503:
        type = FeatherJsErrorType.UNAVAILABLE_ERROR;
        break;
      default:
        type = FeatherJsErrorType.SERVER_ERROR;
    }
    return FeatherJsError(error: this.message, type: type);
  }
}

FeatherJsError errorCode2FeatherJsError(error) {
  var type;
  switch (error["code"]) {
    case 400:
      type = FeatherJsErrorType.BAD_REQUEST_ERROR;
      break;
    case 401:
      type = FeatherJsErrorType.NOT_AUTHENTICATED_ERROR;
      break;
    case 402:
      type = FeatherJsErrorType.PAYMENT_ERROR;
      break;
    case 403:
      type = FeatherJsErrorType.FORBIDDEN_ERROR;
      break;
    case 404:
      type = FeatherJsErrorType.NOT_FOUND_ERROR;
      break;
    case 405:
      type = FeatherJsErrorType.METHOD_NOT_ALLOWED_ERROR;
      break;
    case 406:
      type = FeatherJsErrorType.NOT_ACCEPTABLE_ERROR;
      break;
    case 408:
      type = FeatherJsErrorType.TIMEOUT_ERROR;
      break;
    case 409:
      type = FeatherJsErrorType.CONFLICT_ERROR;
      break;
    case 411:
      type = FeatherJsErrorType.LENGTH_REQUIRED_ERROR;
      break;
    case 422:
      type = FeatherJsErrorType.UNPROCESSABLE_ERROR;
      break;
    case 429:
      type = FeatherJsErrorType.TOO_MANY_REQUESTS_ERROR;
      break;
    case 500:
      type = FeatherJsErrorType.GENERAL_ERROR;
      break;
    case 501:
      type = FeatherJsErrorType.NOT_IMPLEMENTED_ERROR;
      break;
    case 502:
      type = FeatherJsErrorType.BAD_GATE_WAY_ERROR;
      break;
    case 503:
      type = FeatherJsErrorType.UNAVAILABLE_ERROR;
      break;
    default:
      type = FeatherJsErrorType.SERVER_ERROR;
  }
  return new FeatherJsError(error: error, type: type);
}
