// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurriculumSettings _$CurriculumSettingsFromJson(Map<String, dynamic> json) =>
    CurriculumSettings(
        weekendMode: $enumDecode(
          _$WeekendDisplayModeEnumMap,
          json['weekendMode'],
        ),
        tableSize: $enumDecode(_$TableSizeEnumMap, json['tableSize']),
        animationMode: $enumDecode(
          _$AnimationModeEnumMap,
          json['animationMode'],
        ),
        activated: json['activated'] as bool? ?? true,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$CurriculumSettingsToJson(CurriculumSettings instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'weekendMode': _$WeekendDisplayModeEnumMap[instance.weekendMode]!,
      'tableSize': _$TableSizeEnumMap[instance.tableSize]!,
      'animationMode': _$AnimationModeEnumMap[instance.animationMode]!,
      'activated': instance.activated,
    };

const _$WeekendDisplayModeEnumMap = {
  WeekendDisplayMode.always: 'always',
  WeekendDisplayMode.auto: 'auto',
  WeekendDisplayMode.never: 'never',
};

const _$TableSizeEnumMap = {
  TableSize.small: 'small',
  TableSize.medium: 'medium',
  TableSize.large: 'large',
};

const _$AnimationModeEnumMap = {
  AnimationMode.none: 'none',
  AnimationMode.fade: 'fade',
  AnimationMode.slide: 'slide',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) =>
    AppSettings(themeMode: $enumDecode(_$ThemeModeEnumMap, json['themeMode']))
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

AnnouncementReadMap _$AnnouncementReadMapFromJson(Map<String, dynamic> json) =>
    AnnouncementReadMap(
        readTimestamp: AnnouncementReadMap._readTimestampFromJson(
          json['readTimestamp'] as Map<String, dynamic>,
        ),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$AnnouncementReadMapToJson(
  AnnouncementReadMap instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'readTimestamp': AnnouncementReadMap._readTimestampToJson(
    instance.readTimestamp,
  ),
};

ServiceSettingsPreference _$ServiceSettingsPreferenceFromJson(
  Map<String, dynamic> json,
) =>
    ServiceSettingsPreference(
        coursesBaseUrl: json['coursesBaseUrl'] as String?,
        netBaseUrl: json['netBaseUrl'] as String?,
        syncBaseUrl: json['syncBaseUrl'] as String?,
        payBaseUrl: json['payBaseUrl'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$ServiceSettingsPreferenceToJson(
  ServiceSettingsPreference instance,
) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'coursesBaseUrl': instance.coursesBaseUrl,
  'netBaseUrl': instance.netBaseUrl,
  'syncBaseUrl': instance.syncBaseUrl,
  'payBaseUrl': instance.payBaseUrl,
};
