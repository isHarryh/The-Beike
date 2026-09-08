import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/services/store/base.dart';
import '/types/courses.dart';
import '/types/preferences.dart';
import '/types/base.dart';

String formatCacheTime(BaseDataClass cachedData) {
  final time = cachedData.$lastUpdateTime!;
  final dateString =
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  final timeString =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return '$dateString $timeString';
}

// Curriculum settings helpers

CurriculumSettings readCurriculumSettings(BaseStoreService store) {
  return store.getPref<CurriculumSettings>(
        "curriculum",
        CurriculumSettings.fromJson,
      ) ??
      CurriculumSettings.defaultSettings;
}

void saveCurriculumSettings(BaseStoreService store, CurriculumSettings settings) {
  store.putPref<CurriculumSettings>("curriculum", settings);
}

// Week selector

class CurriculumWeekSelector extends StatelessWidget {
  final int currentWeek;
  final int maxWeek;
  final int? todayWeek;
  final ValueChanged<int> onWeekChanged;

  const CurriculumWeekSelector({
    super.key,
    required this.currentWeek,
    required this.maxWeek,
    this.todayWeek,
    required this.onWeekChanged,
  });

  void _gotoWeekSafe(int newWeek) {
    newWeek = newWeek.clamp(1, maxWeek);
    if (newWeek == currentWeek) return;
    onWeekChanged(newWeek);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _gotoWeekSafe(currentWeek - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _showWeekJumper(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第 $currentWeek 周',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: currentWeek >= maxWeek ? '已经到最大周次了~' : '',
          child: IconButton(
            onPressed: () => _gotoWeekSafe(currentWeek + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }

  void _showWeekJumper(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            const Text('周次跳转'),
          ],
        ),
        content: SizedBox(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(maxWeek, (index) {
                  final week = index + 1;
                  final isCurrentWeek = week == currentWeek;
                  final isTodayWeek = week == todayWeek;

                  return FilterChip(
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$week'),
                        if (isCurrentWeek) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                        if (isTodayWeek && !isCurrentWeek) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.today,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ],
                    ),
                    selected: false,
                    onSelected: (selected) {
                      Navigator.of(context).pop();
                      _gotoWeekSafe(week);
                    },
                    backgroundColor: isCurrentWeek
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.6)
                        : null,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChooseCacheCard extends StatelessWidget {
  final CurriculumIntegratedData cachedData;
  final VoidCallback onSubmit;
  final bool useFlexLayout;
  final bool isLoading;

  const ChooseCacheCard({
    super.key,
    required this.cachedData,
    required this.onSubmit,
    this.useFlexLayout = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = cachedData;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: useFlexLayout ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '使用缓存课表',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '直接查看之前缓存的课表',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '缓存时间：${formatCacheTime(cachedData)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data.currentTerm.year}学年 第${data.currentTerm.season}学期',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (useFlexLayout) const Spacer(),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.visibility),
                label: Text(isLoading ? '加载中' : '查看'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChooseLatestCard extends StatefulWidget {
  final bool isLoggedIn;
  final ValueChanged<TermInfo>? onTermSelected;
  final bool useFlexLayout;
  final bool isLoading;
  final Future<List<TermInfo>> Function() getTerms;

  const ChooseLatestCard({
    super.key,
    required this.isLoggedIn,
    required this.getTerms,
    this.onTermSelected,
    this.useFlexLayout = false,
    this.isLoading = false,
  });

  @override
  State<ChooseLatestCard> createState() => _ChooseLatestCardState();
}

class _ChooseLatestCardState extends State<ChooseLatestCard> {
  TermInfo? _selectedTerm;
  List<TermInfo>? _availableTerms;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _loadTerms();
    }
  }

  @override
  void didUpdateWidget(ChooseLatestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When login status changes from false to true, load terms
    if (!oldWidget.isLoggedIn && widget.isLoggedIn) {
      _loadTerms();
    }
  }

  Future<void> _loadTerms() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final terms = await widget.getTerms();
      if (mounted) {
        setState(() {
          _availableTerms = terms;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _availableTerms = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: widget.useFlexLayout
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.refresh,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '获取最新课表',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '获取并查看指定学期的最新课表',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.isLoggedIn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.login,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      onPressed: () =>
                          context.router.pushPath('/courses/account'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请先登录以获取学期列表',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_availableTerms == null && _errorMessage == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('正在加载学期列表...'),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '加载失败：$_errorMessage',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_availableTerms == null || _availableTerms!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '暂无可用学期',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<TermInfo>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '选择学期',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                initialValue: _selectedTerm,
                isExpanded: true,
                items: _availableTerms!.map((term) {
                  return DropdownMenuItem<TermInfo>(
                    value: term,
                    child: Text('${term.year}学年 第${term.season}学期'),
                  );
                }).toList(),
                onChanged: (TermInfo? value) {
                  setState(() {
                    _selectedTerm = value;
                  });
                },
              ),
            const SizedBox(height: 24),
            if (widget.useFlexLayout) const Spacer(),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isLoading
                    ? null
                    : (widget.isLoggedIn &&
                              _selectedTerm != null &&
                              widget.onTermSelected != null
                          ? () => widget.onTermSelected!(_selectedTerm!)
                          : null),
                icon: widget.isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.visibility),
                label: Text(widget.isLoading ? '加载中' : '查看'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
