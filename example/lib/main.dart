import 'dart:convert';

import 'package:dio_base_api/dio_base_api.dart';
import 'package:dio_base_api/exceptions/exceptions.dart';
import 'package:dio_base_api/listeners/api_listener.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Close keyboard when tap outside input zone (textField,...)
        WidgetsBinding.instance?.focusManager.primaryFocus?.unfocus();
      },
      child: MaterialApp(
        title: 'Flutter Api Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Flutter Api Demo'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

const demoApi = 'https://jsonplaceholder.typicode.com/';
const demoPath = '/posts';

class _MyHomePageState extends State<MyHomePage> implements ApiListener {
  final _baseUrlController = TextEditingController(text: '');
  final _pathController = TextEditingController(text: '');
  final _optionalPathController = TextEditingController(text: '');
  final _tokenController = TextEditingController(text: '');
  final _queryParamsController = TextEditingController(text: '');
  final _bodyParamsController = TextEditingController(text: '');
  late String baseUrl = demoApi;
  late HttpMethod _httpMethod = HttpMethod.get;
  bool _isLoading = false;
  late DioBaseApi? baseApi;

  @override
  void initState() {
    _baseUrlController.text = demoApi;
    _pathController.text = demoPath;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Base API Demo',
          style: Theme.of(context)
              .textTheme
              .headline6!
              .copyWith(color: Colors.white),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextFormField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              label: Text('Base Url'),
            ),
          ),
          TextFormField(
            controller: _pathController,
            decoration: const InputDecoration(
              label: Text('Path'),
            ),
          ),
          TextFormField(
            controller: _optionalPathController,
            decoration: const InputDecoration(
              label: Text('Optional Path'),
            ),
          ),
          TextFormField(
            controller: _tokenController,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(
              label: Text('Token'),
            ),
          ),
          TextFormField(
            controller: _queryParamsController,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(
              label: Text('Query Params'),
            ),
          ),
          TextFormField(
            controller: _bodyParamsController,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(
              label: Text('Body Params'),
            ),
          ),
          DropdownButtonFormField<HttpMethod>(
            decoration: const InputDecoration(
              label: Text('Http Method'),
            ),
            value: _httpMethod,
            items: HttpMethod.values
                .map(
                  (e) => DropdownMenuItem<HttpMethod>(
                    value: e,
                    child: Text(
                      httpMethodTitle[e.index],
                    ),
                  ),
                )
                .toList(),
            isExpanded: true,
            onChanged: (val) {
              _httpMethod = val!;
            },
          ),
          const SizedBox(
            height: 16,
          ),
          _buildButtons(_isLoading)
        ],
      ),
    );
  }

  Widget _buildButtons(bool isLoading) {
    Widget child = Text(
      'Call',
      style: Theme.of(context).textTheme.button!.copyWith(color: Colors.white),
    );
    if (isLoading) {
      child = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 45),
      ),
      child: child,
      onPressed: isLoading ? null : _onCallPressed,
    );
  }

  Widget _buildDialog(String message) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.90,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'DIO BASE API',
              style: Theme.of(context).textTheme.bodyText1,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyText2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(
              height: 1,
              color: Colors.grey,
            ),
            InkWell(
              child: Container(
                width: double.maxFinite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Close',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.button,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> get httpMethodTitle => ['Get', 'Post', 'Put', 'Delete'];

  @override
  void onTokenExpired() {
    Navigator.popUntil(context, (route) => route.isFirst);
    showDialog(
      context: context,
      builder: (ctx) => _buildDialog('Token is Expired'),
    );
  }

  @override
  void onRequestCall() {
    print('Request called');
  }

  void setBaseApi(String url) {
    baseApi = DioBaseApi(
      baseUrl: url,
    );
    baseApi?.setListener(this);
  }

  Future _onCallPressed() async {
    _setLoading(true);
    final request = DataRequest(
      baseApiUrl: _baseUrlController.text.trim(),
      path: _pathController.text.trim(),
      optionalPath: _optionalPathController.text.trim(),
      token: _tokenController.text.trim(),
      queryParams: _queryParamsController.text.trim(),
      bodyParams: _bodyParamsController.text.trim(),
    );

    final validate = request.validate;

    if (validate.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => _buildDialog(validate),
      );

      _setLoading(false);
      return;
    }

    setBaseApi(request.baseApiUrl);

    try {
      final result = await baseApi?.request(
        path: request.path,
        method: _httpMethod,
        optionalPath:
            request.optionalPath.isEmpty ? null : request.optionalPath,
        token: request.token,
        queryParams: request.convertQueryParamsToMap,
        bodyParams: request.convertBodyParamsToMap,
        responseType: ResponseType.plain,
      );

      if (result == null) {
        showDialog(
          context: context,
          builder: (ctx) => _buildDialog('An error occurred'),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => _buildDialog(result.toString()),
      );
    } catch (ex) {
      final message = ExceptionHandler(ex).message;

      showDialog(
        context: context,
        builder: (ctx) => _buildDialog(message),
      );
    }

    _setLoading(false);
  }

  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    setState(() {});
  }
}

class DataRequest {
  String baseApiUrl;
  String path;
  String optionalPath;
  String token;
  String queryParams;
  String bodyParams;

  DataRequest({
    required this.baseApiUrl,
    required this.path,
    required this.optionalPath,
    required this.token,
    required this.queryParams,
    required this.bodyParams,
  });

  Map<String, dynamic>? get convertQueryParamsToMap {
    if (queryParams.isEmpty) {
      return {};
    }
    try {
      return json
          .decode(queryParams.replaceAll("“", "\"").replaceAll("”", "\""));
    } catch (ex) {
      return null;
    }
  }

  Map<String, dynamic>? get convertBodyParamsToMap {
    if (bodyParams.isEmpty) {
      return {};
    }

    try {
      return json
          .decode(bodyParams.replaceAll("“", "\"").replaceAll("”", "\""));
    } catch (ex) {
      return null;
    }
  }

  String get validate {
    if (baseApiUrl.isEmpty) {
      return 'Base Url cannot be empty';
    }

    if (path.isEmpty) {
      return 'Path cannot be empty';
    }

    if (convertQueryParamsToMap == null) {
      return 'Query Params Invalid Json Format';
    }

    if (convertBodyParamsToMap == null) {
      return 'Body Params Invalid Json Format';
    }

    return '';
  }
}

class ExceptionHandler {
  final dynamic exception;
  ExceptionHandler(this.exception);

  String get message {
    if (exception is ServerException) {
      return ' Status Code: ${exception.code}, Message: ${exception.error.toString()}';
    }
    if (exception is TokenExpiredException) {
      return 'UnAuthorized';
    }
    if (exception is String) {
      return exception;
    }
    return 'An error occurred: ${exception.toString()}';
  }
}
