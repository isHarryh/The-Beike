import 'package:flutter/material.dart';
import '/types/payment.dart';
import '/utils/app_bar.dart';
import 'common.dart';

/// Step 3: payment outcome.
class PayResultPage extends StatelessWidget {
  final PayProject project;
  final PayOrder order;
  final bool isSuccess;

  const PayResultPage({
    super.key,
    required this.project,
    required this.order,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PageAppBar(title: project.projectName),
      body: Column(
        children: [
          buildStepIndicator(context, 3),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error_outline,
                    size: 72,
                    color: isSuccess ? Colors.green : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSuccess ? '支付成功' : '订单已关闭',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSuccess) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${formatCents(order.amount)} 元',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (order.balanceOrderTradeOrderNo != null)
                      Text(
                        '流水号 ${order.balanceOrderTradeOrderNo}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('完成'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
