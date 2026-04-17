import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/pages/net/common/dialog_login.dart';
import '/types/net.dart';
import '/utils/app_bar.dart';
import '/utils/page_mixins.dart';
import '/utils/sync_embeded.dart';
import 'dialog_device_show.dart';
import 'bill.dart';

class NetTrafficPage extends StatefulWidget {
  const NetTrafficPage({super.key});

  @override
  State<NetTrafficPage> createState() => _NetTrafficPageState();
}

class _NetTrafficPageState extends State<NetTrafficPage>
    with PageStateMixin, LoadingStateMixin {
  List<NetOnlineSession>? _onlineSessions;
  final ValueNotifier<List<NetOnlineSession>> _onlineSessionsNotifier =
      ValueNotifier<List<NetOnlineSession>>([]);
  List<MonthlyBill>? _monthlyBills;
  static const Duration _requestInterval = Duration(seconds: 2);

  Timer? _refreshTimer;
  bool _isRefreshingOnlineSessions = false;

  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  bool _isLoadingLogin = false;

  bool get _isOnline => serviceProvider.netService.isOnline;

  @override
  void onServiceInit() {
    _refreshData();
    if (_isOnline) {
      _startAutoRefreshOnlineSessions();
    }
  }

  @override
  void onServiceStatusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      if (_isOnline) {
        _startAutoRefreshOnlineSessions();
        _refreshData();
      } else {
        _stopAutoRefreshOnlineSessions();
        setState(() {
          _onlineSessions = null;
          _onlineSessionsNotifier.value = [];
          _monthlyBills = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _stopAutoRefreshOnlineSessions();
    _onlineSessionsNotifier.dispose();
    super.dispose();
  }

  void _startAutoRefreshOnlineSessions() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_requestInterval, (timer) {
      if (!mounted) return;

      _refreshOnlineSessionsSilently();
    });
  }

  void _stopAutoRefreshOnlineSessions() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshOnlineSessionsSilently() async {
    if (!_isOnline || _isRefreshingOnlineSessions) return;

    _isRefreshingOnlineSessions = true;
    try {
      final onlineSessions = await serviceProvider.netService
          .getOnlineSessionList();
      if (!mounted) return;
      setState(() {
        _onlineSessions = onlineSessions;
      });
      _onlineSessionsNotifier.value = onlineSessions;
    } catch (_) {
      // Keep the old value when transient refresh errors happen.
    } finally {
      _isRefreshingOnlineSessions = false;
    }
  }

  Future<void> _refreshData() async {
    if (!_isOnline) {
      setState(() {
        _onlineSessions = null;
        _onlineSessionsNotifier.value = [];
        _monthlyBills = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _onlineSessions = null;
      _onlineSessionsNotifier.value = [];
      _monthlyBills = null;
    });

    try {
      final results = await Future.wait([
        serviceProvider.netService.getOnlineSessionList(),
        serviceProvider.netService.getMonthPay(year: _selectedYear),
      ]);

      final onlineSessions = results[0] as List<NetOnlineSession>;
      final monthlyBills = results[1] as List<MonthlyBill>;
      final sortedBills = List<MonthlyBill>.from(monthlyBills)
        ..sort((a, b) => a.createTime.compareTo(b.createTime));

      if (!mounted) return;
      setState(() {
        _onlineSessions = onlineSessions;
        _onlineSessionsNotifier.value = onlineSessions;
        _monthlyBills = sortedBills;
      });
    } catch (e) {
      if (!mounted) return;
      setError('刷新流量查询失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _onlineSessions = null;
          _onlineSessionsNotifier.value = [];
          _monthlyBills = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLoginDialog() async {
    setState(() => _isLoadingLogin = true);
    try {
      final result = await showDialog<NetUserIntegratedData>(
        context: context,
        builder: (context) => NetLoginDialog(),
      );

      if (result != null) {
        await _refreshData();
      }
    } finally {
      if (mounted) setState(() => _isLoadingLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '校园网流量查询'),
      body: SyncPowered(childBuilder: (context) => _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage ?? '未知错误',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: clearError,
                            icon: Icon(
                              Icons.close,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasError) const SizedBox(height: 16),
                if (!_isOnline) _buildLoginGuideCard(theme),
                if (_isOnline) ...[
                  NetOnlineSessionSection(
                    sessions: _onlineSessions ?? [],
                    sessionsListenable: _onlineSessionsNotifier,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  NetMonthlyBillSection(
                    year: _selectedYear,
                    bills: _monthlyBills ?? [],
                    onYearChanged: (newYear) {
                      if (newYear < 1970 || newYear > DateTime.now().year) {
                        return;
                      }
                      setState(() {
                        _selectedYear = newYear;
                      });
                      _refreshData();
                    },
                    isLoading: _isLoading,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginGuideCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                Text('请先登录自助服务', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '当前未登录校园网自助服务。\n'
              '请先登录后再进行流量查询。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoadingLogin ? null : _showLoginDialog,
              icon: _isLoadingLogin
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
}

class NetOnlineSessionSection extends StatelessWidget {
  final List<NetOnlineSession> sessions;
  final ValueListenable<List<NetOnlineSession>> sessionsListenable;
  final bool isLoading;

  const NetOnlineSessionSection({
    super.key,
    required this.sessions,
    required this.sessionsListenable,
    required this.isLoading,
  });

  Widget _buildOnlineSessionListTile(
    ThemeData theme,
    BuildContext context,
    NetOnlineSession session,
  ) {
    var displayMac = session.mac.toUpperCase();
    if (RegExp(r'^[0-9A-F]{12}$').hasMatch(displayMac)) {
      displayMac = displayMac.replaceAllMapped(
        RegExp(r'.{2}'),
        (match) => '${match.group(0)}:',
      );
      displayMac = displayMac.substring(0, displayMac.length - 1);
    }

    final deviceName = session.deviceName.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.link, size: 22, color: theme.colorScheme.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayMac,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  deviceName.isNotEmpty ? deviceName : '未命名设备',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 20,
            color: theme.colorScheme.primary,
            onPressed: () => showDialog(
              context: context,
              builder: (context) => NetOnlineDeviceShowDialog(
                session: session,
                sessionsListenable: sessionsListenable,
              ),
            ),
            icon: const Icon(Icons.info_outline),
            tooltip: '详情',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text('在线设备', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    isLoading ? '正在载入在线设备' : '当前无在线设备',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _buildOnlineSessionListTile(theme, context, session);
                },
              ),
          ],
        ),
      ),
    );
  }
}
