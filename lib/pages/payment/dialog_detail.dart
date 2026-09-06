import 'package:flutter/material.dart';
import '/types/payment.dart';
import 'common.dart';

/// Modal dialog showing an order's basic info.
class OrderDetailDialog extends StatelessWidget {
  final PayOrder order;

  const OrderDetailDialog({super.key, required this.order});

  Widget _buildRow(BuildContext context, String label, String? value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value ?? '--', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('订单详情'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow(context, '订单号', order.orderNo),
              _buildRow(context, '项目', order.projectName ?? order.productDesc),
              _buildRow(context, '金额', '${formatCents(order.amount)} 元'),
              _buildRow(
                context,
                '渠道',
                paymentChannels[order.tradeChannel]?.label ??
                    order.tradeChannel,
              ),
              _buildRow(context, '创建时间', order.createDate),
              _buildRow(context, '计划关闭时间', order.schdualCloseTime),
              _buildRow(context, '实际关闭时间', order.actualCloseTime),
              _buildRow(context, '支付流水号', order.balanceOrderTradeOrderNo),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
