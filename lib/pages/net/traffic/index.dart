import 'package:flutter/material.dart';
import '/pages/net/dashboard/dialog_login.dart';
import '/types/net.dart';
import '/utils/app_bar.dart';
import '/utils/page_mixins.dart';
import '/utils/sync_embeded.dart';
import 'bill.dart';

class NetTrafficPage extends StatefulWidget {
  const NetTrafficPage({super.key});

  @override
  State<NetTrafficPage> createState() => _NetTrafficPageState();
}

class _NetTrafficPageState extends State<NetTrafficPage>
    with PageStateMixin, LoadingStateMixin {
  List<NetOnlineSession>? _onlineSessions;
  List<MonthlyBill>? _monthlyBills;

  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  bool _isRefreshingOnlineDevices = false;
  bool _isLoadingLogin = false;

  bool get _isOnline => serviceProvider.netService.isOnline;

  @override
  void onServiceInit() {
    _refreshData();
  }

  @override
  void onServiceStatusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      if (_isOnline) {
        _refreshData();
      } else {
        setState(() {
          _onlineSessions = null;
          _monthlyBills = null;
        });
      }
    });
  }

  Future<void> _refreshData() async {
    if (!_isOnline) {
      setState(() {
        _onlineSessions = null;
        _monthlyBills = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _onlineSessions = null;
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
        _monthlyBills = sortedBills;
      });
    } catch (e) {
      if (!mounted) return;
      setError('刷新流量查询失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _onlineSessions = null;
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

  Future<void> _refreshOnlineSessions() async {
    if (!_isOnline) return;

    setState(() {
      _isRefreshingOnlineDevices = true;
      _onlineSessions = null;
    });

    try {
      final onlineSessions = await serviceProvider.netService
          .getOnlineSessionList();
      if (!mounted) return;
      setState(() {
        _onlineSessions = onlineSessions;
      });
    } catch (e) {
      if (!mounted) return;
      setError('刷新在线设备失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _onlineSessions = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingOnlineDevices = false;
        });
      }
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
                    isLoading: _isLoading,
                    isRefreshing: _isRefreshingOnlineDevices,
                    onRefresh: _refreshOnlineSessions,
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
  final bool isLoading;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const NetOnlineSessionSection({
    super.key,
    required this.sessions,
    required this.isLoading,
    required this.isRefreshing,
    required this.onRefresh,
  });

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60 * 24) {
      final days = minutes ~/ (60 * 24);
      final hours = (minutes % (60 * 24)) ~/ 60;
      return '${days}天${hours}小时';
    }
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final leftMinutes = minutes % 60;
      return '${hours}小时${leftMinutes}分钟';
    }
    return '${minutes}分钟';
  }

  String _formatFlow(double mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(3)} GB';
    }
    return '${mb.toStringAsFixed(3)} MB';
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
                const Spacer(),
                IconButton(
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
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
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    columns: const [
                      DataColumn(label: Text('上线时间')),
                      DataColumn(label: Text('IP地址')),
                      DataColumn(label: Text('MAC地址')),
                      DataColumn(label: Text('使用时长')),
                      DataColumn(label: Text('下行流量')),
                      DataColumn(label: Text('设备名称')),
                    ],
                    rows: sessions
                        .map(
                          (session) => DataRow(
                            cells: [
                              DataCell(
                                Text(_formatDateTime(session.loginTime)),
                              ),
                              DataCell(Text(session.ip)),
                              DataCell(Text(session.mac)),
                              DataCell(
                                Text(_formatDuration(session.useTimeMinutes)),
                              ),
                              DataCell(Text(_formatFlow(session.downFlowMb))),
                              DataCell(
                                Text(
                                  session.deviceName.trim().isEmpty
                                      ? '未命名设备'
                                      : session.deviceName,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
