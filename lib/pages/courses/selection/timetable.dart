import 'package:flutter/material.dart';
import '/pages/courses/curriculum/common.dart';
import '/pages/courses/curriculum/table.dart';
import '/services/courses/convert.dart';
import '/services/provider.dart';
import '/types/courses.dart';

/// Counts the (day, period) slots in the given week where a base curriculum
/// class and an overlay class collide, or where multiple overlay classes
/// collide with each other.
int countConflictsInWeek(
  CurriculumIntegratedData data,
  List<ClassItem> overlay,
  int week,
) {
  final baseCounts = <String, int>{};
  for (final classItem in data.allClasses) {
    if (classItem.weeks.contains(week)) {
      final key = '${classItem.day}-${classItem.period}';
      baseCounts[key] = (baseCounts[key] ?? 0) + 1;
    }
  }

  final overlayCounts = <String, int>{};
  for (final classItem in overlay) {
    if (classItem.weeks.contains(week)) {
      final key = '${classItem.day}-${classItem.period}';
      overlayCounts[key] = (overlayCounts[key] ?? 0) + 1;
    }
  }

  var conflicts = 0;
  final keys = {...baseCounts.keys, ...overlayCounts.keys};
  for (final key in keys) {
    final baseCount = baseCounts[key] ?? 0;
    final overlayCount = overlayCounts[key] ?? 0;
    if ((baseCount > 0 && overlayCount > 0) || overlayCount > 1) {
      conflicts++;
    }
  }
  return conflicts;
}

/// Whether any week of the term contains a conflict between the base
/// curriculum and the overlay classes.
bool hasConflictInAnyWeek(
  CurriculumIntegratedData data,
  List<ClassItem> overlay,
) {
  for (int week = 1; week <= data.getMaxValidWeekIndex(); week++) {
    if (countConflictsInWeek(data, overlay, week) > 0) {
      return true;
    }
  }
  return false;
}

/// Parses all wanted courses into overlay class items against the period
/// mapping of the given curriculum data.
ScheduleParseResult parseWantedCourses(
  CurriculumIntegratedData data,
  List<CourseInfo> wantedCourses,
) {
  final items = <ClassItem>[];
  final unparsed = <String>[];
  for (final course in wantedCourses) {
    final result = parseCourseSchedule(course, data.allPeriods);
    items.addAll(result.items);
    unparsed.addAll(result.unparsed);
  }
  return ScheduleParseResult(items, unparsed);
}

/// A compact curriculum preview for the selection flow, rendering the
/// curriculum data provided by the parent (fetched online and never touching
/// the cache system of the curriculum page) with the wanted courses overlaid
/// and time conflicts highlighted.
class SelectionTimetablePanel extends StatefulWidget {
  final CurriculumIntegratedData? curriculumData;
  final bool isLoading;
  final String? errorMessage;
  final List<CourseInfo> wantedCourses;
  final VoidCallback? onRefresh;

  const SelectionTimetablePanel({
    super.key,
    required this.wantedCourses,
    this.curriculumData,
    this.isLoading = false,
    this.errorMessage,
    this.onRefresh,
  });

  @override
  State<SelectionTimetablePanel> createState() =>
      _SelectionTimetablePanelState();
}

class _SelectionTimetablePanelState extends State<SelectionTimetablePanel> {
  int _currentWeek = 1;
  bool _weekInitialized = false;

  @override
  void initState() {
    super.initState();
    _initWeekIfNeeded();
  }

  @override
  void didUpdateWidget(SelectionTimetablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initWeekIfNeeded();
  }

  void _initWeekIfNeeded() {
    final data = widget.curriculumData;
    if (data == null) return;

    final maxWeek = data.getMaxValidWeekIndex();
    if (!_weekInitialized) {
      _weekInitialized = true;
      _currentWeek = _initialWeekOf(data);
    } else if (_currentWeek > maxWeek) {
      _currentWeek = maxWeek;
    }
  }

  int _initialWeekOf(CurriculumIntegratedData data) {
    final maxWeek = data.getMaxValidWeekIndex();
    final todayWeek = data.getWeekIndexToday();
    if (todayWeek != null && todayWeek >= 1 && todayWeek <= maxWeek) {
      return todayWeek;
    }
    return 1;
  }

  ScheduleParseResult _parseWantedCourses(CurriculumIntegratedData data) {
    return parseWantedCourses(data, widget.wantedCourses);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.curriculumData;
    final isReady =
        !widget.isLoading && widget.errorMessage == null && data != null;
    final parse = isReady ? _parseWantedCourses(data) : null;
    final conflictCount = isReady
        ? countConflictsInWeek(data, parse!.items, _currentWeek)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(conflictCount),
        const Divider(height: 1),
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : widget.errorMessage != null || data == null
              ? _buildErrorView()
              : _buildPreview(parse!),
        ),
      ],
    );
  }

  Widget _buildHeader(int conflictCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '课表预览',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (conflictCount > 0)
            Tooltip(
              message: '当前周存在时间冲突，请点击冲突格子查看详情',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$conflictCount 处冲突',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: '刷新课表',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: widget.isLoading ? null : widget.onRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ScheduleParseResult parse) {
    final data = widget.curriculumData!;
    final settings = readCurriculumSettings(
      ServiceProvider.instance.storeService,
    );
    final maxWeek = data.getMaxValidWeekIndex();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: CurriculumWeekSelector(
            currentWeek: _currentWeek,
            maxWeek: maxWeek,
            todayWeek: data.getWeekIndexToday(),
            onWeekChanged: (week) => setState(() => _currentWeek = week),
          ),
        ),
        const SizedBox(height: 4),
        if (parse.unparsed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${parse.unparsed.length} 条排课信息无法识别',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: CurriculumTable(
                  curriculumData: data,
                  availableWidth: constraints.maxWidth,
                  settings: settings,
                  weekDates: data.getWeekdayDaysOf(_currentWeek),
                  currentWeek: _currentWeek,
                  overlayClasses: parse.items,
                  blinkOverlayClasses: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.errorMessage ?? '暂无课表数据',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
