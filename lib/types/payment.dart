import 'package:json_annotation/json_annotation.dart';
import 'base.dart';

part 'payment.g.dart';

/// User profile returned by `pay/queryUserInfo`.
@JsonSerializable()
class PayUserInfo extends BaseDataClass {
  final String id;
  final String idserial;
  final String name;
  final String? idNum;
  final String? phone;
  final String? email;
  final String? userType;
  final String? identityType;

  PayUserInfo({
    required this.id,
    required this.idserial,
    required this.name,
    this.idNum,
    this.phone,
    this.email,
    this.userType,
    this.identityType,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'id': id, 'idserial': idserial, 'name': name};
  }

  factory PayUserInfo.fromJson(Map<String, dynamic> json) =>
      _$PayUserInfoFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PayUserInfoToJson(this);
}

/// Payment project (e.g. tuition, campus card, network fee).
@JsonSerializable()
class PayProject extends BaseDataClass {
  final String id;
  final String projectName;
  final String? engName;
  final String? proModelUrl;
  final String? imgUrl;
  final String? status;

  PayProject({
    required this.id,
    required this.projectName,
    this.engName,
    this.proModelUrl,
    this.imgUrl,
    this.status,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'id': id, 'projectName': projectName};
  }

  factory PayProject.fromJson(Map<String, dynamic> json) =>
      _$PayProjectFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PayProjectToJson(this);
}

/// A payable fee row for tuition and dormitory.
@JsonSerializable()
class TuitionFeeRow extends BaseDataClass {
  final String id;
  final String proCode;
  final String proName;
  final String? academicYear;
  final int amount;
  final int payableAmount;
  final int actualReceivable;
  final String projectId;
  final String? projectName;

  TuitionFeeRow({
    required this.id,
    required this.proCode,
    required this.proName,
    this.academicYear,
    required this.amount,
    required this.payableAmount,
    required this.actualReceivable,
    required this.projectId,
    this.projectName,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'id': id, 'proCode': proCode};
  }

  factory TuitionFeeRow.fromJson(Map<String, dynamic> json) =>
      _$TuitionFeeRowFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$TuitionFeeRowToJson(this);
}

/// A payment channel (Alipay, WeChat, ...) available for a project.
@JsonSerializable()
class TradeChannel extends BaseDataClass {
  final String code;
  final String? channelName;
  final String? interfaceType;
  final String? imageUrl;

  TradeChannel({
    required this.code,
    this.channelName,
    this.interfaceType,
    this.imageUrl,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'code': code};
  }

  factory TradeChannel.fromJson(Map<String, dynamic> json) =>
      _$TradeChannelFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$TradeChannelToJson(this);
}

/// The trade result of `toPayOrderTrade` (QR content for NATIVE).
@JsonSerializable()
class PayTradeResult extends BaseDataClass {
  final String? orderNo;
  final int? amount;
  final String? urlCode;
  final String? payType;
  final String? tradeType;

  PayTradeResult({
    this.orderNo,
    this.amount,
    this.urlCode,
    this.payType,
    this.tradeType,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'orderNo': orderNo, 'payType': payType};
  }

  factory PayTradeResult.fromJson(Map<String, dynamic> json) =>
      _$PayTradeResultFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PayTradeResultToJson(this);
}

/// Payment order (subset of PAY_ORDER_TRADE row).
@JsonSerializable()
class PayOrder extends BaseDataClass {
  final String id;
  final String? orderNo;
  final int? amount;
  final int? payableAmount;
  final String? tradeChannel;
  final String? status;
  final String? displayStatus;
  final String? createDate;
  final String? schdualCloseTime;
  final String? actualCloseTime;
  final String? balanceOrderTradeOrderNo;
  final String? projectId;
  final String? projectName;
  final String? productDesc;
  final String? isKp; // Kp = 开票
  final String? imgUrl;

  PayOrder({
    required this.id,
    this.orderNo,
    this.amount,
    this.payableAmount,
    this.tradeChannel,
    this.status,
    this.displayStatus,
    this.createDate,
    this.schdualCloseTime,
    this.actualCloseTime,
    this.balanceOrderTradeOrderNo,
    this.projectId,
    this.projectName,
    this.productDesc,
    this.isKp,
    this.imgUrl,
  });

  bool get isPending =>
      status == 'PENDING_PAYMENT' ||
      displayStatus == '101' ||
      displayStatus == '102';

  bool get isCompleted => status == 'COMPLETED' || displayStatus == '103';

  @override
  Map<String, dynamic> getEssentials() {
    return {'id': id, 'orderNo': orderNo, 'status': status};
  }

  factory PayOrder.fromJson(Map<String, dynamic> json) =>
      _$PayOrderFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PayOrderToJson(this);
}

/// MyBatis-Plus style paged result of orders.
@JsonSerializable()
class PayOrderPage extends BaseDataClass {
  final List<PayOrder> records;
  final int total;
  final int size;
  final int current;
  final int pages;

  PayOrderPage({
    required this.records,
    required this.total,
    required this.size,
    required this.current,
    required this.pages,
  });

  @override
  Map<String, dynamic> getEssentials() {
    return {'total': total, 'current': current};
  }

  factory PayOrderPage.fromJson(Map<String, dynamic> json) =>
      _$PayOrderPageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PayOrderPageToJson(this);
}

/// Network account state and balance (yuan string) parsed from the raw
/// `"state|balance"` response of `queryNetAccBalance`.
class NetAccBalance {
  final String state;
  final String balance;

  const NetAccBalance({required this.state, required this.balance});

  /// Whether the account is suspended (platform state "0").
  bool get isSuspended => state == '0';
}

/// Persisted payment login data.
@JsonSerializable()
class PaymentAccountData extends BaseDataClass {
  final PayUserInfo? user;
  final String? token;
  final String? method;

  PaymentAccountData({this.user, this.token, this.method});

  @override
  Map<String, dynamic> getEssentials() {
    return {'user': user?.getEssentials(), 'method': method};
  }

  factory PaymentAccountData.fromJson(Map<String, dynamic> json) =>
      _$PaymentAccountDataFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PaymentAccountDataToJson(this);
}
