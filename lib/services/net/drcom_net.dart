import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/services/net/convert.dart';
import '/types/net.dart';
import '/services/net/base.dart';
import '/services/net/exceptions.dart';

class DrcomNetService extends BaseNetService {
  DrcomNetService({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get defaultBaseUrl => 'http://zifuwu.ustb.edu.cn:8080';
  // Alternative VPN URL:
  // 'https://vpn.ustb.edu.cn/http-8080/77726476706e69737468656265737421a2a713d275603c1e2858c7fb';

  final http.Client _client;
  String? _cookie;

  Map<String, String> _buildHeaders({bool includeFormContentType = false}) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    };
    if (includeFormContentType) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    if (_cookie != null && _cookie!.isNotEmpty) {
      headers['Cookie'] = _cookie!;
    }
    return headers;
  }

  void _updateCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      _cookie = setCookie.split(';').first;
    }
  }

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
    String? forceContentType,
    bool followRedirects = false,
  }) async {
    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
    final request = http.Request('GET', uri);
    request.headers.addAll(_buildHeaders());
    request.followRedirects = followRedirects;
    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (forceContentType != null) {
      response.headers["content-type"] = forceContentType;
    }
    return response;
  }

  Future<http.Response> _post(
    String path, {
    Map<String, String>? data,
    String? forceContentType,
    bool followRedirects = false,
  }) async {
    final uri = Uri.parse('$baseUrl/$path');
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders(includeFormContentType: data != null));
    if (data != null) {
      request.bodyFields = data;
    }
    request.followRedirects = followRedirects;
    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (forceContentType != null) {
      response.headers["content-type"] = forceContentType;
    }
    return response;
  }

  @override
  Future<NetDashboardSessionState> doGetSessionState() async {
    final response = await _get(
      'Self/login/',
      forceContentType: 'text/html; charset=utf-8',
    );
    NetServiceException.raiseForStatus(response.statusCode);
    _updateCookie(response);

    final sessionState = NetDashboardSessionStateExtension.parseFromHtml(
      response.body,
      _cookie ?? '',
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

    final response = await _post(
      'Self/login/verify',
      data: {
        'checkcode': checkCode,
        'account': username,
        'password': passwordMd5,
        'code': randomCode ?? '',
      },
    );

    // Check for redirect to dashboard (success) or back to login (failure)
    if (response.statusCode == 302) {
      final location = response.headers['location'] ?? '';
      if (location.contains('dashboard')) {
        _updateCookie(response);
        return;
      } else {
        throw const NetServiceBadResponse(
          'Login failed: redirected to login page',
        );
      }
    }

    NetServiceException.raiseForStatus(response.statusCode, setOffline);
    throw const NetServiceBadResponse('Unexpected login response');
  }

  @override
  Future<void> doLogout() async {
    final response = await _get(
      'Self/login/logout',
      forceContentType: 'text/html; charset=utf-8',
    );
    // Expect 302 redirect to /Self/
    if (response.statusCode >= 400) {
      if (kDebugMode) {
        print('Net service logout failed: ${response.statusCode}');
      }
    }
    _cookie = null;
  }

  @override
  Future<Uint8List> getCodeImage() async {
    final response = await _get(
      'Self/login/randomCode',
      query: {'t': Random().nextDouble().toString()},
    );
    NetServiceException.raiseForStatus(response.statusCode);
    _updateCookie(response);
    return response.bodyBytes;
  }

  @override
  Future<NetUserInfo> getUser() async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      final response = await _get(
        'Self/dashboard',
        forceContentType: 'text/html; charset=utf-8',
      );
      NetServiceException.raiseForStatus(response.statusCode, setOffline);
      _updateCookie(response);

      await refreshCsrfFrom('Self/dashboard');

      return NetUserInfoExtension.parseFromHtml(response.body);
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

    final response = await _post(
      'Self/service/bindMac',
      data: {
        'macAddress': macAddress.toUpperCase(),
        'terminalName': terminalName,
        'terminalType': isDumbTerminal ? '1' : '0',
      },
      forceContentType: 'application/json; charset=utf-8',
    );
    NetServiceException.raiseForStatus(response.statusCode, setOffline);

    try {
      final decoded = json.decode(response.body);
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

    final response = await _get(
      'Self/service/unbindmac',
      query: {'mac': macAddress.toUpperCase(), 'ajaxCsrfToken': csrfToken},
    );
    // Expect 302 redirect to /Self/service/myMac
    if (response.statusCode == 302) {
      final location = response.headers['location'] ?? '';
      if (location.contains('myMac')) {
        return;
      }
    }
    NetServiceException.raiseForStatus(response.statusCode, setOffline);
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

    final response = await _post(
      'Self/service/updateTerminalName',
      data: {
        't': Random().nextDouble().toString(),
        'macAddress': macAddress.toUpperCase(),
        'terminalName': terminalName,
        'ajaxCsrfToken': csrfToken,
      },
    );
    NetServiceException.raiseForStatus(response.statusCode, setOffline);
    _updateCookie(response);

    try {
      final jsonMap = json.decode(response.body);
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

    final response = await _get(
      'Self/service/getMacList',
      query: {
        'pageSize': '100', // Fetch enough to cover most users
        'pageNumber': '1',
        'sortName': '2',
        'sortOrder': 'desc',
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      forceContentType: 'application/json; charset=utf-8',
    );
    NetServiceException.raiseForStatus(response.statusCode, setOffline);
    _updateCookie(response);

    try {
      final jsonMap = json.decode(response.body);
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
      final response = await _get(
        'Self/bill/getMonthPay',
        query: {
          't': Random().nextDouble().toString(),
          'pageSize': '100',
          'pageNumber': '1',
          'sortName': '0',
          'sortOrder': 'desc',
          'year': year.toString(),
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        forceContentType: 'application/json; charset=utf-8',
      );
      NetServiceException.raiseForStatus(response.statusCode, setOffline);
      _updateCookie(response);
      final jsonData = json.decode(response.body);
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

      final response = await _get(
        'Self/bill/getUserOnlineLog',
        query: {
          't': Random().nextDouble().toStringAsFixed(6),
          'pageSize': '100',
          'pageNumber': '1',
          'sortName': 'loginTime',
          'sortOrder': 'desc',
          'startTime': startStr,
          'endTime': endStr,
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        forceContentType: 'application/json; charset=utf-8',
      );
      NetServiceException.raiseForStatus(response.statusCode, setOffline);
      _updateCookie(response);
      return json.decode(response.body) as Map<String, dynamic>;
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load user online log', e);
    }
  }

  @override
  Future<void> doChangePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }
    await refreshCsrfFrom('Self/setting/changePassword');

    final csrfToken = NetDashboardSessionStateExtension.getCsrf(
      cachedSessionState!,
      'changePasswordForm',
    );

    final response = await _post(
      'Self/v2/password',
      data: {
        'csrftoken': csrfToken,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmPassword': newPassword,
      },
      forceContentType: 'application/json; charset=utf-8',
    );
    NetServiceException.raiseForStatus(response.statusCode, setOffline);

    try {
      final decoded = json.decode(response.body);
      if (decoded['state'] != 'success') {
        throw NetServiceBadResponse(
          '${decoded['data'] ?? 'Unknown error while changing password'}',
        );
      }
    } catch (e) {
      if (e is NetServiceException) rethrow;
      throw NetServiceBadResponse(
        'Failed to parse password change response',
        e,
      );
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
      final uri = Uri.parse(
        '$base/eportal/portal/visitor/loadUserFlow'
        '?callback=dr1003'
        '&account=$username'
        '&jsVersion=4.1'
        '&v=$randomNum'
        '&lang=zh',
      );

      final response = await _client.get(uri, headers: _buildHeaders());
      NetServiceException.raiseForStatus(response.statusCode);
      return RealtimeUsageExtension.parse(response.body);
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load realtime usage', e);
    }
  }

  void dispose() {
    _client.close();
  }

  Future<void> refreshCsrfFrom(String path) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    try {
      final response = await _get(
        path,
        forceContentType: 'text/html; charset=utf-8',
      );
      NetServiceException.raiseForStatus(response.statusCode, setOffline);
      _updateCookie(response);

      if (cachedSessionState != null) {
        final updatedState = NetDashboardSessionStateExtension.updateCsrf(
          cachedSessionState!,
          response.body,
        );
        updateSessionState(updatedState);

        try {
          final refreshAccountToken = NetDashboardSessionStateExtension.getCsrf(
            cachedSessionState!,
            'Self/dashboard/refreshaccount',
          );

          final response = await _get(
            'Self/dashboard/refreshaccount',
            query: {
              'csrftoken': refreshAccountToken,
              't': Random().nextDouble().toString(),
            },
          );
          NetServiceException.raiseForStatus(response.statusCode, setOffline);
          _updateCookie(response);

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
