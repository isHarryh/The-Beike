import 'package:dio/dio.dart';
import '/types/payment.dart';
import '/services/base.dart';
import '/services/payment/base.dart';
import '/services/payment/exceptions.dart';
import 'convert.dart';

class UstbXyjfService extends BasePaymentService {
  late final Dio _dio;
  String? _token;
  PayUserInfo? _cachedUserInfo;

  UstbXyjfService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  static const String _schoolCode = 'datalook';
  static const String _dataSource = 'PAY';

  @override
  String get defaultBaseUrl => 'https://xyjf.ustb.edu.cn/api';

  @override
  set baseUrl(String url) {
    // Strip a trailing slash so "/pay/..." paths do not become "//pay/...".
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    super.baseUrl = url;
    _dio.options.baseUrl = url;
  }

  String? get token => _token;

  @override
  PayUserInfo? get cachedUserInfo => _cachedUserInfo;

  @override
  Future<void> doLogin(String token) async {
    try {
      _token = token;
      _cachedUserInfo = await getUserInfo();
    } catch (e) {
      _token = null;
      _cachedUserInfo = null;
      rethrow;
    }
  }

  @override
  Future<void> doLogout() async {
    _token = null;
    _cachedUserInfo = null;
  }

  @override
  Future<PayUserInfo> getUserInfo() async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _getEnvelopeData('pay/queryUserInfo');
    return PayUserInfoUstbXyjfExtension.parse(data);
  }

  @override
  Future<List<PayProject>> getRecommendedProjects() async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _getEnvelopeData(
      'pay/project/getRecommendedProjectList',
      query: {'schoolCode': _schoolCode},
    );
    return _parseList(
      data,
      PayProjectUstbXyjfExtension.parse,
      'projects response',
    );
  }

  @override
  Future<void> checkProjectPayable(String projectId) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final envelope = await _postEnvelope(
      'pay/project/getProjectIsAllowPayment',
      data: {'projectId': projectId},
    );

    // The pending-order case keeps messageCode "0" but sets message "165499".
    if (envelope.message == '165499') {
      throw PaymentPendingOrderException.fromEnvelopeData(envelope.data);
    }
  }

  @override
  Future<List<TuitionFeeRow>> getTuitionList(String idserial) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final envelope = await _getEnvelope(
      'pay/web/tuitionAndDorm/getTuitionAndDormList/$idserial/$_schoolCode',
      okCodes: const {'0', '1'},
    );
    // messageCode "1" means no unpaid fee rows; not an error.
    if (envelope.messageCode == '1') {
      return const [];
    }
    return _parseList(
      envelope.data,
      TuitionFeeRowUstbXyjfExtension.parse,
      'tuition list',
    );
  }

  @override
  Future<PayOrder> createTuitionOrder(List<TuitionFeeRow> rows) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }
    if (rows.isEmpty) {
      throw const PaymentServiceBadResponse('No fee rows selected');
    }

    final body = rows
        .map(
          (row) => {
            ...row.toJson(),
            'amount': row.amount.toString(),
            'fullPay': true,
            // payNowStr is the row's own payable amount, per real traffic.
            'payNowStr': (row.payableAmount / 100).toStringAsFixed(2),
          },
        )
        .toList();

    final data = await _postEnvelopeData(
      'pay/web/tuitionAndDorm/createOrder',
      data: body,
    );
    return PayOrderUstbXyjfExtension.parseCreated(data);
  }

  @override
  Future<String> getECardBalance(String idserial, String projectId) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _getEnvelopeData(
      'pay/web/eCardRecharge/queryBasicInfo/$idserial/$projectId',
    );

    // The platform reports the balance in cents; its own web frontend
    // multiplies it by 0.01 before display (chunk "2a40", export "a").
    final raw = data is Map<String, dynamic> ? data['balance'] : null;
    final cents = raw is int ? raw : int.tryParse('$raw');
    if (cents == null) {
      throw const PaymentServiceBadResponse('Unexpected eCard balance format');
    }
    return (cents / 100).toStringAsFixed(2);
  }

  @override
  Future<PayOrder> createECardOrder(String payamtStr) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _postEnvelopeData(
      'pay/web/eCardRecharge/createOrder',
      data: {
        'schoolCode': _schoolCode,
        'projectId': _requireProjectId(),
        'cardType': '',
        'payamtStr': payamtStr,
      },
    );
    return PayOrderUstbXyjfExtension.parseCreated(data);
  }

  @override
  Future<NetAccBalance> getNetAccBalance(
    String idserial,
    String projectId,
  ) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final envelope = await _getEnvelope(
      'pay/web/netCost/queryNetAccBalance/$idserial/$projectId',
    );

    final raw = envelope.data;
    if (raw is! String) {
      throw const PaymentServiceBadResponse('Unexpected balance format');
    }
    final parts = raw.split('|');
    if (parts.length < 2) {
      throw const PaymentServiceBadResponse('Unexpected balance format');
    }
    return NetAccBalance(state: parts[0], balance: parts[1]);
  }

  @override
  Future<PayOrder> createNetOrder(int paymentAmountCents) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }
    if (paymentAmountCents <= 0 || paymentAmountCents > 100000) {
      throw const PaymentServiceBadResponse(
        'Invalid payment amount (must be within 0.01-1000 yuan)',
      );
    }

    final data = await _postEnvelopeData(
      'pay/web/netCost/createOrder',
      data: {
        'netAccount': _cachedUserInfo?.idserial ?? '',
        'paymentAmount': paymentAmountCents,
        'projectId': _requireProjectId(),
      },
    );
    return PayOrderUstbXyjfExtension.parseCreated(data);
  }

  @override
  Future<List<TradeChannel>> getTradeChannels(String projectId) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _getEnvelopeData(
      'pay/open/pay/payrouterref/queryTradeChannel/$projectId/PC',
    );

    // Only Alipay and WeChat are usable on PC clients.
    return _parseList(
          data,
          TradeChannelUstbXyjfExtension.parse,
          'trade channels',
        )
        .where((c) => pcTradeChannelCodes.contains(c.code))
        .map(
          (c) => TradeChannel(
            code: c.code,
            channelName: c.channelName,
            interfaceType: c.interfaceType,
            imageUrl: _absoluteImageUrl(c.imageUrl),
          ),
        )
        .toList();
  }

  /// Makes a platform-relative image URL absolute against the site origin
  /// (e.g. "/pay_student_img/icon_payway1.png" under
  /// "https://xyjf.ustb.edu.cn/api" becomes
  /// "https://xyjf.ustb.edu.cn/pay_student_img/icon_payway1.png").
  String? _absoluteImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.isAbsolute) return url;
    final origin = Uri.tryParse(baseUrl)?.origin;
    return origin == null ? url : '$origin$url';
  }

  @override
  Future<PayTradeResult> toPayOrderTrade(String orderNo, String payType) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _postEnvelopeData(
      'pay/web/third/toPayOrderTrade/',
      data: {
        'payType': payType,
        'tradeType': 'NATIVE',
        'orderNo': orderNo,
        'ip': '127.0.0.1',
        'schoolCode': _schoolCode,
        'dataSource': _dataSource,
        'isKp': '0',
      },
    );
    return PayTradeResultUstbXyjfExtension.parse(data);
  }

  @override
  Future<PayOrder> getOrderById(String orderId) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _getEnvelopeData(
      'pay/pay/orderTrade/getOrderById/$orderId',
    );
    return PayOrderUstbXyjfExtension.parse(data);
  }

  @override
  Future<void> canPay(String orderId) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final envelope = await _postEnvelope(
      'pay/web/order/queryOrderStatusCanPay/$orderId',
      data: {},
    );

    if (envelope.data != null) {
      throw PaymentServiceBadRequest(envelope.message);
    }
  }

  @override
  Future<void> closeOrder(String orderId) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    await _postEnvelopeData('pay/web/order/closeOrderById/$orderId', data: {});
  }

  @override
  Future<PayOrderPage> pageOrders({
    int pageCurrent = 1,
    int pageSize = 10,
    String projectName = '',
    String displayStatus = '',
    String orderNo = '',
  }) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _postEnvelopeData(
      'pay/web/order/pageOrderlist',
      data: {
        'pageCurrent': pageCurrent,
        'pageSize': pageSize,
        'projectName': projectName,
        'projectId': '',
        'displayStatus': displayStatus,
        'startCreateDate': '',
        'endCreateDate': '',
        'schoolCode': _schoolCode,
        'orderNo': orderNo,
      },
    );
    return PayOrderPageUstbXyjfExtension.parse(data);
  }

  @override
  Future<PayOrder?> findPendingOrder(String orderNo) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final page = await pageOrders(orderNo: orderNo);
    for (final order in page.records) {
      if (order.orderNo == orderNo && order.isPending) {
        return order;
      }
    }
    return null;
  }

  @override
  Future<String> getBillUrl(String orderNo) async {
    if (status == ServiceStatus.offline) {
      throw const PaymentServiceOffline();
    }

    final data = await _postEnvelopeData(
      'servpay/pay/orderTrade/lookBillNew',
      data: {'orderNo': orderNo},
    );

    try {
      return data as String;
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse bill URL', e);
    }
  }

  // Envelope handling

  String? _effectiveProjectId;

  String _requireProjectId() {
    final projectId = _effectiveProjectId;
    if (projectId == null) {
      throw const PaymentServiceException('Project id is not cached');
    }
    return projectId;
  }

  /// Updates the cached project id used by project-specific create-order APIs.
  @override
  void cacheProjectId(String projectId) {
    _effectiveProjectId = projectId;
  }

  Future<_Envelope> _requestEnvelope(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Set<String> okCodes = const {'0'},
  }) async {
    // Dio joins baseUrl and path verbatim; ensure a leading slash so the
    // request does not become e.g. ".../apipay/queryUserInfo".
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    var response = await _send(method, path, data, query);
    PaymentServiceException.raiseForStatus(response.statusCode!, setOffline);
    var envelope = _parseEnvelope(response);

    // Token silently refreshed: the new token arrives in data; replay once.
    if (envelope.messageCode == '-3') {
      final newToken = _extractNewToken(envelope.data);
      if (newToken != null) {
        _token = newToken;
        response = await _send(method, path, data, query);
        PaymentServiceException.raiseForStatus(
          response.statusCode!,
          setOffline,
        );
        envelope = _parseEnvelope(response);
      }
    }

    if (envelope.messageCode == '-1' ||
        envelope.messageCode == '-2' ||
        envelope.messageCode == '50014') {
      setOffline();
      throw const PaymentServiceUnauthorized('Token expired or invalid');
    }

    if (!okCodes.contains(envelope.messageCode)) {
      throw PaymentServiceBadRequest(
        envelope.message.isNotEmpty
            ? envelope.message
            : 'Unknown error (${envelope.messageCode})',
      );
    }

    return envelope;
  }

  Future<Response> _send(
    String method,
    String path,
    Object? data,
    Map<String, dynamic>? query,
  ) async {
    try {
      return await _dio.request(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: _token != null ? {'X-Token': _token} : null,
        ),
      );
    } catch (e) {
      throw PaymentServiceNetworkError('Failed to request $path', e);
    }
  }

  _Envelope _parseEnvelope(Response response) {
    try {
      final map = response.data as Map<String, dynamic>;
      return _Envelope(
        '${map['messageCode']}',
        '${map['message'] ?? ''}',
        map['data'],
      );
    } catch (e) {
      throw PaymentServiceBadResponse('Response is not a JSON envelope', e);
    }
  }

  String? _extractNewToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic> && inner['token'] is String) {
        return inner['token'] as String;
      }
      if (data['token'] is String) return data['token'] as String;
    }
    return null;
  }

  List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parse,
    String what,
  ) {
    try {
      return (data as List)
          .map((item) => parse(item as Map<String, dynamic>))
          .toList();
    } on PaymentServiceException {
      rethrow;
    } catch (e) {
      throw PaymentServiceBadResponse('Failed to parse $what', e);
    }
  }

  Future<_Envelope> _getEnvelope(
    String path, {
    Map<String, dynamic>? query,
    Set<String> okCodes = const {'0'},
  }) {
    return _requestEnvelope('GET', path, query: query, okCodes: okCodes);
  }

  Future<_Envelope> _postEnvelope(String path, {Object? data}) {
    return _requestEnvelope('POST', path, data: data);
  }

  Future<dynamic> _getEnvelopeData(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return (await _getEnvelope(path, query: query)).data;
  }

  Future<dynamic> _postEnvelopeData(String path, {Object? data}) async {
    return (await _postEnvelope(path, data: data)).data;
  }
}

class _Envelope {
  final String messageCode;
  final String message;
  final dynamic data;

  const _Envelope(this.messageCode, this.message, this.data);
}
