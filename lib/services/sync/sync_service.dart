import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '/services/sync/base.dart';
import '/services/sync/exceptions.dart';
import 'convert.dart';
import '/types/sync.dart';
import '/utils/meta_info.dart';

class SyncService extends BaseSyncService {
  late final Dio _dio;

  SyncService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        headers: {'User-Agent': MetaInfo.instance.userAgent},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  @override
  String get defaultBaseUrl => 'https://thebeike.cn/api';

  @override
  set baseUrl(String url) {
    super.baseUrl = url;
    _dio.options.baseUrl = url;
  }

  @override
  Future<List<Announcement>> getAnnouncements() async {
    final response = await _postClientRequest('announcement', {});

    if (response == null || response['contents'] == null) {
      return [];
    }

    final announcements = response['contents'] as List<dynamic>;
    return announcements
        .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReleaseInfo?> getRelease() async {
    Response response;

    try {
      response = await _dio.get('/release/version');
    } catch (e) {
      throw SyncServiceNetworkError('Network error: $e', e);
    }

    Map<String, dynamic>? responseData;

    try {
      responseData = response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      throw SyncServiceBadResponse('Invalid response format', e);
    }

    if (response.statusCode == 200) {
      if (responseData == null) return null;
      return ReleaseInfo.fromJson(responseData);
    } else {
      throw SyncServiceException(
        'Server error: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>?> _postClientRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    Response response;

    try {
      response = await _dio.post(
        '/client/$endpoint',
        data: body,
        options: Options(contentType: Headers.jsonContentType),
      );
    } catch (e) {
      throw SyncServiceNetworkError('Network error: $e', e);
    }

    int responseBusinessCode;
    Map<String, dynamic>? responseData;

    try {
      responseBusinessCode = response.data['code'] as int;
      responseData = response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      throw SyncServiceBadResponse('Invalid response format', e);
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return responseData;
    } else if (response.statusCode == 400) {
      throw SyncServiceBadRequest(
        getSyncErrorMessage(responseBusinessCode),
        responseBusinessCode,
      );
    } else if (response.statusCode == 401) {
      throw SyncServiceAuthError(
        getSyncErrorMessage(responseBusinessCode),
        responseBusinessCode,
      );
    } else {
      throw SyncServiceException(
        'Server error: ${response.statusCode}',
        response.statusCode,
      );
    }
  }

  @override
  Future<String> registerDevice({
    required String deviceOs,
    required String deviceName,
  }) async {
    final response = await _postClientRequest('device/register', {
      'deviceOs': deviceOs,
      'deviceName': deviceName,
    });

    setOnline();
    return response!['deviceId'] as String;
  }

  @override
  Future<String> createGroup({
    required String deviceId,
    required String byytCookie,
  }) async {
    final response = await _postClientRequest('sync/create', {
      'deviceId': deviceId,
      'byytCookie': byytCookie,
    });

    return response!['groupId'] as String;
  }

  @override
  Future<PairingInfo> openPairing({
    required String deviceId,
    required String groupId,
  }) async {
    final response = await _postClientRequest('sync/open', {
      'deviceId': deviceId,
      'groupId': groupId,
    });

    return PairingInfoExtension.parse(response!);
  }

  @override
  Future<void> closePairing({
    required String pairCode,
    required String groupId,
  }) async {
    await _postClientRequest('sync/close', {
      'pairCode': pairCode,
      'groupId': groupId,
    });
  }

  @override
  Future<List<DeviceInfo>> listDevices({
    required String groupId,
    String? deviceId,
  }) async {
    final body = {'groupId': groupId};
    if (deviceId != null) {
      body['deviceId'] = deviceId;
    }
    final response = await _postClientRequest('sync/list', body);

    final devices = response!['devices'] as List<dynamic>;
    return devices
        .map((d) => DeviceInfoExtension.parse(d as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JoinGroupResult> joinGroup({
    required String deviceId,
    required String pairCode,
  }) async {
    final response = await _postClientRequest('sync/join', {
      'deviceId': deviceId,
      'pairCode': pairCode,
    });

    return JoinGroupResultExtension.parse(response!);
  }

  @override
  Future<void> leaveGroup({
    required String deviceId,
    required String groupId,
  }) async {
    await _postClientRequest('sync/leave', {
      'deviceId': deviceId,
      'groupId': groupId,
    });
  }

  @override
  Future<Map<String, dynamic>?> update({
    required String deviceId,
    required String groupId,
    required Map<String, dynamic> config,
  }) async {
    List<int> bodyBytes;

    final jsonString = json.encode(config);
    bodyBytes = zlib.encode(utf8.encode(jsonString));

    Response response;
    try {
      response = await _dio.post(
        '/client/sync/update',
        queryParameters: {'deviceId': deviceId, 'groupId': groupId},
        data: bodyBytes,
        options: Options(
          contentType: 'application/octet-stream',
          headers: {'Content-Encoding': 'deflate'},
          responseType: ResponseType.bytes,
        ),
      );
    } catch (e) {
      recordSyncStatus(SyncStatusType.failure);
      throw SyncServiceNetworkError('Network error: $e', e);
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      if ((response.data as List<int>).isEmpty) {
        recordSyncStatus(SyncStatusType.success);
        return null;
      }
      try {
        final decodedBytes = zlib.decode(response.data as List<int>);
        final decodedString = utf8.decode(decodedBytes);
        final result = json.decode(decodedString) as Map<String, dynamic>;
        recordSyncStatus(SyncStatusType.success);
        return result;
      } catch (e) {
        recordSyncStatus(SyncStatusType.failure);
        throw SyncServiceBadResponse('Invalid response format', e);
      }
    } else {
      // Try to parse error from JSON if possible
      int responseBusinessCode = -1;
      try {
        final responseString = utf8.decode(response.data as List<int>);
        final responseJson =
            json.decode(responseString) as Map<String, dynamic>;
        responseBusinessCode = responseJson['code'] as int;
      } catch (_) {
        // Ignore if not JSON
      }

      final errorMsg = getSyncErrorMessage(responseBusinessCode);
      recordSyncStatus(SyncStatusType.failure);

      if (response.statusCode == 400) {
        throw SyncServiceBadRequest(errorMsg, responseBusinessCode);
      } else if (response.statusCode == 401) {
        throw SyncServiceAuthError(errorMsg, responseBusinessCode);
      } else {
        throw SyncServiceException(
          'Server error: ${response.statusCode}',
          response.statusCode,
        );
      }
    }
  }
}
