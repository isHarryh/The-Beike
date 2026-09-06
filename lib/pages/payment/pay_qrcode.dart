import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '/services/provider.dart';
import '/types/payment.dart';
import '/utils/app_bar.dart';
import 'common.dart';
import 'pay_result.dart';

/// Step 2: pick a channel, show the QR code and poll the order state.
class PayQrcodePage extends StatefulWidget {
  final PayProject project;
  final PayOrder order;

  const PayQrcodePage({super.key, required this.project, required this.order});

  @override
  State<PayQrcodePage> createState() => _PayQrcodePageState();
}

class _PayQrcodePageState extends State<PayQrcodePage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  Timer? _pollTimer;

  /// True while either loading the channel list or requesting a trade
  /// result; the two phases share one flag and the retry button picks the
  /// right method depending on whether channels were loaded.
  bool _isRequestingTrade = false;
  bool _isPolling = false;
  String? _errorMessage;

  TradeChannel? _selectedChannel;
  List<TradeChannel> _channels = [];
  PayTradeResult? _tradeResult;
  late PayOrder _order = widget.order;

  /// Whether channel switching is disabled: resumed orders (entered with an
  /// existing channel) or an explicit user pick locks the choice.
  bool _channelLocked = false;

  static const _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    // Resumed orders (e.g. "继续支付") already carry a channel; lock it.
    _channelLocked = widget.order.tradeChannel != null;
    _loadChannels();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() => _isRequestingTrade = true);
    try {
      final channels = await _serviceProvider.paymentService.getTradeChannels(
        widget.project.id,
      );
      if (!mounted) return;
      if (channels.isEmpty) {
        setState(() {
          _errorMessage = '无可用支付渠道';
          _isRequestingTrade = false;
        });
        return;
      }
      // Fresh orders start with no channel selected so the user makes the
      // choice (or there is no choice with a single channel); resumed
      // orders keep their existing channel.
      final resumedCode = widget.order.tradeChannel;
      final selected = channels.length == 1
          ? channels.first
          : resumedCode == null
          ? null
          : channels.firstWhere(
              (c) => c.code == resumedCode,
              orElse: () => channels.first,
            );
      setState(() {
        _channels = channels;
        _selectedChannel = selected;
        _isRequestingTrade = false;
      });
      if (selected != null) await _requestTrade();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isRequestingTrade = false;
      });
    }
  }

  Future<void> _requestTrade() async {
    final channel = _selectedChannel;
    final orderNo = _order.orderNo;
    if (channel == null || orderNo == null) return;

    setState(() {
      _isRequestingTrade = true;
      _errorMessage = null;
      _tradeResult = null;
    });
    try {
      final result = await _serviceProvider.paymentService.toPayOrderTrade(
        orderNo,
        channel.code,
      );
      if (!mounted) return;
      setState(() {
        _tradeResult = result;
        _isRequestingTrade = false;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isRequestingTrade = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOrderState());
  }

  Future<void> _pollOrderState() async {
    if (_isPolling) return;
    _isPolling = true;
    try {
      final order = await _serviceProvider.paymentService.getOrderById(
        _order.id,
      );
      if (!mounted) return;
      setState(() => _order = order);
      if (order.isCompleted) {
        _pollTimer?.cancel();
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PayResultPage(
              project: widget.project,
              order: order,
              isSuccess: true,
            ),
          ),
        );
      }
    } catch (e) {
      // Keep polling silently; transient errors are not fatal.
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _confirmExit() async {
    if (_order.isCompleted) return;

    final close = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃支付'),
        content: const Text('是否要关闭此未支付订单？关闭后可以重新创建订单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留订单'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('关闭订单'),
          ),
        ],
      ),
    );

    if (close == true) {
      try {
        await _serviceProvider.paymentService.closeOrder(_order.id);
      } catch (e) {
        // Ignore close failures on exit.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _confirmExit();
        if (mounted) {
          _pollTimer?.cancel();
          // Use the State's context: the build method's parameter may not
          // survive this async gap.
          Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        appBar: PageAppBar(title: widget.project.projectName),
        body: Column(
          children: [
            buildStepIndicator(context, 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showSelector = _channels.length > 1;
                      if (showSelector && constraints.maxWidth >= 560) {
                        // Wide layout: amount and channel selector side by
                        // side with equal heights, the QR area below spans
                        // the full content width.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildOrderSummary(theme),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: _buildChannelSelector(theme),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildQrcodeArea(theme),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildOrderSummary(theme),
                          if (showSelector) ...[
                            const SizedBox(height: 16),
                            _buildChannelSelector(theme),
                          ],
                          const SizedBox(height: 16),
                          _buildQrcodeArea(theme),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应缴金额',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatCents(_order.payableAmount ?? _order.amount)} 元',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (_order.orderNo != null) ...[
              const SizedBox(height: 4),
              Text(
                '订单号 ${_order.orderNo}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSelector(ThemeData theme) {
    return Card(
      child: RadioGroup<String>(
        groupValue: _selectedChannel?.code,
        onChanged: (value) {
          if (value == null || value == _selectedChannel?.code) return;
          final channel = _channels.firstWhere((c) => c.code == value);
          setState(() {
            _selectedChannel = channel;
            _channelLocked = true;
          });
          _requestTrade();
        },
        child: Column(
          children: _channels
              .map(
                (channel) => RadioListTile<String>(
                  // A resumed order's channel or an explicit user pick must
                  // not be switched afterwards.
                  enabled: !_channelLocked,
                  value: channel.code,
                  title: Row(
                    children: [
                      _buildChannelIcon(channel),
                      const SizedBox(width: 8),
                      Text(channel.channelName ?? channel.code),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  /// Shows the platform-provided channel logo when available, falling back
  /// to the built-in icon.
  Widget _buildChannelIcon(TradeChannel channel) {
    final url = channel.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 24,
        height: 24,
        errorBuilder: (context, error, stackTrace) =>
            Icon(channelIcon(channel.code)),
      );
    }
    return Icon(channelIcon(channel.code));
  }

  Widget _buildQrcodeArea(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(width: 220, height: 220, child: _buildQrcodeBody(theme)),
            const SizedBox(height: 12),
            Text(
              '请使用${paymentChannels[_selectedChannel?.code]?.label ?? '指定渠道'}扫码支付',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrcodeBody(ThemeData theme) {
    if (_isRequestingTrade) {
      return const Center(child: CircularProgressIndicator());
    }
    final urlCode = _tradeResult?.urlCode;
    if (urlCode != null) {
      return QrImageView(
        data: urlCode,
        size: 220,
        backgroundColor: Colors.white,
      );
    }
    if (_selectedChannel == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payments_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          const Text('请先选择支付方式'),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 8),
        Text(_errorMessage ?? '二维码获取失败', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () =>
              _channels.isEmpty ? _loadChannels() : _requestTrade(),
          child: const Text('重试'),
        ),
      ],
    );
  }
}
