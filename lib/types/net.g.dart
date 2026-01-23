// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'net.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetDashboardSessionState _$NetDashboardSessionStateFromJson(
  Map<String, dynamic> json,
) =>
    NetDashboardSessionState(
        checkCode: json['checkCode'] as String,
        needRandomCode: json['needRandomCode'] as bool,
        csrfTokens: (json['csrfTokens'] as Map<String, dynamic>?)?.map(
          (k, e) => MapEntry(k, e as String),
        ),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$NetDashboardSessionStateToJson(
  NetDashboardSessionState instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'checkCode': instance.checkCode,
  'needRandomCode': instance.needRandomCode,
  'csrfTokens': instance.csrfTokens,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

NetUserIntegratedData _$NetUserIntegratedDataFromJson(
  Map<String, dynamic> json,
) =>
    NetUserIntegratedData(
        account: json['account'] as String,
        password: json['password'] as String,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$NetUserIntegratedDataToJson(
  NetUserIntegratedData instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'account': instance.account,
  'password': instance.password,
};

MacDevice _$MacDeviceFromJson(Map<String, dynamic> json) =>
    MacDevice(
        name: json['name'] as String,
        mac: json['mac'] as String,
        isOnline: json['isOnline'] as bool,
        lastOnlineTime: json['lastOnlineTime'] as String,
        lastOnlineIp: json['lastOnlineIp'] as String,
        isDumbDevice: json['isDumbDevice'] as bool,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$MacDeviceToJson(MacDevice instance) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'name': instance.name,
  'mac': instance.mac,
  'isOnline': instance.isOnline,
  'lastOnlineTime': instance.lastOnlineTime,
  'lastOnlineIp': instance.lastOnlineIp,
  'isDumbDevice': instance.isDumbDevice,
};

MonthlyBill _$MonthlyBillFromJson(Map<String, dynamic> json) =>
    MonthlyBill(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        packageName: json['packageName'] as String,
        monthlyFee: (json['monthlyFee'] as num).toDouble(),
        usageFee: (json['usageFee'] as num).toDouble(),
        usageDurationMinutes: (json['usageDurationMinutes'] as num).toDouble(),
        usageFlowMb: (json['usageFlowMb'] as num).toDouble(),
        createTime: DateTime.parse(json['createTime'] as String),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$MonthlyBillToJson(MonthlyBill instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'packageName': instance.packageName,
      'monthlyFee': instance.monthlyFee,
      'usageFee': instance.usageFee,
      'usageDurationMinutes': instance.usageDurationMinutes,
      'usageFlowMb': instance.usageFlowMb,
      'createTime': instance.createTime.toIso8601String(),
    };

RealtimeUsage _$RealtimeUsageFromJson(Map<String, dynamic> json) =>
    RealtimeUsage(
        v4: (json['v4'] as num).toDouble(),
        v6: (json['v6'] as num).toDouble(),
        time: DateTime.parse(json['time'] as String),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$RealtimeUsageToJson(RealtimeUsage instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'v4': instance.v4,
      'v6': instance.v6,
      'time': instance.time.toIso8601String(),
    };
