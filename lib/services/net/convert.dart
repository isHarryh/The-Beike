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

extension RealtimeUsageExtension on RealtimeUsage {
  static final v4Regex = RegExp(r'"v4"\s*:\s*([\d.]+)', caseSensitive: false);
  static final v6Regex = RegExp(r'"v6"\s*:\s*([\d.]+)', caseSensitive: false);

  static RealtimeUsage parse(String jsStr) {
    final v4Match = v4Regex.firstMatch(jsStr);
    final v6Match = v6Regex.firstMatch(jsStr);

    final v4Str = v4Match?.group(1)?.trim();
    final v6Str = v6Match?.group(1)?.trim();

    if (v4Str == null || v4Str.isEmpty) {
      throw const NetServiceException('Failed to parse v4 usage');
    }
    if (v6Str == null || v6Str.isEmpty) {
      throw const NetServiceException('Failed to parse v6 usage');
    }

    final v4 = double.tryParse(v4Str);
    final v6 = double.tryParse(v6Str);

    if (v4 == null || v6 == null) {
      throw const NetServiceException('Failed to parse usage values');
    }

    return RealtimeUsage(v4: v4, v6: v6, time: DateTime.now());
  }
}
