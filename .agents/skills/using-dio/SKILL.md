---
name: using-dio
description: Guide for using `dio` the powerful Dart HTTP package. Use this when working on HTTP requests.
---

This skill is adapt from the official `dio` documentation.

- Last updated: Sept 2026
- Source: https://github.com/cfug/dio/blob/main/dio/README.md

> Appendix:
>
> 1. [ReferCookieManager](./ReferCookieManager.md): Guide for using `dio_cookie_manager` plugin.

## Examples

### Performing a `GET` request

```dart
import 'package:dio/dio.dart';

final dio = Dio();

void request() async {
  Response response;
  response = await dio.get('/test?id=12&name=dio');
  print(response.data.toString());
  // The below request is the same as above.
  response = await dio.get(
    '/test',
    queryParameters: {'id': 12, 'name': 'dio'},
  );
  print(response.data.toString());
}
```

### Performing a `POST` request

```dart
response = await dio.post('/test', data: {'id': 12, 'name': 'dio'});
```

### Performing a `QUERY` request

The `QUERY` method (RFC 10008) is safe and idempotent like `GET`, but allows a
request body, which is useful for complex queries that do not fit in the URL.

```dart
response = await dio.query('/search', data: {'filter': {'name': 'dio'}});
```

### Downloading a file

```dart
response = await dio.download(
  'https://pub.dev/',
  (await getTemporaryDirectory()).path + 'pub.html',
);
```

### Get response stream

```dart
final rs = await dio.get(
  url,
  options: Options(responseType: ResponseType.stream), // Set the response type to `stream`.
);
print(rs.data.stream); // Response stream.
```

### Get response with bytes

```dart
final rs = await Dio().get<List<int>>(
  url,
  options: Options(responseType: ResponseType.bytes), // Set the response type to `bytes`.
);
print(rs.data); // Type: List<int>.
```

### Listening the uploading progress

```dart
final response = await dio.post(
  'https://www.dtworkroom.com/doris/1/2.0.0/test',
  data: {'aa': 'bb' * 22},
  onSendProgress: (int sent, int total) {
    print('$sent $total');
  },
);
```

### Post binary data with Stream

```dart
// Binary data
final postData = <int>[0, 1, 2];
await dio.post(
  url,
  data: Stream.fromIterable(postData.map((e) => [e])), // Creates a Stream<List<int>>.
  options: Options(
    headers: {
      Headers.contentLengthHeader: postData.length, // Set the content-length.
    },
  ),
);
```

## Dio APIs

### Creating an instance and set default configs

> It is recommended to use a singleton of `Dio` in projects, which can manage configurations like headers, base urls,
> and timeouts consistently.

You can create instance of Dio with an optional `BaseOptions` object:

```dart
final dio = Dio(); // With default `Options`.

void configureDio() {
  // Set default configs
  dio.options.baseUrl = 'https://api.pub.dev';
  dio.options.connectTimeout = Duration(seconds: 5);
  dio.options.receiveTimeout = Duration(seconds: 3);

  // Or create `Dio` with a `BaseOptions` instance.
  final options = BaseOptions(
    baseUrl: 'https://api.pub.dev',
    connectTimeout: Duration(seconds: 5),
    receiveTimeout: Duration(seconds: 3),
  );
  final anotherDio = Dio(options);

  // Or clone the existing `Dio` instance with all fields.
  final clonedDio = dio.clone();
}
```

The core API in Dio instance is:

```dart
Future<Response<T>> request<T>(
  String path, {
  Object? data,
  Map<String, dynamic>? queryParameters,
  CancelToken? cancelToken,
  Options? options,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
});
```

```dart
final response = await dio.request(
  '/test',
  data: {'id': 12, 'name': 'dio'},
  options: Options(method: 'GET'),
);
```

### Request Options

There are two request options concepts in the Dio library:
`BaseOptions` and `Options`.
The `BaseOptions` include a set of base settings for each `Dio()`,
and the `Options` describes the configuration for a single request.
These options will be merged when making requests.
The `Options` declaration is as follows:

