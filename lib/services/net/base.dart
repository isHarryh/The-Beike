import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '/services/base.dart';
import '/services/net/exceptions.dart';
import '/types/net.dart';

abstract class BaseNetService extends ChangeNotifier with BaseService {
  NetDashboardSessionState? _cachedSessionState;

  // Methods need to be implemented:

  Future<NetDashboardSessionState> doGetSessionState();

  Future<void> doLogin({
    required String username,
    required String passwordMd5,
    required String checkCode,
    String? randomCode,
  });

  Future<void> doLogout();

  Future<Uint8List> getCodeImage();

  Future<NetUserInfo> getUser();

  Future<List<MacDevice>> getDeviceList();

  Future<void> doBindMac({
    required String macAddress,
    required String terminalName,
    required bool isDumbTerminal,
  });

  Future<void> doUnbindMac(String macAddress);

  Future<void> doRenameMac({
    required String macAddress,
    required String terminalName,
  });

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<void> changeConsumeProtect({int? maxConsume});

  Future<List<MonthlyBill>> getMonthPay({required int year});

  Future<Map<String, dynamic>> getUserOnlineLog({
    required DateTime startTime,
    required DateTime endTime,
  });

  Future<RealtimeUsage> getRealtimeUsage(
    String username, {
    required bool viaVpn,
  });

  // Methods that already implemented:

  @protected
  void updateSessionState(NetDashboardSessionState newState) {
    _cachedSessionState = newState;
    notifyListeners();
  }

  NetDashboardSessionState? get cachedSessionState => _cachedSessionState;

  Future<NetDashboardSessionState> getSessionState() async {
    try {
      final sessionState = await doGetSessionState();
      _cachedSessionState = sessionState;
      return sessionState;
    } on NetServiceException {
      rethrow;
    } catch (e) {
      throw NetServiceNetworkError('Failed to load session state', e);
    }
  }

  Future<void> login(
    String username,
    String password, {
    String? randomCode,
  }) async {
    try {
      setPending();
      if (_cachedSessionState == null) {
        throw const NetServiceException('Session state not initialized');
      }
      if (_cachedSessionState!.needRandomCode &&
          (randomCode == null || randomCode.isEmpty)) {
        throw const NetServiceException('Missing random code');
      }

      final passwordMd5 = md5.convert(utf8.encode(password)).toString();
      await doLogin(
        username: username,
        passwordMd5: passwordMd5,
        checkCode: _cachedSessionState!.checkCode,
        randomCode: randomCode,
      );
      setOnline();
    } on NetServiceException {
      setOffline();
      rethrow;
    } catch (e) {
      setError(e.toString());
      throw NetServiceNetworkError('Failed to login', e);
    }
  }

  Future<void> logout() async {
    try {
      await doLogout();
    } catch (e) {
      if (kDebugMode) {
        print('Net service logout error: $e');
      }
    } finally {
      _cachedSessionState = null;
      setOffline();
    }
  }

  Future<void> setMacBounded(String mac, {String terminalName = ''}) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    final normalizedMac = normalizeMac(mac);
    if (normalizedMac == null) {
      throw const NetServiceException('Invalid MAC address');
    }

    final allDevices = await getDeviceList();
    if (allDevices.any(
      (e) => e.mac.toUpperCase() == normalizedMac.toUpperCase(),
    )) {
      // Already bounded
      return;
    }

    await doBindMac(
      macAddress: normalizedMac,
      terminalName: terminalName,
      isDumbTerminal: false,
    );
  }

  Future<void> setMacUnbounded(String mac) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    final normalizedMac = normalizeMac(mac);
    if (normalizedMac == null) {
      throw const NetServiceException('Invalid MAC address');
    }

    await doUnbindMac(normalizedMac);
  }

  Future<void> renameMac(String mac, {required String terminalName}) async {
    if (isOffline) {
      throw const NetServiceOffline();
    }

    final normalizedMac = normalizeMac(mac);
    if (normalizedMac == null) {
      throw const NetServiceException('Invalid MAC address');
    }

    await doRenameMac(macAddress: normalizedMac, terminalName: terminalName);
  }

  @protected
  String? normalizeMac(String raw) {
    final filtered = raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (filtered.length != 12) {
      return null;
    }
    return filtered;
  }
}
