import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/payment/exceptions.dart';
import '/services/provider.dart';
import '/types/payment.dart';
import 'common.dart';
import 'dialog_detail.dart';
import 'pay_qrcode.dart';

/// Formats a platform datetime string ("yyyy-MM-dd HH:mm:ss") as
/// "yyyy-MM-dd HH:mm"; returns null when unparseable.
String? _formatMinute(String? raw) {
  if (raw == null) return null;
  final time = DateTime.tryParse(raw);
  if (time == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

/// The "历史订单" tab content.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => OrdersTabState();
}

class OrdersTabState extends State<OrdersTab>
    with AutomaticKeepAliveClientMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final ScrollController _scrollController = ScrollController();

  List<PayOrder> _orders = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _statusFilter = '';

  static const Map<String, String> _statusOptions = {
    '': '全部',
    '101': '待支付',
    '102': '支付中',
    '103': '支付成功',
    '005': '已过期',
    '006': '已取消',
  };

  @override
  bool get wantKeepAlive => true;

  /// Reloads the first page with the current filter; exposed for the parent
  /// page to refresh the list after any payment flow returns.
  Future<void> reload() => _loadOrders();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await _serviceProvider.paymentService.pageOrders(
        displayStatus: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _orders = page.records;
        _currentPage = page.current;
        _totalPages = page.pages;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final page = await _serviceProvider.paymentService.pageOrders(
        pageCurrent: _currentPage + 1,
        displayStatus: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _orders.addAll(page.records);
        _currentPage = page.current;
        _totalPages = page.pages;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _continuePay(PayOrder order) async {
    final service = _serviceProvider.paymentService;
    // Refresh the order and gate terminal states locally first: the
    // platform's canPay rejects completed orders with a raw error message
    // but still passes for cancelled/expired ones.
    PayOrder? fresh;
    try {
      fresh = await service.getOrderById(order.id);
      if (!mounted) return;
      if (!fresh.isPending) {
        final stateText = _statusOptions[fresh.displayStatus] ?? '已结束';
        showMessage(context, '该订单$stateText，无法继续支付');
        return;
      }
      await service.canPay(order.id);
    } on PaymentServiceException catch (e) {
      if (!mounted) return;
      showError(context, e);
      return;
    }
    final freshOrder = fresh;

    if (!mounted) return;
    final project = PayProject(
      id: freshOrder.projectId ?? order.projectId ?? '',
      projectName: freshOrder.projectName ?? order.projectName ?? '缴费',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayQrcodePage(project: project, order: freshOrder),
      ),
    );
    _loadOrders();
  }

  Future<void> _closeOrder(PayOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭订单'),
        content: Text('确定关闭订单 ${order.orderNo ?? ''} 吗？关闭后需重新创建订单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _serviceProvider.paymentService.closeOrder(order.id);
      if (!mounted) return;
      showMessage(context, '订单已关闭');
      _loadOrders();
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
    }
  }

  Future<void> _showDetail(PayOrder order) async {
    await showDialog(
      context: context,
      builder: (_) => OrderDetailDialog(order: order),
    );
  }

  Future<void> _openBill(PayOrder order) async {
    try {
      final url = await _serviceProvider.paymentService.getBillUrl(
        order.orderNo ?? '',
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        showMessage(context, '无法打开票据链接');
      }
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '状态筛选',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            initialValue: _statusFilter,
            isExpanded: true,
            items: _statusOptions.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null || value == _statusFilter) return;
              setState(() {
                _statusFilter = value;
                // Clear the old list so the loading spinner shows
                // instead of keeping stale orders from the previous
                // status filter.
                _orders = [];
              });
              _loadOrders();
            },
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return buildErrorRetry(_errorMessage!, _loadOrders);
    }
    if (_orders.isEmpty) {
      return const Center(child: Text('暂无订单'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(PayOrder order) {
    final theme = Theme.of(context);
    final statusText =
        _statusOptions[order.displayStatus] ?? order.status ?? '未知';
    final closed = _formatMinute(order.actualCloseTime);
    final created = closed == null ? _formatMinute(order.createDate) : null;
    final timeText = closed != null
        ? '已于 $closed 结单'
        : created != null
        ? '已于 $created 发起'
        : '';
    final meta = timeText.isEmpty
        ? '${formatCents(order.amount)} 元'
        : '${formatCents(order.amount)} 元 · $timeText';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.projectName ?? order.productDesc ?? '缴费订单',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: order.isPending
                        ? theme.colorScheme.primary
                        : (order.isCompleted ? Colors.green : Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (order.isPending) ...[
                  TextButton(
                    onPressed: () => _continuePay(order),
                    child: const Text('继续支付'),
                  ),
                  TextButton(
                    onPressed: () => _closeOrder(order),
                    child: const Text('关闭订单'),
                  ),
                ],
                TextButton(
                  onPressed: () => _showDetail(order),
                  child: const Text('详情'),
                ),
                if (order.isCompleted && order.isKp == '1')
                  TextButton(
                    onPressed: () => _openBill(order),
                    child: const Text('查看发票'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
