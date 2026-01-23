import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '/services/net/convert.dart';
import '/types/net.dart';
import '/services/net/base.dart';
import '/services/net/exceptions.dart';

class DrcomNetService extends BaseNetService {
  late final Dio _dio;
  late final CookieJar _cookieJar;

  DrcomNetService() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
        followRedirects: false,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  @override
  String get defaultBaseUrl => 'https://zifuwu.ustb.edu.cn';

  @override
  set baseUrl(String url) {
    super.baseUrl = url;
    _dio.options.baseUrl = url;
  }

  @override
  Future<NetDashboardSessionState> doGetSessionState() async {
    final response = await _dio.get(
      '/Self/login/',
      options: Options(responseType: ResponseType.plain),
    );
    NetServiceException.raiseForStatus(response.statusCode!);

    final sessionState = NetDashboardSessionStateExtension.parseFromHtml(
      response.data as String,
    );

    await getCodeImage(); // This request is to make the session valid
    return sessionState;
  }

  @override
  Future<void> doLogin({
    required String username,
    required String passwordMd5,
    required String checkCode,
    String? randomCode,
  }) async {
    if (username.isEmpty) {
      throw const NetServiceException('Missing username');
    }
    if (passwordMd5.isEmpty) {
      throw const NetServiceException('Missing password');
    }

    final response = await _dio.post(
      '/Self/login/verify',
      data: {
        'checkcode': checkCode,
        'account': username,
        'password': passwordMd5,
        'code': randomCode ?? '',
      },
    );

    // Check for redirect to dashboard (success) or back to login (failure)
    if (response.statusCode == 302) {
      final location = response.headers.value('location') ?? '';
      if (location.contains('dashboard')) {
        return;
      } else {
        throw const NetServiceBadResponse(
          'Login failed: redirected to login page',
        );
      }
    }

    NetServiceException.raiseForStatus(response.statusCode!, setOffline);
    throw const NetServiceBadResponse('Unexpected login response');
  }

  @override
  Future<void> doLogout() async {
    final response = await _dio.get(
      '/Self/login/logout',
      options: Options(responseType: ResponseType.plain),
    );
    // Expect 302 redirect to /Self/
    if (response.statusCode! >= 400) {
      if (kDebugMode) {
        print('Net service logout failed: ${response.statusCode}');
      }
    }
    await _cookieJar.deleteAll();
  }

  @override
  Future<Uint8List> getCodeImage() async {
    final response = await _dio.get(
      '/Self/login/randomCode',
      queryParameters: {'t': Random().nextDouble().toString()},
      options: Options(responseType: ResponseType.bytes),
    );
    NetServiceException.raiseForStatus(response.statusCode!);
    return response.data as Uint8List;
  }

  @override
  Future<NetUserInfo> getUser() async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      final response = await _dio.get(
        '/Self/dashboard',
        options: Options(responseType: ResponseType.plain),
      );
      NetServiceException.raiseForStatus(response.statusCode!, setOffline);

      await refreshCsrfFrom('Self/dashboard');

