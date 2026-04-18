import 'dart:convert';
import 'package:flutter/foundation.dart';
import '/services/net/exceptions.dart';
import '/types/net.dart';

extension NetDashboardSessionStateExtension on NetDashboardSessionState {
  static final RegExp checkCodeRegex = RegExp(
    // Match an <input> tag that contains name="checkcode" and type="hidden",
    r'''<input\b(?=[^>]*\bname\s*=\s*['"]checkcode['"])(?=[^>]*\btype\s*=\s*['"]hidden['"])[^>]*\bvalue\s*=\s*['"]([^'"]+)['"]''',
    caseSensitive: false,
  );

  static final RegExp randomDivRegex = RegExp(
    // Match a <div> with id="randomDiv" and optionally capture its class attribute.
    r'''<div\b(?=[^>]*\bid\s*=\s*['"]randomDiv['"])(?:[^>]*\bclass\s*=\s*['"]([^'"]*)['"])?[^>]*>''',
    caseSensitive: false,
  );

  // Csrf Pattern 1: JQuery Ajax
  static final RegExp csrfAjaxPattern = RegExp(
    r'''\$\.(?:(?:ajax)|(?:get))\s*\([^'"]*['"]([^'"]+)['"][^}]*(?:(?:csrftoken)|(?:ajaxCsrfToken))\s*:\s*['"]([^'"]+)['"]''',
    caseSensitive: false,
    dotAll: true,
  );

  // Csrf Pattern 2: Window location redirection
  static final RegExp csrfLocationPattern = RegExp(
    r'''window\.location\.href\s*=\s*['"]([^'"?]+)\?.*ajaxCsrfToken=(?:['"]\s*\+\s*['"])?([\w-]+)['"]''',
    caseSensitive: false,
    dotAll: true,
  );

  // Csrf Pattern 3: Form field
  static final RegExp csrfFormPattern = RegExp(
    r'''<form[^]+id=['"]([^'"]+)['"][^]*>[^]*<input[^]+name=['"]csrftoken['"][^]+value=['"]([^'"]+)['"][^<]*>''',
    caseSensitive: false,
    dotAll: true,
  );

  static NetDashboardSessionState parseFromHtml(String html) {
    final checkCodeMatch = checkCodeRegex.firstMatch(html);
    final checkCode = checkCodeMatch?.group(1)?.trim();

    if (checkCode == null || checkCode.isEmpty) {
      throw const NetServiceException('Failed to parse check code');
    }

    // If randomDiv has class "hide", then random code is not needed
    final randomDivMatch = randomDivRegex.firstMatch(html);
    final needRandomCode =
        randomDivMatch != null && !randomDivMatch.group(0)!.contains('hide');

    return NetDashboardSessionState(
      checkCode: checkCode,
      needRandomCode: needRandomCode,
    );
  }

  static NetDashboardSessionState updateCsrf(
    NetDashboardSessionState state,
    String html,
  ) {
    final newTokens = Map<String, String>.from(state.csrfTokens);

    final csrfPatterns = [
      csrfAjaxPattern,
      csrfLocationPattern,
      csrfFormPattern,
    ];

    for (final pattern in csrfPatterns) {
      for (final match in pattern.allMatches(html)) {
        final key = match.group(1)?.trim();
        final token = match.group(2)?.trim();
        if (key != null &&
            key.isNotEmpty &&
            token != null &&
            token.isNotEmpty) {
          newTokens[key] = token;
        }
      }
    }

    if (newTokens.isEmpty && state.csrfTokens.isEmpty) {
      return state;
    }

    return NetDashboardSessionState(
      checkCode: state.checkCode,
      needRandomCode: state.needRandomCode,
      csrfTokens: newTokens,
    );
  }

  static String getCsrf(NetDashboardSessionState state, path) {
    for (final entry in state.csrfTokens.entries) {
      if (entry.key.endsWith(path)) {
        return entry.value;
      }
    }
    throw NetServiceException("CSRF token missing");
  }
}