```dart
/// The HTTP request method.
String method;

/// Timeout when sending data.
///
/// Throws the [DioException] with
/// [DioExceptionType.sendTimeout] type when timed out.
///
/// `null` or `Duration.zero` means no timeout limit.
Duration? sendTimeout;

/// Timeout when receiving data.
///
/// The timeout represents:
///  - a timeout before the connection is established
///    and the first received response bytes.
///  - the duration during data transfer of each byte event,
///    rather than the total duration of the receiving.
///
/// Throws the [DioException] with
/// [DioExceptionType.receiveTimeout] type when timed out.
///
/// `null` or `Duration.zero` means no timeout limit.
Duration? receiveTimeout;

/// Timeout when transforming response data.
///
/// Throws the [DioException] with
/// [DioExceptionType.transformTimeout] type when timed out.
/// On web, timeout handling is best-effort because synchronous JavaScript
/// work cannot be preempted.
///
/// `null` or `Duration.zero` means no timeout limit.
Duration? transformTimeout;

/// Custom field that you can retrieve it later in [Interceptor],
/// [Transformer] and the [Response.requestOptions] object.
Map<String, dynamic>? extra;

/// HTTP request headers.
///
/// The keys of the header are case-insensitive,
/// e.g.: `content-type` and `Content-Type` will be treated as the same key.
Map<String, dynamic>? headers;

/// Whether the case of header keys should be preserved.
///
/// Defaults to false.
///
/// This option WILL NOT take effect on these circumstances:
/// - XHR ([HttpRequest]) does not support handling this explicitly.
/// - The HTTP/2 standard only supports lowercase header keys.
bool? preserveHeaderCase;

/// The type of data that [Dio] handles with options.
///
/// The default value is [ResponseType.json].
/// [Dio] will parse response string to JSON object automatically
/// when the content-type of response is [Headers.jsonContentType].
///
/// See also:
///  - `plain` if you want to receive the data as `String`.
///  - `bytes` if you want to receive the data as the complete bytes.
///  - `stream` if you want to receive the data as streamed binary bytes.
ResponseType? responseType;

/// The request content-type.
///
/// The default `content-type` for requests will be implied by the
/// [ImplyContentTypeInterceptor] according to the type of the request payload.
/// The interceptor can be removed by
/// [Interceptors.removeImplyContentTypeInterceptor].
String? contentType;

/// Defines whether the request is considered to be successful
/// with the given status code.
/// The request will be treated as succeed if the callback returns true.
ValidateStatus? validateStatus;

/// Whether to retrieve the data if status code indicates a failed request.
///
/// Defaults to true.
bool? receiveDataWhenStatusError;

/// See [HttpClientRequest.followRedirects].
///
/// Defaults to true.
bool? followRedirects;

/// The maximum number of redirects when [followRedirects] is `true`.
/// [RedirectException] will be thrown if redirects exceeded the limit.
///
/// Defaults to 5.
int? maxRedirects;

/// See [HttpClientRequest.persistentConnection].
///
/// Defaults to true.
bool? persistentConnection;

/// The default request encoder is [Utf8Encoder], you can set custom
/// encoder by this option.
RequestEncoder? requestEncoder;

/// The default response decoder is [Utf8Decoder], you can set custom
/// decoder by this option, it will be used in [Transformer].
ResponseDecoder? responseDecoder;

/// Indicates the format of collection data in request query parameters and
/// `x-www-url-encoded` body data.
///
/// Defaults to [ListFormat.multi].
ListFormat? listFormat;
```

### Response

The response for a request contains the following information.

```dart
/// Response body. may have been transformed, please refer to [ResponseType].
T? data;

/// The corresponding request info.
RequestOptions requestOptions;

/// HTTP status code.
int? statusCode;

/// Returns the reason phrase associated with the status code.
/// The reason phrase must be set before the body is written
/// to. Setting the reason phrase after writing to the body.
String? statusMessage;

/// Whether this response is a redirect.
/// ** Attention **: Whether this field is available depends on whether the
/// implementation of the adapter supports it or not.
bool isRedirect;

/// The series of redirects this connection has been through. The list will be
/// empty if no redirects were followed. [redirects] will be updated both
/// in the case of an automatic and a manual redirect.
///
/// ** Attention **: Whether this field is available depends on whether the
/// implementation of the adapter supports it or not.
List<RedirectRecord> redirects;

/// Custom fields that only for the [Response].
Map<String, dynamic> extra;

/// Response headers.
Headers headers;
```

