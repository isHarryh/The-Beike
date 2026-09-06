import '/types/payment.dart';
import '/services/payment/exceptions.dart';

extension PayUserInfoUstbXyjfExtension on PayUserInfo {
  static PayUserInfo parse(Map<String, dynamic> data) {
    try {
      return PayUserInfo(
        id: data['id'] as String,
        idserial: data['idserial'] as String? ?? '',
        name: data['name'] as String? ?? '',
        idNum: data['idNum'] as String?,
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        userType: data['userType'] as String?,
        identityType: data['identityType'] as String?,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse user info', e);
    }
  }
}

extension PayProjectUstbXyjfExtension on PayProject {
  static PayProject parse(Map<String, dynamic> data) {
    try {
      return PayProject(
        id: data['id'] as String,
        projectName: data['projectName'] as String? ?? '',
        engName: data['engName'] as String?,
        proModelUrl: data['proModelUrl'] as String?,
        imgUrl: data['imgUrl'] as String?,
        status: data['status'] as String?,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse project', e);
    }
  }
}

extension TuitionFeeRowUstbXyjfExtension on TuitionFeeRow {
  static TuitionFeeRow parse(Map<String, dynamic> data) {
    int parseIntField(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    try {
      return TuitionFeeRow(
        id: data['id'] as String,
        proCode: data['proCode'] as String? ?? '',
        proName: data['proName'] as String? ?? '',
        academicYear: data['academicYear'] as String?,
        amount: parseIntField(data['amount']),
        payableAmount: parseIntField(
          data['payableAmount'] ?? data['actualReceivable'],
        ),
        actualReceivable: parseIntField(data['actualReceivable']),
        projectId: data['projectId'] as String? ?? '',
        projectName: data['projectName'] as String?,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse fee row', e);
    }
  }
}

extension TradeChannelUstbXyjfExtension on TradeChannel {
  static TradeChannel parse(Map<String, dynamic> data) {
    try {
      return TradeChannel(
        code: data['code'] as String,
        channelName: data['channelName'] as String?,
        interfaceType: data['interfaceType'] as String?,
        imageUrl: data['imageUrl'] as String?,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse trade channel', e);
    }
  }
}

extension PayTradeResultUstbXyjfExtension on PayTradeResult {
  static PayTradeResult parse(Map<String, dynamic> data) {
    try {
      return PayTradeResult(
        orderNo: data['orderNo'] as String?,
        amount: data['amount'] is int ? data['amount'] as int : null,
        urlCode: data['urlCode'] as String?,
        payType: data['payType'] as String?,
        tradeType: data['tradeType'] as String?,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse trade result', e);
    }
  }
}

extension PayOrderUstbXyjfExtension on PayOrder {
  static PayOrder parse(Map<String, dynamic> data) {
    int? parseIntField(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value');
    }

    try {
      return PayOrder(
        id: data['id'] as String,
        orderNo: data['orderNo'] as String?,
        amount: parseIntField(data['amount']),
        payableAmount: parseIntField(data['payableAmount']),
        tradeChannel: data['tradeChannel'] as String?,
        status: data['status'] as String?,
        displayStatus: data['displayStatus'] as String?,
        createDate: data['createDate'] as String?,
        schdualCloseTime: data['schdualCloseTime'] as String?,
        actualCloseTime: data['actualCloseTime'] as String?,
        balanceOrderTradeOrderNo: data['balanceOrderTradeOrderNo'] as String?,
        projectId: data['projectId'] as String?,
        projectName: data['projectName'] as String?,
        productDesc: data['productDesc'] as String?,
        isKp: data['isKp'] as String?,
        imgUrl: data['imgUrl'] as String?,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse order', e);
    }
  }

  /// Parses a create-order response, which usually wraps the order in a
  /// `PayOrderTrade` field; some endpoints return the order directly.
  static PayOrder parseCreated(Map<String, dynamic> data) {
    final trade = data['PayOrderTrade'];
    return trade is Map<String, dynamic> ? parse(trade) : parse(data);
  }
}

extension PayOrderPageUstbXyjfExtension on PayOrderPage {
  static PayOrderPage parse(Map<String, dynamic> data) {
    try {
      final records = (data['records'] as List? ?? [])
          .map(
            (item) =>
                PayOrderUstbXyjfExtension.parse(item as Map<String, dynamic>),
          )
          .toList();
      return PayOrderPage(
        records: records,
        total: data['total'] as int? ?? records.length,
        size: data['size'] as int? ?? 10,
        current: data['current'] as int? ?? 1,
        pages: data['pages'] as int? ?? 1,
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse order page', e);
    }
  }
}
