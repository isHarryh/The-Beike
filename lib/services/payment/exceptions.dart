/// Base exception class for payment services.
class PaymentServiceException implements Exception {
  final String message;
  final dynamic originalError;

  const PaymentServiceException(this.message, [this.originalError]);

  static void raiseForStatus(
    int statusCode, [
    void Function()? setOfflineCallback,
  ]) {
    if (statusCode == 401) {
      setOfflineCallback?.call();
      throw const PaymentServiceUnauthorized(
        'HTTP 401 - Authentication failed',
      );
    } else if (statusCode < 200 || statusCode >= 300) {
      throw PaymentServiceNetworkError('HTTP $statusCode');
    }
  }

  @override
  String toString() => 'PaymentServiceException: $message';
}

/// Exception thrown when the service is offline or not logged in.
class PaymentServiceOffline extends PaymentServiceException {
  const PaymentServiceOffline([
    super.message = 'Service is offline or not logged in',
  ]);

  @override
  String toString() => 'PaymentServiceOffline: $message';
}

/// Exception thrown when a network error occurs during a request.
class PaymentServiceNetworkError extends PaymentServiceException {
  const PaymentServiceNetworkError(super.message, [super.originalError]);

  @override
  String toString() => 'PaymentServiceNetworkError: $message';
}

/// Exception thrown when the response cannot be parsed.
class PaymentServiceBadResponse extends PaymentServiceException {
  const PaymentServiceBadResponse(super.message, [super.originalError]);

  @override
  String toString() => 'PaymentServiceBadResponse: $message';
}

/// Exception thrown when the login token is invalid or expired.
class PaymentServiceUnauthorized extends PaymentServiceException {
  const PaymentServiceUnauthorized(super.message);

  @override
  String toString() => 'PaymentServiceUnauthorized: $message';
}

/// Exception thrown when the project already has a pending order (code 165499).
class PaymentPendingOrderException extends PaymentServiceException {
  final String orderNo;
  final String? tipMessage;

  const PaymentPendingOrderException(this.orderNo, [this.tipMessage])
    : super(tipMessage ?? 'A pending order exists');

  /// Builds the exception from the `{orderNo, message}` payload of a 165499
  /// envelope.
  factory PaymentPendingOrderException.fromEnvelopeData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return PaymentPendingOrderException(
        data['orderNo'] as String? ?? '',
        data['message'] as String?,
      );
    }
    return const PaymentPendingOrderException('', null);
  }

  @override
  String toString() =>
      'PaymentPendingOrderException: ${tipMessage ?? 'A pending order exists'} ($orderNo)';
}

/// Exception thrown for non-zero business codes that are not special-cased.
class PaymentServiceBadRequest extends PaymentServiceException {
  const PaymentServiceBadRequest(super.message, [super.originalError]);

  @override
  String toString() => 'PaymentServiceBadRequest: $message';
}