When request is succeed, you will receive the response as follows:

```dart
final response = await dio.get('https://pub.dev');
print(response.data);
print(response.headers);
print(response.requestOptions);
print(response.statusCode);
```

Be aware, the `Response.extra` is different from `RequestOptions.extra`,
they are not related to each other.

### Interceptors

For each dio instance, we can add one or more interceptors,
by which we can intercept requests, responses, and errors
before they are handled by `then` or `catchError`.

```dart
dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
      // Do something before request is sent.
      // If you want to resolve the request with custom data,
      // you can resolve a `Response` using `handler.resolve(response)`.
      // If you want to reject the request with a error message,
      // you can reject with a `DioException` using `handler.reject(dioError)`.
      return handler.next(options);
    },
    onResponse: (Response response, ResponseInterceptorHandler handler) {
      // Do something with response data.
      // If you want to reject the request with a error message,
      // you can reject a `DioException` object using `handler.reject(dioError)`.
      return handler.next(response);
    },
    onError: (DioException error, ErrorInterceptorHandler handler) {
      // Do something with response error.
      // If you want to resolve the request with some custom data,
      // you can resolve a `Response` object using `handler.resolve(response)`.
      return handler.next(error);
    },
  ),
);
```

Simple interceptor example:

```dart
import 'package:dio/dio.dart';
class CustomInterceptors extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('REQUEST[${options.method}] => PATH: ${options.path}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
    super.onResponse(response, handler);
  }

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    print('ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
    super.onError(err, handler);
  }
}
```

#### Resolve and reject the request

In all interceptors, you can interfere with their execution flow.
If you want to resolve the request/response with some custom data,
you can call `handler.resolve(Response)`.
If you want to reject the request/response with a error message,
you can call `handler.reject(dioError)` .

```dart
dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      return handler.resolve(
        Response(requestOptions: options, data: 'fake data'),
      );
    },
  ),
);
final response = await dio.get('/test');
print(response.data); // 'fake data'
```

#### LogInterceptor

You can apply the `LogInterceptor` to log requests and responses automatically.

**Note:** `LogInterceptor` should always be the last interceptor added,
otherwise modifications by following interceptors will not be logged.

##### Dart

```dart
dio.interceptors.add(LogInterceptor(responseBody: false)); // Do not output responses body.
```

**Note:** When using the default `logPrint` function, logs will only be printed
in DEBUG mode (when the assertion is enabled).

Alternatively `dart:developer`'s log can also be used to log messages (available in Flutter too).

##### Flutter

When using Flutter, Flutters own `debugPrint` function should be used.

This ensures, that debug messages are also available via `flutter logs`.

**Note:** `debugPrint` **does not mean print logs under the DEBUG mode**,
it's a throttled function which helps to print full logs without truncation.
Do not use it under any production environment unless you're intended to.

```dart
dio.interceptors.add(
  LogInterceptor(
    logPrint: (o) => debugPrint(o.toString()),
  ),
);
```

### Handling Errors

When an error occurs, Dio will wrap the `Error/Exception` to a `DioException`:

```dart
try {
  // 404
  await dio.get('https://api.pub.dev/not-exist');
} on DioException catch (e) {
  // The request was made and the server responded with a status code
  // that falls out of the range of 2xx and is also not 304.
  if (e.response != null) {
    print(e.response.data)
    print(e.response.headers)
    print(e.response.requestOptions)
  } else {
    // Something happened in setting up or sending the request that triggered an Error
    print(e.requestOptions)
    print(e.message)
  }
}
```

#### DioException

```dart
/// The request info for the request that throws exception.
RequestOptions requestOptions;

/// Response info, it may be `null` if the request can't reach to the
/// HTTP server, for example, occurring a DNS error, network is not available.
Response? response;

/// The type of the current [DioException].
DioExceptionType type;

/// The original error/exception object;
/// It's usually not null when `type` is [DioExceptionType.unknown].
Object? error;

/// The stacktrace of the original error/exception object;
/// It's usually not null when `type` is [DioExceptionType.unknown].
StackTrace? stackTrace;

/// The error message that throws a [DioException].
String? message;
```

