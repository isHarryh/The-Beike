import 'package:flutter/material.dart';
import '/services/payment/exceptions.dart';
import '/services/provider.dart';
import '/types/payment.dart';

// Formatting helpers

String formatCents(int? cents) {
  if (cents == null) return '--';
  final yuan = cents / 100;
  final text = yuan.toStringAsFixed(2);
  return text.endsWith('00') ? text.substring(0, text.length - 3) : text;
}

// Step indicator (mirrors course selection pages)

Widget buildStepIndicator(BuildContext context, int currentStep) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
      ),
    ),
    child: Row(
      children: [
        _buildStepItem(context, '款项确认', 1, currentStep == 1),
        _buildStepConnector(context),
        _buildStepItem(context, '扫码支付', 2, currentStep == 2),
        _buildStepConnector(context),
        _buildStepItem(context, '支付结果', 3, currentStep == 3),
      ],
    ),
  );
}

Widget _buildStepItem(
  BuildContext context,
  String title,
  int stepNumber,
  bool isActive,
) {
  return Expanded(
    child: Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildStepConnector(BuildContext context) {
  return Container(
    height: 2,
    width: 20,
    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
  );
}

// Alerts

/// Shows a snackbar with a plain text message.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Shows a snackbar with the error's message.
void showError(BuildContext context, Object error) {
  showMessage(context, error.toString());
}

/// Fetches the pending order behind a 165499 error; shows a snackbar and
/// returns null when it cannot be found.
Future<PayOrder?> locatePendingOrder(
  BuildContext context,
  String orderNo,
) async {
  try {
    final order = await ServiceProvider.instance.paymentService
        .findPendingOrder(orderNo);
    if (!context.mounted) return null;
    if (order == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到待支付订单')));
    }
    return order;
  } catch (e) {
    if (!context.mounted) return null;
    showError(context, e);
    return null;
  }
}

/// Runs the pending-order (165499) resume flow: shows the confirm dialog,
/// then locates the pending order. Returns null when the user aborts or the
/// order cannot be found.
Future<PayOrder?> resolvePendingOrderFlow(
  BuildContext context,
  PaymentPendingOrderException e,
) async {
  final goOn = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('存在未完成订单'),
        content: Text(e.tipMessage ?? '此项目下仍存在未完成的订单，是否要继续支付？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续支付'),
          ),
        ],
      );
    },
  );
  if (goOn != true || !context.mounted) return null;
  return locatePendingOrder(context, e.orderNo);
}

// Error retry view

Widget buildErrorRetry(String message, VoidCallback onRetry) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

// Channels

const paymentChannels = {
  '01': (label: '支付宝', icon: Icons.account_balance_wallet),
  '02': (label: '微信', icon: Icons.chat_bubble),
};

IconData channelIcon(String? code) =>
    paymentChannels[code]?.icon ?? Icons.payment;
