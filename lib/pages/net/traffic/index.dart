import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '/pages/net/dashboard/dialog_login.dart';
import '/types/net.dart';
import '/utils/app_bar.dart';
import '/utils/page_mixins.dart';
import '/utils/sync_embeded.dart';

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
                  NetTrafficSection(
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

class NetTrafficSection extends StatefulWidget {
  const NetTrafficSection({
    super.key,
    required this.year,
    required this.bills,
    required this.onYearChanged,
    required this.isLoading,
  });

  final int year;
  final List<MonthlyBill> bills;
  final ValueChanged<int> onYearChanged;
  final bool isLoading;

  @override
  State<NetTrafficSection> createState() => _NetTrafficSectionState();
}

class _NetTrafficSectionState extends State<NetTrafficSection> {
  bool _optimizeDataFormat = true;

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
                Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('流量查询', style: theme.textTheme.titleLarge),
                if (widget.isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: widget.isLoading
                      ? null
                      : () => widget.onYearChanged(widget.year - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${widget.year} 年', style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: widget.isLoading
                      ? null
                      : () => widget.onYearChanged(widget.year + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.bills.isNotEmpty) ...[
              _buildUsageChart(theme),
              const SizedBox(height: 16),
            ],
            if (widget.bills.isEmpty)
              SizedBox(
                height: 200,
                child: Center(
                  child: widget.isLoading
                      ? Text('正在载入流量查询', style: theme.textTheme.bodyMedium)
                      : Text(
                          '未能载入流量查询结果\n或所选时间没有账单',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                ),
              )
            else ...[
              _buildBillTable(theme),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swipe,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '移动端左右滑动即可查看\n桌面端使用 Shift + 鼠标滚轮查看',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _optimizeDataFormat,
                    onChanged: (value) {
                      setState(() {
                        _optimizeDataFormat = value ?? true;
                      });
                    },
                  ),
                  Text('自动单位换算', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillTable(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          columns: const [
            DataColumn(label: Text('开始日期')),
            DataColumn(label: Text('结束日期')),
            DataColumn(label: Text('套餐类型')),
            DataColumn(label: Text('基本月租')),
            DataColumn(label: Text('时长/流量计费')),
            DataColumn(label: Text('使用时长')),
            DataColumn(label: Text('使用流量')),
            DataColumn(label: Text('出账时间')),
          ],
          rows: widget.bills
              .map(
                (bill) => DataRow(
                  cells: [
                    DataCell(Text(_formatDate(bill.startDate))),
                    DataCell(Text(_formatDate(bill.endDate))),
                    DataCell(
                      Text(bill.packageName.isEmpty ? '--' : bill.packageName),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(bill.monthlyFee),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatCurrency(bill.usageFee),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatDuration(bill.usageDurationMinutes),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatDataSize(bill.usageFlowMb),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    DataCell(Text(_formatDateTime(bill.createTime))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';
  }

  String _formatCurrency(double value) {
    if (value == 0) {
      return '--';
    }
    return '${value.toStringAsFixed(2)} 元';
  }

  String _formatDuration(double minutes) {
    if (!_optimizeDataFormat) {
      return '${minutes.toStringAsFixed(0)} 分钟';
    }

    final totalMinutes = minutes.toInt();
    if (totalMinutes >= 60 * 24) {
      final days = totalMinutes ~/ (60 * 24);
      return '$days 天';
    } else if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      return '$hours 小时';
    } else {
      return '$totalMinutes 分钟';
    }
  }

  String _formatDataSize(double mb) {
    if (!_optimizeDataFormat) {
      return '${mb.toStringAsFixed(3)} MB';
    }

    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(3)} GB';
    } else {
      return '${mb.toStringAsFixed(3)} MB';
    }
  }

  Widget _buildUsageChart(ThemeData theme) {
    final monthlyData = _aggregateMonthlyUsage();
    final chartConfig = _calculateChartConfig(monthlyData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '流量使用量统计',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: monthlyData.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value / chartConfig.unitDivisor,
                          color: theme.colorScheme.primary,
                          width: 10 + 60 / monthlyData.length,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: theme.textTheme.bodySmall,
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(chartConfig.decimalPlaces)}${chartConfig.unitSuffix}',
                            style: theme.textTheme.bodySmall,
                          );
                        },
                        reservedSize: 45,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartConfig.interval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          theme.colorScheme.surfaceContainerHighest,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final originalValue = monthlyData[group.x] ?? 0;
                        return BarTooltipItem(
                          '${group.x}月\n${_formatDataSize(originalValue)}',
                          theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        );
                      },
                    ),
                  ),
                  maxY: chartConfig.maxY,
                  minY: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<int, double> _aggregateMonthlyUsage() {
    final monthlyUsage = <int, double>{};

    for (final bill in widget.bills) {
      final month = bill.startDate.month;
      monthlyUsage[month] = (monthlyUsage[month] ?? 0) + bill.usageFlowMb;
    }

    return monthlyUsage;
  }

  _ChartConfig _calculateChartConfig(Map<int, double> monthlyData) {
    if (monthlyData.isEmpty) {
      return _ChartConfig(
        unitDivisor: 1,
        unitSuffix: 'MB',
        decimalPlaces: 0,
        interval: 100,
        maxY: 1000,
      );
    }

    final maxValue = monthlyData.values.reduce((a, b) => a > b ? a : b);

    if (maxValue >= 1024) {
      final maxInGB = maxValue / 1024;
      final interval = _calculateOptimalInterval(maxInGB);
      return _ChartConfig(
        unitDivisor: 1024,
        unitSuffix: 'GB',
        decimalPlaces: maxInGB < 10 ? 1 : 0,
        interval: interval,
        maxY: _calculateOptimalMaxY(maxInGB, interval),
      );
    } else {
      final interval = _calculateOptimalInterval(maxValue);
      return _ChartConfig(
        unitDivisor: 1,
        unitSuffix: 'MB',
        decimalPlaces: 0,
        interval: interval,
        maxY: _calculateOptimalMaxY(maxValue, interval),
      );
    }
  }

  double _calculateOptimalInterval(double maxValue) {
    if (maxValue <= 10) return 1;
    if (maxValue <= 50) return 5;
    if (maxValue <= 100) return 10;
    if (maxValue <= 500) return 50;
    if (maxValue <= 1000) return 100;
    if (maxValue <= 5000) return 500;
    return 1000;
  }

  double _calculateOptimalMaxY(double maxValue, double interval) {
    final intervals = (maxValue / interval).ceil();
    return intervals * interval;
  }
}

class _ChartConfig {
  final double unitDivisor;
  final String unitSuffix;
  final int decimalPlaces;
  final double interval;
  final double maxY;

  const _ChartConfig({
    required this.unitDivisor,
    required this.unitSuffix,
    required this.decimalPlaces,
    required this.interval,
    required this.maxY,
  });
}