## Misc

### Using application/x-www-form-urlencoded format

By default, Dio serializes request data (except `String` type) to `JSON`.
To send data in the `application/x-www-form-urlencoded` format instead:

```dart
// Instance level
dio.options.contentType = Headers.formUrlEncodedContentType;
// or only works once
dio.post(
  '/info',
  data: {'id': 5},
  options: Options(contentType: Headers.formUrlEncodedContentType),
);
```

### Sending FormData

You can also send `FormData` with Dio, which will send data in the `multipart/form-data`,
and it supports uploading files.

```dart
final formData = FormData.fromMap({
  'name': 'dio',
  'date': DateTime.now().toIso8601String(),
  'file': await MultipartFile.fromFile('./text.txt', filename: 'upload.txt'),
});
final response = await dio.post('/info', data: formData);
```

You can also specify your desired boundary name which will be used
to construct boundaries of every `FormData` with additional prefix and suffix.

```dart
final formDataWithBoundaryName = FormData(
  boundaryName: 'my-boundary-name',
);
```

> `FormData` is supported with the POST method typically.

#### Multiple files upload

There are two ways to add multiple files to `FormData`,
the only difference is that upload keys are different for array types。

```dart
final formData = FormData.fromMap({
  'files': [
    MultipartFile.fromFileSync('path/to/upload1.txt', filename: 'upload1.txt'),
    MultipartFile.fromFileSync('path/to/upload2.txt', filename: 'upload2.txt'),
  ],
});
```

The upload key eventually becomes `files[]`.
This is because many back-end services add a middle bracket to key
when they get an array of files.
**If you don't want a list literal**,
you should create FormData as follows (Don't use `FormData.fromMap`):

```dart
final formData = FormData();
formData.files.addAll([
  MapEntry(
   'files',
    MultipartFile.fromFileSync('./example/upload.txt',filename: 'upload.txt'),
  ),
  MapEntry(
    'files',
    MultipartFile.fromFileSync('./example/upload.txt',filename: 'upload.txt'),
  ),
]);
```

#### Reuse `FormData`s and `MultipartFile`s

You should make a new `FormData` or `MultipartFile` every time in repeated requests.
A typical wrong behavior is setting the `FormData` as a variable and using it in every request.
It can be easy for the _Cannot finalize_ exceptions to occur.
To avoid that, write your requests like the below code:

```dart
Future<void> _repeatedlyRequest() async {
  Future<FormData> createFormData() async {
    return FormData.fromMap({
      'name': 'dio',
      'date': DateTime.now().toIso8601String(),
      'file': await MultipartFile.fromFile('./text.txt',filename: 'upload.txt'),
    });
  }

  await dio.post('some-url', data: await createFormData());
}
```

### HttpClientAdapter

`HttpClientAdapter` is a bridge between `Dio` and `HttpClient`.

`Dio` implements standard and friendly APIs for developer.
`HttpClient` is the real object that makes Http requests.

We can use any `HttpClient` not just `dart:io:HttpClient` to make HTTP requests.
And all we need is providing a `HttpClientAdapter`.
The default `HttpClientAdapter` for Dio is `IOHttpClientAdapter` on native platforms,
and `BrowserHttpClientAdapter` on the Web platform.
They can be initiated by calling the `HttpClientAdapter()`.

```dart
dio.httpClientAdapter = HttpClientAdapter();
```

### Cancellation

You can cancel a request using a `CancelToken`.
One token can be shared with multiple requests.
When a token's `cancel()` is invoked, all requests with this token will be cancelled.

```dart
final cancelToken = CancelToken();
dio.get(url, cancelToken: cancelToken).catchError((DioException error) {
  if (CancelToken.isCancel(error)) {
    print('Request canceled: ${error.message}');
  } else {
    // handle error.
  }
});
// Cancel the requests with "cancelled" message.
token.cancel('cancelled');
```
