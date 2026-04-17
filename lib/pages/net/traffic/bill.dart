import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '/types/net.dart';

class NetMonthlyBillSection extends StatefulWidget {
  const NetMonthlyBillSection({
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
  State<NetMonthlyBillSection> createState() => _NetMonthlyBillSectionState();
}

class _NetMonthlyBillSectionState extends State<NetMonthlyBillSection> {
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
                Text('月度账单', style: theme.textTheme.titleLarge),
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
                      ? Text('正在载入月度账单', style: theme.textTheme.bodyMedium)
                      : Text(
                          '未能载入账单\n或所选时间没有账单',
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
      // GB
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
      // MB
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
