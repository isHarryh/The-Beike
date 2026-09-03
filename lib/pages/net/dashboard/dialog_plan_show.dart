import 'package:flutter/material.dart';
import '/types/net.dart';

class NetPlanShowDialog extends StatelessWidget {
  final NetUserInfo userInfo;

  const NetPlanShowDialog({super.key, required this.userInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return AlertDialog(
      title: const Text('套餐详情'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildDetailItem(theme, '套餐名称', userInfo.plan!.planName),
            _buildDetailItem(theme, '套餐描述', userInfo.plan!.planDescription),
            _buildDetailItem(theme, '最大登录数', '${userInfo.plan!.maxLogins}'),
            const Divider(),
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        theme,
                        '免费流量',
                        '${userInfo.plan!.freeFlow.toStringAsFixed(0)} MB',
                        subtitle:
                            '= ${(userInfo.plan!.freeFlow / 1024).toStringAsFixed(1)} GB',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              theme,
                              '流量单价',
                              '¥${userInfo.plan!.unitFlowCost.toStringAsFixed(4)}/MB',
                              subtitle:
                                  '= ¥${(userInfo.plan!.unitFlowCost * 1024).toStringAsFixed(2)}/GB',
                            ),
                          ),
                          _buildQuickCalcButton(context),
                        ],
                      ),
                      const Divider(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          theme,
                          '免费流量',
                          '${userInfo.plan!.freeFlow.toStringAsFixed(0)} MB',
                          subtitle:
                              '= ${(userInfo.plan!.freeFlow / 1024).toStringAsFixed(1)} GB',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailItem(
                          theme,
                          '流量单价',
                          '¥${userInfo.plan!.unitFlowCost.toStringAsFixed(4)}/MB',
                          subtitle:
                              '= ¥${(userInfo.plan!.unitFlowCost * 1024).toStringAsFixed(2)}/GB',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: _buildQuickCalcButton(context)),
                    ],
                  ),
            const SizedBox(height: 8),
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        theme,
                        '最大下行速度',
                        '${((userInfo.bandwidthDown ?? 0) / 1024).toStringAsFixed(1)} MB/s',
                        subtitle:
                            '= ${((userInfo.bandwidthDown ?? 0) / 128).toStringAsFixed(0)} Mbps',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              theme,
                              '最大上行速度',
                              '${((userInfo.bandwidthUp ?? 0) / 1024).toStringAsFixed(1)} MB/s',
                              subtitle:
                                  '= ${((userInfo.bandwidthUp ?? 0) / 128).toStringAsFixed(0)} Mbps',
                            ),
                          ),
                          _buildNotSoFastButton(context, theme),
                        ],
                      ),
                      const Divider(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          theme,
                          '最大下行速度',
                          '${((userInfo.bandwidthDown ?? 0) / 1024).toStringAsFixed(1)} MB/s',
                          subtitle:
                              '= ${((userInfo.bandwidthDown ?? 0) / 128).toStringAsFixed(0)} Mbps',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailItem(
                          theme,
                          '最大上行速度',
                          '${((userInfo.bandwidthUp ?? 0) / 1024).toStringAsFixed(1)} MB/s',
                          subtitle:
                              '= ${((userInfo.bandwidthUp ?? 0) / 128).toStringAsFixed(0)} Mbps',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: _buildNotSoFastButton(context, theme)),
                    ],
                  ),
            const SizedBox(height: 16),
          ],
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

  Widget _buildDetailItem(
    ThemeData theme,
    String label,
    String value, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
          if (subtitle != null)
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCalcButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.calculate_rounded),
      label: const Text('快捷计算'),
      onPressed: () => showDialog(
        context: context,
        builder: (context) =>
            NetQuickCalcDialog(unitFlowCost: userInfo.plan!.unitFlowCost),
      ),
    );
  }

  Widget _buildNotSoFastButton(BuildContext context, ThemeData theme) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.sentiment_dissatisfied_outlined),
      label: const Text('没那么快'),
      onPressed: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('没那么快'),
          content: Text(
            '由于 WLAN 的技术局限性，如果您使用的是无线网，则实际网速通常无法达到上限。',
            style: theme.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}

class NetQuickCalcDialog extends StatefulWidget {
  final double unitFlowCost;

  const NetQuickCalcDialog({super.key, required this.unitFlowCost});

  @override
  State<NetQuickCalcDialog> createState() => _NetQuickCalcDialogState();
}

class _NetQuickCalcDialogState extends State<NetQuickCalcDialog> {
  final TextEditingController _flowController = TextEditingController();

  String _unit = 'GB';

  double _cost = 0.0;

  @override
  void initState() {
    super.initState();
    _flowController.addListener(_calculateCost);
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  void _calculateCost() {
    double multiplier = 1.0;
    if (_unit == 'GB') {
      multiplier = 1024.0;
    } else if (_unit == 'TB') {
      multiplier = 1024.0 * 1024.0;
    }
    final flow = (double.tryParse(_flowController.text) ?? 0.0) * multiplier;
    setState(() {
      _cost = flow * widget.unitFlowCost;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('快捷计算'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('请输入需要计算费用的套餐外流量值。', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _flowController,
                  decoration: const InputDecoration(
                    labelText: '流量值',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 100,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  items: ['MB', 'GB', 'TB'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _unit = newValue!;
                      _calculateCost();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Text(
            '费用：¥${_cost.toStringAsFixed(2)}',
            style: theme.textTheme.bodyLarge,
          ),
        ],
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