extension NetUserInfoExtension on NetUserInfo {
  static final RegExp _userInfoRegex = RegExp(
    r'window\.user\s*=\s*user\s*\|\|\s*\{\};\s*\}\)\((\{.*?\})\);',
    dotAll: true,
  );

  static NetUserInfo parseFromHtml(String html) {
    final match = _userInfoRegex.firstMatch(html);
    if (match == null) {
      throw const NetServiceException('Failed to find user info in dashboard');
    }

    final jsonStr = match.group(1);
    if (jsonStr == null) {
      throw const NetServiceException(
        'Failed to extract user info JSON from dashboard',
      );
    }

    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      // Parse userGroup if present
      NetUserPlan? plan;
      final userGroupJson = json['userGroup'] as Map<String, dynamic>?;
      if (userGroupJson != null) {
        plan = NetUserPlan(
          planId: userGroupJson['userGroupId'] as int,
          planName: userGroupJson['userGroupName'] as String,
          planDescription: userGroupJson['userGroupDescription'] as String,
          freeFlow: (userGroupJson['flowStart'] as num).toDouble(),
          unitFlowCost: (userGroupJson['flowRate'] as num).toDouble(),
          maxLogins: userGroupJson['ipMaxCount'] as int,
        );
      }

      // Parse maxConsume from installmentFlag
      int? maxConsume;
      final installmentFlag = json['installmentFlag'] as int?;
      if (installmentFlag != null &&
          0 <= installmentFlag &&
          installmentFlag < 999999) {
        maxConsume = installmentFlag;
      }

      return NetUserInfo(
        realName: json['userRealName'] as String,
        accountName: json['userName'] as String,
        bandwidthDown: json['downloadBand'] as int?,
        bandwidthUp: json['uploadBand'] as int?,
        internetDownFlow: (json['internetDownFlow'] as num).toDouble(),
        internetUpFlow: (json['internetUpFlow'] as num).toDouble(),
        flowLeft: (json['leftFlow'] as num).toDouble(),
        flowUsed: (json['useFlow'] as num).toDouble(),
        moneyLeft: (json['leftMoney'] as num).toDouble(),
        moneyUsed: (json['useMoney'] as num).toDouble(),
        plan: plan,
        maxConsume: maxConsume,
      );
    } catch (e) {
      throw NetServiceException('Failed to parse user info JSON: $e');
    }
  }
}

extension MacDeviceExtension on MacDevice {
  static List<MacDevice> parse(Map<String, dynamic> json) {
    final devices = <MacDevice>[];
    final rows = json['rows'] as List<dynamic>? ?? [];

    for (final row in rows) {
      if (row is! List || row.length < 7) {
        continue;
      }

      final isOnline = row[0].toString() == '1';
      final mac = row[1].toString();
      final lastOnlineTime = row[3] == null ? "-" : row[3].toString();
      final lastOnlineIp = row[4] == null ? "-" : row[4].toString();
      final isDumbDevice = row[5].toString() == '是';
      final name = row[6] == null ? '' : row[6].toString();

      devices.add(
        MacDevice(
          name: name,
          mac: mac,
          isOnline: isOnline,
          lastOnlineTime: lastOnlineTime,
          lastOnlineIp: lastOnlineIp,
          isDumbDevice: isDumbDevice,
        ),
      );
    }

    return devices;
  }
}

