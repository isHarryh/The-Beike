import 'dart:async';

import 'package:flutter/material.dart';
import '/services/payment/exceptions.dart';
import '/services/provider.dart';
import '/types/payment.dart';
import '/utils/app_bar.dart';
import 'common.dart';
import 'create_amount.dart';
import 'create_tuition.dart';
import 'dialog_login.dart';
import 'orders.dart';
import 'pay_qrcode.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with SingleTickerProviderStateMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  late final TabController _tabController;
  final GlobalKey<OrdersTabState> _ordersTabKey = GlobalKey<OrdersTabState>();

  PayUserInfo? _userInfo;
  bool _isLoadingUser = false;
  bool _isLoggingIn = false;
  bool _isLoggingOut = false;

  List<PayProject> _projects = [];
  bool _isLoadingProjects = false;
  String? _projectsErrorMessage;

  // Pre-fetched per-project info shown on the cards; keyed by project id.
  final Map<String, NetAccBalance> _netBalances = {};
  final Map<String, String> _eCardBalances = {};
  List<TuitionFeeRow>? _tuitionRows;
  final Map<String, String> _projectErrors = {};
  final Set<String> _projectLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _serviceProvider.addListener(_onServiceStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  /// Whether a user is logged in with info loaded; drives the account card
  /// and the visibility of the project/order tabs.
  bool get _isLoggedIn =>
      _serviceProvider.paymentService.isOnline && _userInfo != null;

  Future<void> _refreshAll() async {
    final service = _serviceProvider.paymentService;
    if (service.isOnline) {
      await _loadUserInfo();
      await _loadProjects();
      unawaited(_ordersTabKey.currentState?.reload());
    } else {
      if (!mounted) return;
      setState(() {
        _userInfo = null;
        _projects = [];
        _netBalances.clear();
        _eCardBalances.clear();
        _tuitionRows = null;
        _projectErrors.clear();
        _projectLoading.clear();
      });
      unawaited(_ordersTabKey.currentState?.reload());
    }
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoadingUser = true);
    try {
      final user = await _serviceProvider.paymentService.getUserInfo();
      if (!mounted) return;
      setState(() => _userInfo = user);
    } catch (e) {
      // Keep the last user info; the service error card already reflects state.
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsErrorMessage = null;
    });
    try {
      final projects = await _serviceProvider.paymentService
          .getRecommendedProjects();
      if (!mounted) return;
      setState(() => _projects = projects);
      _loadProjectInfos();
    } catch (e) {
      if (!mounted) return;
      setState(() => _projectsErrorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  /// Clears pre-fetched project info and refetches it for every project.
  void _loadProjectInfos() {
    setState(() {
      _netBalances.clear();
      _eCardBalances.clear();
      _tuitionRows = null;
      _projectErrors.clear();
      _projectLoading.clear();
    });
    for (final project in _projects) {
      switch (project.proModelUrl) {
        case 'eCardRecharge':
        case 'netCost':
        case 'tuitionAndDorm':
          unawaited(_loadProjectInfo(project));
      }
    }
  }

  Future<void> _loadProjectInfo(PayProject project) async {
    final service = _serviceProvider.paymentService;
    final id = project.id;
    setState(() {
      _projectLoading.add(id);
      _projectErrors.remove(id);
    });
    try {
      final user = service.cachedUserInfo ?? await service.getUserInfo();
      switch (project.proModelUrl) {
        case 'eCardRecharge':
          final balance = await service.getECardBalance(user.idserial, id);
          if (!mounted) return;
          setState(() => _eCardBalances[id] = balance);
        case 'netCost':
          final balance = await service.getNetAccBalance(user.idserial, id);
          if (!mounted) return;
          setState(() => _netBalances[id] = balance);
        case 'tuitionAndDorm':
          final rows = await service.getTuitionList(user.idserial);
          if (!mounted) return;
          setState(() => _tuitionRows = rows);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _projectErrors[id] = e.toString());
    } finally {
      if (mounted) setState(() => _projectLoading.remove(id));
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoggingIn = true);
    await showPaymentLoginDialog(context, onLoginSuccess: _refreshAll);
    if (!mounted) return;
    setState(() => _isLoggingIn = false);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('是否确认登出此账户？'),
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

    setState(() => _isLoggingOut = true);
    try {
      await _serviceProvider.paymentService.logout();
      _serviceProvider.storeService.delConfig('payment_account_data');
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _startProjectFlow(PayProject project) async {
    final service = _serviceProvider.paymentService;

    // Check for pending orders on this project first.
    try {
      await service.checkProjectPayable(project.id);
    } on PaymentPendingOrderException catch (e) {
      if (!mounted) return;
      final order = await resolvePendingOrderFlow(context, e);
      if (order == null || !mounted) return;
      await _openQrcodePage(project, order);
      return;
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      return;
    }

    if (!mounted) return;
    switch (project.proModelUrl) {
      case 'tuitionAndDorm':
        final created = await Navigator.push<PayOrder>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TuitionCreatePage(project: project, initialRows: _tuitionRows!),
          ),
        );
        if (created != null && mounted) {
          await _openQrcodePage(project, created);
        } else if (mounted) {
          // Returned without creating an order; refresh the tabs anyway.
          unawaited(_refreshAll());
        }
      case 'eCardRecharge':
      case 'netCost':
        final created = await Navigator.push<PayOrder>(
          context,
          MaterialPageRoute(
            builder: (_) => AmountCreatePage(
              project: project,
              initialNetBalance: _netBalances[project.id],
              initialECardBalance: _eCardBalances[project.id],
            ),
          ),
        );
        if (created != null && mounted) {
          await _openQrcodePage(project, created);
        } else if (mounted) {
          // Returned without creating an order; refresh the tabs anyway.
          unawaited(_refreshAll());
        }
      default:
        showMessage(context, '暂不支持该缴费项目');
    }
  }

  Future<void> _openQrcodePage(PayProject project, PayOrder order) async {
    final service = _serviceProvider.paymentService;
    if (order.projectId != null) {
      service.cacheProjectId(order.projectId!);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayQrcodePage(project: project, order: order),
      ),
    );
    unawaited(_refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '充值缴费'),
      body: Column(
        children: [
          _buildAccountCard(),
          if (_isLoggedIn) ...[
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '缴费项目'),
                Tab(text: '历史订单'),
              ],
              indicatorSize: TabBarIndicatorSize.tab,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildProjectsTab(),
                  OrdersTab(key: _ordersTabKey),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final theme = Theme.of(context);
    if (!_isLoggedIn) {
      return _buildLoginPromptCard(theme);
    }
    final user = _userInfo!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('校园缴费账户', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: _isLoadingUser ? null : _loadUserInfo,
                  icon: _isLoadingUser
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.idserial,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      label: const Text('登出'),
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: _isLoggingOut ? null : _handleLogout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPromptCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_open,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('连接校园缴费账户', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '登录后，您可以在此查看校园卡和网费余额并办理充值缴费业务。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoggingIn ? null : _handleLogin,
              icon: _isLoggingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projectsErrorMessage != null) {
      return buildErrorRetry(_projectsErrorMessage!, _loadProjects);
    }
    if (_projects.isEmpty) {
      return const Center(child: Text('暂无缴费项目'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) => _buildProjectCard(_projects[index]),
    );
  }

  Widget _buildProjectCard(PayProject project) {
    final theme = Theme.of(context);
    final error = _projectErrors[project.id];
    final isLoading = _projectLoading.contains(project.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.payment),
        title: Text(
          project.projectName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          error != null
              ? '信息获取失败'
              : switch (project.proModelUrl) {
                  'eCardRecharge' =>
                    '余额 ${_eCardBalances[project.id] ?? '--'} 元',
                  'netCost' =>
                    '余额 ${_netBalances[project.id]?.balance ?? '--'} 元',
                  'tuitionAndDorm' => _tuitionSubtitle(),
                  _ => project.engName ?? '',
                },
          style: error != null
              ? TextStyle(color: theme.colorScheme.error)
              : null,
        ),
        trailing: error != null
            ? IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '重试',
                onPressed: () => _loadProjectInfo(project),
              )
            : isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: error != null || isLoading
            ? null
            : () => _startProjectFlow(project),
      ),
    );
  }

  String _tuitionSubtitle() {
    final rows = _tuitionRows;
    if (rows == null) return '--';
    if (rows.isEmpty) return '无待缴费用';
    final totalCents = rows.fold<int>(0, (sum, row) => sum + row.payableAmount);
    return '待缴 ${rows.length} 项，合计 ${formatCents(totalCents)} 元';
  }
}
