import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import '/types/base.dart';

part 'net.g.dart';

/// Network connectivity status for topology display
enum NetworkStatus {
  /// No data available
  noData,

  /// Connected (has recent records within 2x request interval)
  connected,

  /// Disconnected (no recent records)
  disconnected,
}

extension NetworkStatusExtension on NetworkStatus {
  Color get color {
    switch (this) {
      case NetworkStatus.noData:
        return Colors.grey;
      case NetworkStatus.connected:
        return Colors.green;
      case NetworkStatus.disconnected:
        return Colors.red;
    }
  }

  String get label {
    switch (this) {
      case NetworkStatus.noData:
        return '无数据';
      case NetworkStatus.connected:
        return '连通';
      case NetworkStatus.disconnected:
        return '不连通';
    }
  }
}

@JsonSerializable()
class NetDashboardSessionState extends BaseDataClass {
  final String checkCode;
  final bool needRandomCode;
  final Map<String, String> csrfTokens;

  NetDashboardSessionState({
    required this.checkCode,
    required this.needRandomCode,
    Map<String, String>? csrfTokens,
  }) : csrfTokens = csrfTokens ?? {};

  @override
  Map<String, dynamic> getEssentials() {
    return {
      'checkCode': checkCode,
      'needRandomCode': needRandomCode,
      'csrfTokens': csrfTokens,
    };
  }

  factory NetDashboardSessionState.fromJson(Map<String, dynamic> json) =>
      _$NetDashboardSessionStateFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$NetDashboardSessionStateToJson(this);
}

class NetUserPlan extends BaseDataClass {
  final int planId;
  final String planName;
  final String planDescription;
  final double freeFlow;
  final double unitFlowCost;
  final int maxLogins;

  NetUserPlan({
    required this.planId,
    required this.planName,
    required this.planDescription,
    required this.freeFlow,
    required this.unitFlowCost,
    required this.maxLogins,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'planId': planId, 'planName': planName};
  }

  @override
  Map<String, dynamic> toJson() => getEssentials();
}

class NetUserInfo extends BaseDataClass {
  final String realName;
  final String accountName;

  final int? bandwidthDown;
  final int? bandwidthUp;

  final double internetDownFlow;
  final double internetUpFlow;

  final double flowLeft;
  final double flowUsed;

  final double moneyLeft;
  final double moneyUsed;

  final NetUserPlan? plan;
  final int? maxConsume;

  NetUserInfo({
    required this.realName,
    required this.accountName,
    this.bandwidthDown,
    this.bandwidthUp,
    required this.internetDownFlow,
    required this.internetUpFlow,
    required this.flowLeft,
    required this.flowUsed,
    required this.moneyLeft,
    required this.moneyUsed,
    this.plan,
    this.maxConsume,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {
      'realName': realName,
      'accountName': accountName,
      'flowLeft': flowLeft,
      'moneyLeft': moneyLeft,
      'maxConsume': maxConsume,
    };
  }

  @override
  Map<String, dynamic> toJson() => getEssentials();
}

@JsonSerializable()
class NetUserIntegratedData extends BaseDataClass {
  final String account;
  final String password;

  NetUserIntegratedData({required this.account, required this.password});

  @override
  Map<String, dynamic> getEssentials() {
    return {'account': account, 'password': password};
  }

  factory NetUserIntegratedData.fromJson(Map<String, dynamic> json) =>
      _$NetUserIntegratedDataFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$NetUserIntegratedDataToJson(this);
}

@JsonSerializable()
class MacDevice extends BaseDataClass {
  final String name;
  final String mac;
  final bool isOnline;
  final String lastOnlineTime;
  final String lastOnlineIp;
  final bool isDumbDevice;

  MacDevice({
    required this.name,
    required this.mac,
    required this.isOnline,
    required this.lastOnlineTime,
    required this.lastOnlineIp,
    required this.isDumbDevice,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {
      'name': name,
      'mac': mac,
      'isOnline': isOnline,
      'lastOnlineTime': lastOnlineTime,
      'lastOnlineIp': lastOnlineIp,
      'isDumbDevice': isDumbDevice,
    };
  }

  factory MacDevice.fromJson(Map<String, dynamic> json) =>
      _$MacDeviceFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MacDeviceToJson(this);
}

@JsonSerializable()
class MonthlyBill extends BaseDataClass {
  final DateTime startDate;
  final DateTime endDate;
  final String packageName;
  final double monthlyFee;
  final double usageFee;
  final double usageDurationMinutes;
  final double usageFlowMb;
  final DateTime createTime;

  MonthlyBill({
    required this.startDate,
    required this.endDate,
    required this.packageName,
    required this.monthlyFee,
    required this.usageFee,
    required this.usageDurationMinutes,
    required this.usageFlowMb,
    required this.createTime,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'packageName': packageName,
      'monthlyFee': monthlyFee,
      'usageFee': usageFee,
      'usageDurationMinutes': usageDurationMinutes,
      'usageFlowMb': usageFlowMb,
      'createTime': createTime.toIso8601String(),
    };
  }

  factory MonthlyBill.fromJson(Map<String, dynamic> json) =>
      _$MonthlyBillFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MonthlyBillToJson(this);
}

@JsonSerializable()
class RealtimeUsage extends BaseDataClass {
  final double v4;
  final double v6;
  final DateTime time;

  RealtimeUsage({required this.v4, required this.v6, required this.time});

  @override
  Map<String, dynamic> getEssentials() {
    return {'v4': v4, 'v6': v6, 'time': time.toIso8601String()};
  }

  factory RealtimeUsage.fromJson(Map<String, dynamic> json) =>
      _$RealtimeUsageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$RealtimeUsageToJson(this);
}