extension MonthlyBillExtension on MonthlyBill {
  static List<MonthlyBill> parse(Map<String, dynamic> json, int year) {
    final bills = <MonthlyBill>[];
    final rows = json['rows'] as List<dynamic>? ?? [];

    for (final row in rows) {
      if (row is! List || row.length < 8) {
        continue;
      }

      try {
        final startDate = DateTime.fromMillisecondsSinceEpoch(row[0] as int);
        final endDate = DateTime.fromMillisecondsSinceEpoch(row[1] as int);
        final packageName = row[2] as String;
        final monthlyFee = (row[3] as num).toDouble();
        final usageFee = (row[4] as num).toDouble();
        final durationMinutes = (row[5] as num).toDouble();
        final flowMb = (row[6] as num).toDouble();
        final createTime = DateTime.fromMillisecondsSinceEpoch(row[7] as int);

        bills.add(
          MonthlyBill(
            startDate: startDate,
            endDate: endDate,
            packageName: packageName,
            monthlyFee: monthlyFee,
            usageFee: usageFee,
            usageDurationMinutes: durationMinutes,
            usageFlowMb: flowMb,
            createTime: createTime,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to parse monthly bill row: $e');
        }
      }
    }

    return bills;
  }
}

extension NetOnlineSessionExtension on NetOnlineSession {
  static List<NetOnlineSession> parse(dynamic jsonData) {
    if (jsonData is! List) {
      throw const NetServiceBadResponse('Invalid online session payload');
    }

    final sessions = <NetOnlineSession>[];

    for (final row in jsonData) {
      if (row is! Map) {
        continue;
      }

      try {
        int? parseOptionalInt(dynamic value) {
          if (value == null) return null;
          return int.tryParse(value.toString());
        }

        double parseFlowInMb(dynamic value) {
          final parsed = double.tryParse(value.toString());
          if (parsed == null) {
            throw const NetServiceBadResponse('Invalid flow value');
          }
          return parsed / 1024.0;
        }

        int parseRequiredInt(dynamic value, String fieldName) {
          final parsed = int.tryParse(value.toString());
          if (parsed == null) {
            throw NetServiceBadResponse('Invalid $fieldName value');
          }
          return parsed;
        }

        final loginTimeRaw = row['loginTime']?.toString();
        final loginTime = loginTimeRaw == null
            ? null
            : DateTime.tryParse(loginTimeRaw);
        if (loginTime == null) {
          throw const NetServiceBadResponse('Invalid loginTime value');
        }

        sessions.add(
          NetOnlineSession(
            deviceName: row['hostName']?.toString() ?? '',
            ip: row['ip']?.toString() ?? '',
            mac: row['mac']?.toString() ?? '',
            sessionId: row['sessionId']?.toString(),
            terminalType: row['terminalType']?.toString(),
            downFlowMb: parseFlowInMb(row['downFlow']),
            upFlowMb: parseFlowInMb(row['upFlow']),
            loginTime: loginTime,
            useTimeMinutes: parseRequiredInt(row['useTime'], 'useTime') ~/ 60,
            brasId: parseOptionalInt(row['brasid']),
            userId: parseOptionalInt(row['userId']),
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to parse online session row: $e');
        }
      }
    }

    return sessions;
  }
}

extension NetLoginHistoryExtension on NetLoginHistory {
  static List<NetLoginHistory> parse(dynamic jsonData) {
    if (jsonData is! List) {
      throw const NetServiceBadResponse('Invalid login history payload');
    }

    final histories = <NetLoginHistory>[];

    for (final row in jsonData) {
      if (row is! List || row.length < 9) {
        continue;
      }

      try {
        final loginMs = row[0] is num ? (row[0] as num).toInt() : null;
        final logoutMs = row[1] is num ? (row[1] as num).toInt() : null;
        if (loginMs == null) {
          throw const NetServiceBadResponse('Invalid login timestamp');
        }

        final loginTime = DateTime.fromMillisecondsSinceEpoch(loginMs);
        final logoutTime = logoutMs == null || logoutMs <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(logoutMs);

        final usedTimeMinutes = row[4] is num
            ? (row[4] as num).toInt()
            : int.tryParse(row[4].toString()) ?? 0;
        final usedFlowMb = row[5] is num
            ? (row[5] as num).toDouble()
            : double.tryParse(row[5].toString()) ?? 0;

        final terminalType = row.length > 9
            ? (row[9]?.toString() ??
                  (row.length > 10 ? row[10]?.toString() : null))
            : null;

        histories.add(
          NetLoginHistory(
            deviceName: row[8]?.toString() ?? '',
            ip: row[2]?.toString() ?? '',
            mac: row[3]?.toString() ?? '',
            terminalType: terminalType,
            usedFlowMb: usedFlowMb,
            loginTime: loginTime,
            logoutTime: logoutTime,
            usedTimeMinutes: usedTimeMinutes,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to parse login history row: $e');
        }
      }
    }

    return histories;
  }
}