      return NetUserInfoExtension.parseFromHtml(response.data as String);
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load net user info', e);
    }
  }

  @override
  Future<void> doBindMac({
    required String macAddress,
    required String terminalName,
    required bool isDumbTerminal,
  }) async {
    await refreshCsrfFrom('Self/service/myMac');

    final response = await _dio.post(
      '/Self/service/bindMac',
      data: {
        'macAddress': macAddress.toUpperCase(),
        'terminalName': terminalName,
        'terminalType': isDumbTerminal ? '1' : '0',
      },
      options: Options(contentType: 'application/json; charset=utf-8'),
    );
    NetServiceException.raiseForStatus(response.statusCode!, setOffline);

    try {
      final decoded = response.data;
      if (decoded['state'] != 'success') {
        throw NetServiceBadResponse(
          'MAC binding failed: ${decoded['data'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      if (e is NetServiceException) rethrow;
      throw NetServiceBadResponse('Failed to parse MAC binding response', e);
    }
  }

  @override
  Future<void> doUnbindMac(String macAddress) async {
    await refreshCsrfFrom('Self/service/myMac');

    final csrfToken = NetDashboardSessionStateExtension.getCsrf(
      cachedSessionState!,
      'Self/service/unbindmac',
    );

    final response = await _dio.get(
      '/Self/service/unbindmac',
      queryParameters: {
        'mac': macAddress.toUpperCase(),
        'ajaxCsrfToken': csrfToken,
      },
    );
    // Expect 302 redirect to /Self/service/myMac
    if (response.statusCode == 302) {
      final location = response.headers.value('location') ?? '';
      if (location.contains('myMac')) {
        return;
      }
    }
    NetServiceException.raiseForStatus(response.statusCode!, setOffline);
  }

  @override
  Future<void> doRenameMac({
    required String macAddress,
    required String terminalName,
  }) async {
    await refreshCsrfFrom('Self/service/myMac');

    final csrfToken = NetDashboardSessionStateExtension.getCsrf(
      cachedSessionState!,
      'Self/service/updateTerminalName',
    );

    final response = await _dio.post(
      '/Self/service/updateTerminalName',
      data: {
        't': Random().nextDouble().toString(),
        'macAddress': macAddress.toUpperCase(),
        'terminalName': terminalName,
        'ajaxCsrfToken': csrfToken,
      },
    );
    NetServiceException.raiseForStatus(response.statusCode!, setOffline);

    try {
      final jsonMap = response.data;
      final state = jsonMap['state'];
      if (state != 'success') {
        throw NetServiceException('Failed to rename device: $state');
      }
    } catch (e) {
      if (e is NetServiceException) rethrow;
      throw NetServiceBadResponse('Failed to parse rename response', e);
    }
  }

  @override
  Future<List<MacDevice>> getDeviceList() async {
    await refreshCsrfFrom('Self/service/myMac');

    final response = await _dio.get(
      '/Self/service/getMacList',
      queryParameters: {
        'pageSize': '100', // Fetch enough to cover most users
        'pageNumber': '1',
        'sortName': '2',
        'sortOrder': 'desc',
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: Options(responseType: ResponseType.plain),
    );
    NetServiceException.raiseForStatus(response.statusCode!, setOffline);

    try {
      final jsonMap =
          json.decode(response.data as String) as Map<String, dynamic>;
      return MacDeviceExtension.parse(jsonMap);
    } catch (e) {
      throw NetServiceBadResponse('Failed to parse mac list', e);
    }
  }

  @override
  Future<List<MonthlyBill>> getMonthPay({required int year}) async {
    if (year <= 0) {
      throw const NetServiceException('Invalid year');
    }
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      final response = await _dio.get(
        '/Self/bill/getMonthPay',
        queryParameters: {
          't': Random().nextDouble().toString(),
          'pageSize': '100',
          'pageNumber': '1',
          'sortName': '0',
          'sortOrder': 'desc',
          'year': year.toString(),
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        options: Options(responseType: ResponseType.plain),
      );
      NetServiceException.raiseForStatus(response.statusCode!, setOffline);
      final jsonData =
          json.decode(response.data as String) as Map<String, dynamic>;
      return MonthlyBillExtension.parse(jsonData, year);
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load monthly bill', e);
    }
  }

  @override
  Future<Map<String, dynamic>> getUserOnlineLog({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      final startStr =
          '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
      final endStr =
          '${endTime.year}-${endTime.month.toString().padLeft(2, '0')}-${endTime.day.toString().padLeft(2, '0')}';

      final response = await _dio.get(
        '/Self/bill/getUserOnlineLog',
        queryParameters: {
          't': Random().nextDouble().toStringAsFixed(6),
          'pageSize': '100',
          'pageNumber': '1',
          'sortName': 'loginTime',
          'sortOrder': 'desc',
          'startTime': startStr,
          'endTime': endStr,
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      NetServiceException.raiseForStatus(response.statusCode!, setOffline);
      return response.data as Map<String, dynamic>;
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load user online log', e);
    }
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      await refreshCsrfFrom('Self/setting/changePassword');

      final csrfToken = NetDashboardSessionStateExtension.getCsrf(
        cachedSessionState!,
        'changePasswordForm',
      );

      final response = await _dio.post(
        '/Self/v2/password',
        data: {
          'csrftoken': csrfToken,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmPassword': newPassword,
        },
        options: Options(contentType: 'application/json; charset=utf-8'),
      );
      NetServiceException.raiseForStatus(response.statusCode!, setOffline);

      final decoded = response.data;
      if (decoded['state'] != 'success') {
        throw NetServiceBadResponse(
          '${decoded['data'] ?? 'Unknown error while changing password'}',
        );
      }
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to change password', e);
    }
  }

  @override
  Future<void> changeConsumeProtect({int? maxConsume}) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      await refreshCsrfFrom('Self/service/consumeProtect');

      final csrfToken = NetDashboardSessionStateExtension.getCsrf(
        cachedSessionState!,
        'form',
      );

      maxConsume ??= 999999;
      maxConsume = maxConsume.clamp(0, 999999);

      final response = await _dio.post(
        '/Self/service/changeConsumeProtect',
        data: {'csrftoken': csrfToken, 'consumeLimit': maxConsume.toString()},
      );
      // Expect 302 redirect to /Self/service/consumeProtect
      if (response.statusCode == 302) {
        final location = response.headers.value('location') ?? '';
        if (location.contains('consumeProtect')) {
          return;
        }
      }
      NetServiceException.raiseForStatus(response.statusCode!, setOffline);
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to change consume protect', e);
    }
  }

  @override
  Future<RealtimeUsage> getRealtimeUsage(
    String username, {
    required bool viaVpn,
  }) async {
    try {
      const usageServerUrl = 'http://202.204.48.82:801';
      const usageServerElib =
          'https://elib.ustb.edu.cn/http-801/77726476706e69737468656265737421a2a713d275603c1e2a50c7face';
      final randomNum = Random().nextInt(1000000).toString();
      final base = viaVpn ? usageServerElib : usageServerUrl;

      // Use a separate Dio instance for this external service
      final usageDio = Dio();
      final response = await usageDio.get(
        '$base/eportal/portal/visitor/loadUserFlow'
        '?callback=dr1003'
        '&account=$username'
        '&jsVersion=4.1'
        '&v=$randomNum'
        '&lang=zh',
        options: Options(responseType: ResponseType.plain),
      );
      NetServiceException.raiseForStatus(response.statusCode!);
      return RealtimeUsageExtension.parse(response.data as String);
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load realtime usage', e);
    }
  }

  Future<void> refreshCsrfFrom(String path) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      final response = await _dio.get(
        '/$path',
        options: Options(responseType: ResponseType.plain),
      );
      NetServiceException.raiseForStatus(response.statusCode!, setOffline);

      if (cachedSessionState != null) {
        final updatedState = NetDashboardSessionStateExtension.updateCsrf(
          cachedSessionState!,
          response.data as String,
        );
        updateSessionState(updatedState);

        try {
          final refreshAccountToken = NetDashboardSessionStateExtension.getCsrf(
            cachedSessionState!,
            'Self/dashboard/refreshaccount',
          );

          final response = await _dio.get(
            '/Self/dashboard/refreshaccount',
            queryParameters: {
              'csrftoken': refreshAccountToken,
              't': Random().nextDouble().toString(),
            },
          );
          NetServiceException.raiseForStatus(response.statusCode!, setOffline);

          if (kDebugMode) {
            print("Net dashboard CSRF token refreshed for $path");
          }
        } catch (_) {
          // ignored
        }
      }
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to refresh CSRF token', e);
    }
  }
}
