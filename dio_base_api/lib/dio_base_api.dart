library dio_base_api;

import 'package:dio/dio.dart';
import 'package:dio_base_api/exceptions/exceptions.dart';
import 'package:dio_base_api/listeners/api_listener.dart';

import 'config/conectivity_service.dart';

export 'package:dio/src/options.dart';

enum HttpMethod { get, post, put, del }

extension HttoMethodEx on HttpMethod {
  String get code {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.del:
        return 'DELETE';
    }
  }
}

class DioBaseApi {
  // PROPERTIES
  late Dio _dio;
  late String _baseUrl;
  late bool _isProductEnv;
  ApiListener? _listener;

  /// if you don't want to show log in logcat on production environment
  /// you can set [isProductEnv] = true to ignore print log. Default
  /// [isProductEnv] = false,
  DioBaseApi({
    required String baseUrl,
    Interceptor? customInterceptor,
    int receiveTimeout = 30000,
    int connectTimeout = 30000,
    bool isProductEnv = false,
  }) {
    /// check baseUrl == null or empty
    assert(baseUrl.isNotEmpty);

    /// initial base url
    _baseUrl = baseUrl;

    /// initial isProductEnv
    _isProductEnv = isProductEnv;

    /// create [BaseOptions] instance
    final BaseOptions options = BaseOptions(
      receiveTimeout: receiveTimeout,
      connectTimeout: connectTimeout,
      baseUrl: _baseUrl,
    );

    /// initial [_dio] with [options]
    _dio = Dio(options);

    _setupLoggingInterceptor(
      customInterceptor: customInterceptor,
    );
  }

  /// you can set path, Http method, header in [config] to make request
  /// set token for request by [token]
  /// add query by [queryParams]
  /// add more path by [optionalPath]
  /// example:
  /// mainPath = abc/def
  /// [optionalPath] = ghj
  /// => full path is abc/def/ghj
  /// and base url + full path is
  /// => https://google.com.vn/abc/def/ghj
  Future request({
    required String path,
    required HttpMethod method,
    String? token,
    String? contentType,
    String? optionalPath,
    Map<String, dynamic>? headers,
    dynamic bodyParams,
    Map<String, dynamic>? queryParams,
    bool Function(int?)? validateStatus,
    bool? receiveDataWhenStatusError,
    bool? followRedirects,
    int? maxRedirects,
    ResponseType? responseType,
    ListFormat? listFormat,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
  }) async {
    assert((path.isNotEmpty));
    dynamic responseData;
    try {
      // Check internet connection
      if (!(await _checkInternetConnection())) {
        throw (ConnectionException());
      }

      if (token?.isNotEmpty ?? false) {
        _setToken(token!, headers);
      }

      if (_listener?.onRequestCall != null) {
        final isContinue = await _listener!.onRequestCall();
        if (!isContinue) {
          throw ManuallyException('');
        }
      }

      // Setup custom path
      final String customPath =
          optionalPath != null ? (path + optionalPath) : path;

      // late Response response;

      final res = await _dio.request(
        customPath,
        data: bodyParams,
        queryParameters: queryParams,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          method: method.code,
          contentType: contentType,
          headers: headers,
          validateStatus: validateStatus,
          receiveDataWhenStatusError: receiveDataWhenStatusError,
          followRedirects: followRedirects,
          maxRedirects: maxRedirects,
          responseType: responseType,
          listFormat: listFormat,
        ),
      );
      responseData = res.data;
    } on DioError catch (exception) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      _printLog(exception.error.toString());
      if (exception.response?.statusCode == 201) {
        responseData = exception.response?.data;
      }
      // Check for authorization error
      if ((exception.response?.statusCode ?? -1) == 401) {
        if ((token?.isNotEmpty ?? false) && _listener != null) {
          _listener?.onTokenExpired();
        }
        throw (TokenExpiredException());
      }

      // Check for server error
      if ((exception.response?.statusCode ?? -1) == 500) {
        if (exception.response?.data is! String) {
          return exception.response?.data;
        }
        throw (ServerException(
          exception.response?.data.toString(),
          code: exception.response?.statusCode,
        ));
      }

      if (exception.response != null) {
        if (exception.response?.data is! String) {
          return exception.response?.data;
        }
        throw (ServerException(
          exception.response?.toString() ?? '',
          code: exception.response?.statusCode ?? -1,
        ));
      }
      throw (ServerException(
        exception.message,
        code: exception.response?.statusCode ?? -1,
      ));
    }
    return responseData;
  }

  // SUPPORT

  void _setupLoggingInterceptor({Interceptor? customInterceptor}) {
    if (customInterceptor != null) {
      _dio.interceptors.add(customInterceptor);
      return;
    }
    const int maxCharactersPerLine = 200;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (
          RequestOptions options,
          RequestInterceptorHandler requestHandler,
        ) {
          _printLog(
              '--> ${options.method.toString()} ${options.path.toString()}');
          _printLog('URI: ${options.uri.toString()}');
          _printLog('Headers ${options.headers.toString()}');
          _printLog('Data ${options.data.toString()}');
          _printLog('Query ${options.queryParameters.toString()}');
          _printLog('<-- END HTTP');
          requestHandler.next(options);
        },
        onResponse: (
          Response response,
          ResponseInterceptorHandler responseHandler,
        ) {
          _printLog(
              '<-- ${response.statusCode.toString()} ${response.requestOptions.method.toString()} ${response.requestOptions.path.toString()}');
          final String responseAsString = response.data.toString();
          if (responseAsString.length > maxCharactersPerLine) {
            final int iterations =
                (responseAsString.length / maxCharactersPerLine).floor();
            for (int i = 0; i <= iterations; i++) {
              int endingIndex = i * maxCharactersPerLine + maxCharactersPerLine;
              if (endingIndex > responseAsString.length) {
                endingIndex = responseAsString.length;
              }
              _printLog(responseAsString.substring(
                  i * maxCharactersPerLine, endingIndex));
            }
          } else {
            _printLog(response.data.toString());
          }
          _printLog('<-- END HTTP');
          responseHandler.next(response);
        },
        onError: (
          DioError e,
          ErrorInterceptorHandler errorHandler,
        ) {
          _printLog(e.message.toString());
          errorHandler.next(e);
        },
      ),
    );
  }

  void _printLog(String? log) {
    if (!_isProductEnv) {
      print(log ?? '');
    }
  }

  void closeConnection() {
    _dio.unlock();
  }

  void _setToken(String token, Map<String, dynamic>? header) {
    if (header == null) {
      header = {};
    }

    header['Authorization'] = 'Bearer $token';
  }

  Future<bool> _checkInternetConnection() async {
    final ConnectivityService service = ConnectivityService();
    return service.hasConnection();
  }

  void setListener(ApiListener? listener) {
    _listener = listener;
  }

  void setBaseOptions(BaseOptions options) {
    _dio.options = options;
  }
}
