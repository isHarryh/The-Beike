// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PayUserInfo _$PayUserInfoFromJson(Map<String, dynamic> json) =>
    PayUserInfo(
        id: json['id'] as String,
        idserial: json['idserial'] as String,
        name: json['name'] as String,
        idNum: json['idNum'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        userType: json['userType'] as String?,
        identityType: json['identityType'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PayUserInfoToJson(PayUserInfo instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'id': instance.id,
      'idserial': instance.idserial,
      'name': instance.name,
      'idNum': instance.idNum,
      'phone': instance.phone,
      'email': instance.email,
      'userType': instance.userType,
      'identityType': instance.identityType,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

PayProject _$PayProjectFromJson(Map<String, dynamic> json) =>
    PayProject(
        id: json['id'] as String,
        projectName: json['projectName'] as String,
        engName: json['engName'] as String?,
        proModelUrl: json['proModelUrl'] as String?,
        imgUrl: json['imgUrl'] as String?,
        status: json['status'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PayProjectToJson(PayProject instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'id': instance.id,
      'projectName': instance.projectName,
      'engName': instance.engName,
      'proModelUrl': instance.proModelUrl,
      'imgUrl': instance.imgUrl,
      'status': instance.status,
    };

TuitionFeeRow _$TuitionFeeRowFromJson(Map<String, dynamic> json) =>
    TuitionFeeRow(
        id: json['id'] as String,
        proCode: json['proCode'] as String,
        proName: json['proName'] as String,
        academicYear: json['academicYear'] as String?,
        amount: (json['amount'] as num).toInt(),
        payableAmount: (json['payableAmount'] as num).toInt(),
        actualReceivable: (json['actualReceivable'] as num).toInt(),
        projectId: json['projectId'] as String,
        projectName: json['projectName'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$TuitionFeeRowToJson(TuitionFeeRow instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'id': instance.id,
      'proCode': instance.proCode,
      'proName': instance.proName,
      'academicYear': instance.academicYear,
      'amount': instance.amount,
      'payableAmount': instance.payableAmount,
      'actualReceivable': instance.actualReceivable,
      'projectId': instance.projectId,
      'projectName': instance.projectName,
    };

TradeChannel _$TradeChannelFromJson(Map<String, dynamic> json) =>
    TradeChannel(
        code: json['code'] as String,
        channelName: json['channelName'] as String?,
        interfaceType: json['interfaceType'] as String?,
        imageUrl: json['imageUrl'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$TradeChannelToJson(TradeChannel instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'code': instance.code,
      'channelName': instance.channelName,
      'interfaceType': instance.interfaceType,
      'imageUrl': instance.imageUrl,
    };

PayTradeResult _$PayTradeResultFromJson(Map<String, dynamic> json) =>
    PayTradeResult(
        orderNo: json['orderNo'] as String?,
        amount: (json['amount'] as num?)?.toInt(),
        urlCode: json['urlCode'] as String?,
        payType: json['payType'] as String?,
        tradeType: json['tradeType'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PayTradeResultToJson(PayTradeResult instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'orderNo': instance.orderNo,
      'amount': instance.amount,
      'urlCode': instance.urlCode,
      'payType': instance.payType,
      'tradeType': instance.tradeType,
    };

PayOrder _$PayOrderFromJson(Map<String, dynamic> json) =>
    PayOrder(
        id: json['id'] as String,
        orderNo: json['orderNo'] as String?,
        amount: (json['amount'] as num?)?.toInt(),
        payableAmount: (json['payableAmount'] as num?)?.toInt(),
        tradeChannel: json['tradeChannel'] as String?,
        status: json['status'] as String?,
        displayStatus: json['displayStatus'] as String?,
        createDate: json['createDate'] as String?,
        schdualCloseTime: json['schdualCloseTime'] as String?,
        actualCloseTime: json['actualCloseTime'] as String?,
        balanceOrderTradeOrderNo: json['balanceOrderTradeOrderNo'] as String?,
        projectId: json['projectId'] as String?,
        projectName: json['projectName'] as String?,
        productDesc: json['productDesc'] as String?,
        isKp: json['isKp'] as String?,
        imgUrl: json['imgUrl'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PayOrderToJson(PayOrder instance) => <String, dynamic>{
  r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
    instance.$lastUpdateTime,
    const UTCConverter().toJson,
  ),
  'id': instance.id,
  'orderNo': instance.orderNo,
  'amount': instance.amount,
  'payableAmount': instance.payableAmount,
  'tradeChannel': instance.tradeChannel,
  'status': instance.status,
  'displayStatus': instance.displayStatus,
  'createDate': instance.createDate,
  'schdualCloseTime': instance.schdualCloseTime,
  'actualCloseTime': instance.actualCloseTime,
  'balanceOrderTradeOrderNo': instance.balanceOrderTradeOrderNo,
  'projectId': instance.projectId,
  'projectName': instance.projectName,
  'productDesc': instance.productDesc,
  'isKp': instance.isKp,
  'imgUrl': instance.imgUrl,
};

PayOrderPage _$PayOrderPageFromJson(Map<String, dynamic> json) =>
    PayOrderPage(
        records: (json['records'] as List<dynamic>)
            .map((e) => PayOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toInt(),
        size: (json['size'] as num).toInt(),
        current: (json['current'] as num).toInt(),
        pages: (json['pages'] as num).toInt(),
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PayOrderPageToJson(PayOrderPage instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'records': instance.records,
      'total': instance.total,
      'size': instance.size,
      'current': instance.current,
      'pages': instance.pages,
    };

PaymentAccountData _$PaymentAccountDataFromJson(Map<String, dynamic> json) =>
    PaymentAccountData(
        user: json['user'] == null
            ? null
            : PayUserInfo.fromJson(json['user'] as Map<String, dynamic>),
        token: json['token'] as String?,
        method: json['method'] as String?,
      )
      ..$lastUpdateTime = _$JsonConverterFromJson<String, DateTime>(
        json[r'$lastUpdateTime'],
        const UTCConverter().fromJson,
      );

Map<String, dynamic> _$PaymentAccountDataToJson(PaymentAccountData instance) =>
    <String, dynamic>{
      r'$lastUpdateTime': _$JsonConverterToJson<String, DateTime>(
        instance.$lastUpdateTime,
        const UTCConverter().toJson,
      ),
      'user': instance.user,
      'token': instance.token,
      'method': instance.method,
    };
