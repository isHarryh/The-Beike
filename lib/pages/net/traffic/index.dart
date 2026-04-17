import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final Map<String, _TrackedSessionSnapshot> _trackedSessionById = {};
  final Map<String, bool> _sessionTrafficActiveById = {};
  final List<_RealtimeTrafficSample> _realtimeTrafficHistory = [];

  static const Duration _requestInterval = Duration(seconds: 2);
  static const int _maxTrafficHistorySize = 60;
  static const int _maxTrackedSessionCount = 256;

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
          _clearRealtimeTrafficState();
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
        _updateRealtimeTrafficData(onlineSessions);
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
        _clearRealtimeTrafficState();
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
        _updateRealtimeTrafficData(onlineSessions);
        _monthlyBills = sortedBills;
      });
    } catch (e) {
      if (!mounted) return;
      setError('刷新流量查询失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _onlineSessions = null;
          _onlineSessionsNotifier.value = [];
          _clearRealtimeTrafficState();
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

  void _clearRealtimeTrafficState() {
    _trackedSessionById.clear();
    _sessionTrafficActiveById.clear();
    _realtimeTrafficHistory.clear();
  }

  String _buildSessionKey(NetOnlineSession session) {
    final sessionId = session.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }
    return '${session.mac.toUpperCase()}_${session.ip}';
  }

  void _updateRealtimeTrafficData(List<NetOnlineSession> sessions) {
    final now = DateTime.now();
    final activeKeys = <String>{};

    var totalDownSpeedMbPerSec = 0.0;

    for (final session in sessions) {
      final key = _buildSessionKey(session);
      activeKeys.add(key);
      var hasTrafficInLastWindow = false;

      final previous = _trackedSessionById[key];
      if (previous != null) {
        final seconds =
            now.difference(previous.sampleTime).inMilliseconds / 1000.0;
        if (seconds > 0) {
          final downDelta = session.downFlowMb - previous.downFlowMb;
          final upDelta = session.upFlowMb - previous.upFlowMb;

          if (downDelta >= 0) {
            totalDownSpeedMbPerSec += downDelta / seconds;
          }
          hasTrafficInLastWindow = downDelta > 0 || upDelta > 0;
        }
      }

      _trackedSessionById[key] = _TrackedSessionSnapshot(
        downFlowMb: session.downFlowMb,
        upFlowMb: session.upFlowMb,
        sampleTime: now,
      );
      _sessionTrafficActiveById[key] = hasTrafficInLastWindow;
    }

    _trackedSessionById.removeWhere((key, _) => !activeKeys.contains(key));
    _sessionTrafficActiveById.removeWhere(
      (key, _) => !activeKeys.contains(key),
    );
    _trimTrackedSessionMap();

    _realtimeTrafficHistory.add(
      _RealtimeTrafficSample(
        sampleTime: now,
        downSpeedMbPerSec: totalDownSpeedMbPerSec,
      ),
    );
    if (_realtimeTrafficHistory.length > _maxTrafficHistorySize) {
      _realtimeTrafficHistory.removeAt(0);
    }
  }

  void _trimTrackedSessionMap() {
    if (_trackedSessionById.length <= _maxTrackedSessionCount) {
      return;
    }

    final entries = _trackedSessionById.entries.toList()
      ..sort((a, b) => a.value.sampleTime.compareTo(b.value.sampleTime));
    final removeCount = entries.length - _maxTrackedSessionCount;

    for (var i = 0; i < removeCount; i++) {
      final key = entries[i].key;
      _trackedSessionById.remove(key);
      _sessionTrafficActiveById.remove(key);
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
                    sessionTrafficActiveById: _sessionTrafficActiveById,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  NetRealtimeTrafficSection(
                    history: _realtimeTrafficHistory,
                    isLoading: _isLoading && _onlineSessions == null,
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
  final Map<String, bool> sessionTrafficActiveById;
  final bool isLoading;

  const NetOnlineSessionSection({
    super.key,
    required this.sessions,
    required this.sessionsListenable,
    required this.sessionTrafficActiveById,
    required this.isLoading,
  });

  String _buildSessionKey(NetOnlineSession session) {
    final sessionId = session.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }
    return '${session.mac.toUpperCase()}_${session.ip}';
  }

  Widget _buildOnlineSessionListTile(
    ThemeData theme,
    BuildContext context,
    NetOnlineSession session,
  ) {
    var displayMac = session.mac.toUpperCase();
    final hasTraffic =
        sessionTrafficActiveById[_buildSessionKey(session)] ?? false;
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
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.swap_vert,
              size: 22,
              color: hasTraffic
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
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
          const SizedBox(width: 4),
          IconButton(
            iconSize: 20,
            color: theme.colorScheme.primary,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi_tethering,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('入网设备', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    isLoading ? '正在加载入网设备' : '当前无入网设备',
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

class NetRealtimeTrafficSection extends StatelessWidget {
  final List<_RealtimeTrafficSample> history;
  final bool isLoading;

  const NetRealtimeTrafficSection({
    super.key,
    required this.history,
    required this.isLoading,
  });

  String _formatSpeed(double mbPerSec) {
    if (mbPerSec < 1) {
      return '${(mbPerSec * 1024).toStringAsFixed(1)} KB/s';
    }
    return '${mbPerSec.toStringAsFixed(2)} MB/s';
  }

  LineChartData _buildChartData(ThemeData theme) {
    if (history.isEmpty) {
      return LineChartData(lineBarsData: []);
    }

    final downSpots = <FlSpot>[];
    var maxY = 0.1;

    for (var i = 0; i < history.length; i++) {
      final sample = history[i];
      downSpots.add(FlSpot(i.toDouble(), sample.downSpeedMbPerSec));

      if (sample.downSpeedMbPerSec > maxY) {
        maxY = sample.downSpeedMbPerSec;
      }
    }
    maxY = (maxY * 1.15).clamp(0.1, double.infinity);

    return LineChartData(
      minX: 0,
      maxX: (history.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: downSpots,
          isCurved: false,
          color: theme.colorScheme.primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ],
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.bodySmall,
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              const label = '总下行';
              return LineTooltipItem(
                '$label: ${_formatSpeed(spot.y)}',
                TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = history.isNotEmpty ? history.last : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.query_stats,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('实时流量', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '总下行速率：${_formatSpeed(latest?.downSpeedMbPerSec ?? 0)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (isLoading && history.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text('正在初始化实时流量数据', style: theme.textTheme.bodyMedium),
                ),
              )
            else if (history.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text('暂无可用实时数据', style: theme.textTheme.bodyMedium),
                ),
              )
            else ...[
              SizedBox(
                height: 220,
                child: LineChart(
                  _buildChartData(theme),
                  key: ValueKey(history.length),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackedSessionSnapshot {
  final double downFlowMb;
  final double upFlowMb;
  final DateTime sampleTime;

  _TrackedSessionSnapshot({
    required this.downFlowMb,
    required this.upFlowMb,
    required this.sampleTime,
  });
}

class _RealtimeTrafficSample {
  final DateTime sampleTime;
  final double downSpeedMbPerSec;

  _RealtimeTrafficSample({
    required this.sampleTime,
    required this.downSpeedMbPerSec,
  });
}
