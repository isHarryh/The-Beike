import 'package:flutter/foundation.dart';
import '/types/payment.dart';
import '/services/base.dart';
import '/services/payment/exceptions.dart';

/// Trade channel codes that work on PC clients (Alipay, WeChat).
const pcTradeChannelCodes = {'01', '02'};

/// Defines the contract of the campus payment platform service.
abstract class BasePaymentService extends ChangeNotifier with BaseService {
  // Auth

  Future<void> doLogin(String token);

  Future<void> doLogout();

  Future<PayUserInfo> getUserInfo();

  /// User info cached during login, if any.
  PayUserInfo? get cachedUserInfo => null;

  Future<void> login(String token) async {
    await runLogin(() async {
      await doLogin(token);
    });
  }

  Future<void> logout() async {
    await runLogout(() async {
      await doLogout();
    });
  }

  // Projects

  Future<List<PayProject>> getRecommendedProjects();

  /// Checks whether a new order can be created for the project.
  ///
  /// Throws [PaymentPendingOrderException] when a pending order exists.
  Future<void> checkProjectPayable(String projectId);

  // Tuition and dormitory

  Future<List<TuitionFeeRow>> getTuitionList(String idserial);

  Future<PayOrder> createTuitionOrder(List<TuitionFeeRow> rows);

  // Campus card

  /// Returns the eCard balance in yuan with 2 decimals (reported in cents).
  Future<String> getECardBalance(String idserial, String projectId);

  Future<PayOrder> createECardOrder(String payamtStr);

  // Network fee

  /// Returns the network account state and balance (yuan).
  Future<NetAccBalance> getNetAccBalance(String idserial, String projectId);

  /// [paymentAmountCents] is an integer in cents (max 1000 yuan).
  Future<PayOrder> createNetOrder(int paymentAmountCents);

  // Payment flow

  Future<List<TradeChannel>> getTradeChannels(String projectId);

  Future<PayTradeResult> toPayOrderTrade(String orderNo, String payType);

  Future<PayOrder> getOrderById(String orderId);

  Future<void> canPay(String orderId);

  Future<void> closeOrder(String orderId);

  // Orders

  Future<PayOrderPage> pageOrders({
    int pageCurrent = 1,
    int pageSize = 10,
    String projectName = '',
    String displayStatus = '',
    String orderNo = '',
  });

  /// Finds a pending order by its [orderNo] (e.g. from a 165499 error).
  ///
  /// Returns null when no matching pending order exists.
  Future<PayOrder?> findPendingOrder(String orderNo);

  Future<String> getBillUrl(String orderNo);

  /// Caches the project id used by project-scoped create-order endpoints.
  void cacheProjectId(String projectId);
}
