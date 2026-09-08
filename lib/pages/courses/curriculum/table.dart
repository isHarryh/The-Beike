import 'package:flutter/material.dart';
import '/types/courses.dart';
import '/types/preferences.dart';

class _TimeIndicatorInfo {
  final int periodIndex;
  final bool isPreview;

  const _TimeIndicatorInfo(this.periodIndex, this.isPreview);
}

class _MajorPeriodInfo {
  final int id;
  final String name;
  final String startTime;
  final String endTime;

  _MajorPeriodInfo(this.id, this.name, this.startTime, this.endTime);
}

class CurriculumTable extends StatelessWidget {
  final CurriculumIntegratedData curriculumData;
  final double availableWidth;
  final CurriculumSettings settings;
  final Map<int, int> weekDates;
  final int currentWeek;

  /// Overlay classes (e.g. wanted courses in selection preview) rendered
  /// on top of the base curriculum. Slots shared by both layers, or by
  /// multiple overlay classes, are highlighted as conflicts.
  final List<ClassItem> overlayClasses;

  /// Whether overlay classes blink (fade in and out, ~800ms per direction)
  /// to draw attention, e.g. wanted courses in the selection preview.
  /// Slots with a base class alternate between the two layers, while empty
  /// slots fade in and out of view.
  final bool blinkOverlayClasses;

  static const Color _overlayClassColor = Color(0xFF7E57C2);

  const CurriculumTable({
    super.key,
    required this.curriculumData,
    required this.availableWidth,
    required this.settings,
    required this.weekDates,
    required this.currentWeek,
    this.overlayClasses = const [],
    this.blinkOverlayClasses = false,
  });

  List<ClassItem> get weekClasses => curriculumData.allClasses
      .where((classItem) => classItem.weeks.contains(currentWeek))
      .toList();

  List<ClassItem> get overlayWeekClasses => overlayClasses
      .where((classItem) => classItem.weeks.contains(currentWeek))
      .toList();

  static const List<String> dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  void _showClassDetails(
    BuildContext context,
    List<ClassItem> classItems,
    List<ClassItem> overlayItems,
  ) {
    final hasOverlay = overlayItems.isNotEmpty;
    final allItems = [...classItems, ...overlayItems];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(allItems.first.className),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasOverlay)
              for (final classItem in classItems) ...[
                Text('教师: ${classItem.teacherName}'),
                Text('地点: ${classItem.locationName}'),
                Text('周次: ${classItem.weeksText}'),
                Text('节次: 第${classItem.period}大节'),
              ]
            else
              for (final classItem in allItems) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: overlayClasses.contains(classItem)
                            ? _overlayClassColor.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        overlayClasses.contains(classItem) ? '备选' : '已选',
                        style: TextStyle(
                          fontSize: 10,
                          color: overlayClasses.contains(classItem)
                              ? _overlayClassColor
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('教师: ${classItem.teacherName}'),
                          Text('地点: ${classItem.locationName}'),
                          Text('周次: ${classItem.weeksText}'),
                          Text('节次: 第${classItem.period}大节'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  _TimeIndicatorInfo? _calculateTimeIndicator(
    List<_MajorPeriodInfo> majorPeriods, [
    String? debugCurrentHHmmss,
  ]) {
    final now = debugCurrentHHmmss != null
        ? DateTime.parse('1970-01-01 $debugCurrentHHmmss')
        : DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    for (int i = 0; i < majorPeriods.length; i++) {
      final period = majorPeriods[i];
      try {
        final startParts = period.startTime.split(':');
        final endParts = period.endTime.split(':');
        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        // Current time is within this period
        if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
          return _TimeIndicatorInfo(i, false);
        }

        // Current time is before this period
        if (currentMinutes < startMinutes) {
          return _TimeIndicatorInfo(i, true);
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final majorPeriods = _getMajorPeriods(curriculumData.allPeriods);
    final timeIndicatorInfo = _calculateTimeIndicator(majorPeriods);

    final displayDays = settings.calculateDisplayDays(
      weekClasses.map((c) => c.day).toSet().toList(),
    );
    final dayColumnWidth = (availableWidth - 2) / (displayDays + 1);

    String? displayMonth;
    String? displayYear;

    final calendarDays = curriculumData.calendarDays ?? const <CalendarDay>[];
    for (final calendarDay in calendarDays) {
      if (calendarDay.weekIndex == currentWeek) {
        displayMonth = '${calendarDay.month}月';
        displayYear = '${calendarDay.year}年';
      }
    }

    return Container(
      width: availableWidth,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Stack(
        children: [
          Table(
            columnWidths: {
              for (int i = 0; i <= displayDays; i++)
                i: FixedColumnWidth(dayColumnWidth),
            },
            children: [
              // Table header
              TableRow(
                children: [
                  _buildHeaderCell(
                    context,
                    displayMonth ?? '时间',
                    subtitle: displayYear,
                  ),
                  for (int day = 1; day <= displayDays; day++)
                    _buildHeaderCell(
                      context,
                      '周${dayNames[day - 1]}',
                      subtitle: weekDates[day]?.toString(),
                      isToday: day == _getTodayWeekday(),
                    ),
                ],
              ),
              // Table body
              for (
                int periodIndex = 0;
                periodIndex < majorPeriods.length;
                periodIndex++
              )
                TableRow(
                  children: [
                    _buildMajorTimeCell(
                      context,
                      settings,
                      majorPeriods[periodIndex],
                      timeIndicatorInfo,
                      periodIndex,
                    ),
                    for (int day = 1; day <= displayDays; day++)
                      _buildMajorClassCell(
                        context,
                        settings,
                        weekClasses,
                        overlayWeekClasses,
                        day,
                        majorPeriods[periodIndex],
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    String text, {
    String? subtitle,
    bool isToday = false,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isToday
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: subtitle == null ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: isToday
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isToday
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.8)
                      : Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMajorTimeCell(
    BuildContext context,
    CurriculumSettings settings,
    _MajorPeriodInfo majorPeriod,
    _TimeIndicatorInfo? arrowInfo,
    int periodIndex,
  ) {
    final cellHeight = settings.tableSize.height;
    final showArrow = arrowInfo != null && arrowInfo.periodIndex == periodIndex;

    return Container(
      height: cellHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  majorPeriod.startTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${majorPeriod.id}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  majorPeriod.endTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (showArrow)
            Positioned(
              right: 2,
              top: arrowInfo.isPreview ? 4 : cellHeight / 2 - 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  arrowInfo.isPreview ? Icons.north_east : Icons.east,
                  color: Theme.of(context).colorScheme.primary,
                  size: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMajorClassCell(
    BuildContext context,
    CurriculumSettings settings,
    List<ClassItem> weekClasses,
    List<ClassItem> overlayWeekClasses,
    int day,
    _MajorPeriodInfo majorPeriod,
  ) {
    final classesInSlot = weekClasses.where((classItem) {
      return classItem.day == day && classItem.period == majorPeriod.id;
    }).toList();

    final overlaysInSlot = overlayWeekClasses.where((classItem) {
      return classItem.day == day && classItem.period == majorPeriod.id;
    }).toList();

    final hasConflict =
        (classesInSlot.isNotEmpty && overlaysInSlot.isNotEmpty) ||
        overlaysInSlot.length > 1;

    final blink = blinkOverlayClasses && overlaysInSlot.isNotEmpty;
    final cellHeight = settings.tableSize.height;

    return Container(
      height: cellHeight,
      decoration: BoxDecoration(
        color: classesInSlot.isNotEmpty
            ? _getClassColor(classesInSlot.first)
            : overlaysInSlot.isNotEmpty
            ? (blink
                  ? Theme.of(context).colorScheme.surface
                  : _overlayClassColor)
            : Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: hasConflict
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: hasConflict ? 2 : 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: classesInSlot.isEmpty && overlaysInSlot.isEmpty
                ? const SizedBox.expand()
                : _buildClassContent(
                    context,
                    classesInSlot,
                    overlaysInSlot,
                    settings,
                  ),
          ),
          if (hasConflict)
            Positioned(
              right: 2,
              top: 2,
              child: _buildConflictBadge(context),
            ),
        ],
      ),
    );
  }

  /// Renders a warning badge visible on any background, including while a
  /// blinking overlay layer fades towards fully transparent.
  Widget _buildConflictBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(
        Icons.warning_amber_rounded,
        size: 12,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _buildClassContent(
    BuildContext context,
    List<ClassItem> classesInSlot,
    List<ClassItem> overlaysInSlot,
    CurriculumSettings settings,
  ) {
    final maxLines = settings.tableSize.height >= 100 ? 3 : 2;
    final firstClass = classesInSlot.isNotEmpty
        ? classesInSlot.first
        : overlaysInSlot.first;
    final useAnimation = settings.animationMode != AnimationMode.none;
    final blink = blinkOverlayClasses && overlaysInSlot.isNotEmpty;

    final content = blink
        ? _buildBlinkingLayers(classesInSlot, overlaysInSlot, maxLines)
        : _buildClassContentInner(
            firstClass,
            [...classesInSlot, ...overlaysInSlot],
            maxLines,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => _showClassDetails(
          context,
          classesInSlot,
          overlaysInSlot,
        ),
        splashColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.3),
        highlightColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
        child: useAnimation
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2.0),
                width: double.infinity,
                height: double.infinity,
                child: content,
              )
            : Container(
                padding: const EdgeInsets.all(2.0),
                width: double.infinity,
                height: double.infinity,
                child: content,
              ),
      ),
    );
  }

  /// Layers the base class (if any) below a blinking overlay layer: slots
  /// shared by both layers alternate between them, while overlay-only slots
  /// fade in and out of the empty cell.
  Widget _buildBlinkingLayers(
    List<ClassItem> classesInSlot,
    List<ClassItem> overlaysInSlot,
    int maxLines,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (classesInSlot.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: _getClassColor(classesInSlot.first),
            ),
            child: _buildClassContentInner(
              classesInSlot.first,
              classesInSlot,
              maxLines,
            ),
          ),
        _BlinkingOverlay(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: _overlayClassColor),
            child: _buildClassContentInner(
              overlaysInSlot.first,
              overlaysInSlot,
              maxLines,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassContentInner(
    ClassItem firstClass,
    List<ClassItem> classesInSlot,
    int maxLines,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Text(
              firstClass.className,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: maxLines,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
        if (firstClass.locationName.isNotEmpty)
          Text(
            firstClass.locationName,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
            textAlign: TextAlign.center,
            maxLines: maxLines,
            overflow: TextOverflow.fade,
          ),
        if (classesInSlot.length > 1)
          Text(
            '+${classesInSlot.length - 1}',
            style: const TextStyle(fontSize: 9, color: Colors.white70),
          ),
      ],
    );
  }

  Color _getClassColor(ClassItem classItem) {
    final hash = classItem.className.hashCode;
    final hueSteps = 18;
    final hue = (hash.abs() % hueSteps) * (360.0 / hueSteps);
    const saturation = 0.667;
    const value = 0.75;
    return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
  }

  List<_MajorPeriodInfo> _getMajorPeriods(List<ClassPeriod> periods) {
    final majorPeriodsMap = <int, List<ClassPeriod>>{};

    for (final period in periods) {
      majorPeriodsMap.putIfAbsent(period.majorId, () => []).add(period);
    }

    final majorPeriodsList = <_MajorPeriodInfo>[];

    for (final entry in majorPeriodsMap.entries) {
      final majorId = entry.key;
      final periodsInMajor = entry.value;

      if (periodsInMajor.isEmpty) continue;

      final majorName = periodsInMajor.first.majorName;

      String majorStartTime = '';
      String majorEndTime = '';

      for (final period in periodsInMajor) {
        if (period.majorStartTime != null &&
            period.majorStartTime!.isNotEmpty) {
          majorStartTime = period.majorStartTime!;
          break;
        }
      }

      for (final period in periodsInMajor) {
        if (period.majorEndTime != null && period.majorEndTime!.isNotEmpty) {
          majorEndTime = period.majorEndTime!;
          break;
        }
      }

      if (majorStartTime.isEmpty) {
        periodsInMajor.sort((a, b) => a.minorId.compareTo(b.minorId));
        majorStartTime = periodsInMajor.first.minorStartTime;
      }

      if (majorEndTime.isEmpty) {
        periodsInMajor.sort((a, b) => b.minorId.compareTo(a.minorId));
        majorEndTime = periodsInMajor.first.minorEndTime;
      }

      if (majorStartTime.isEmpty || majorEndTime.isEmpty) {
        throw StateError(
          'Incomplete data for MajorPeriod $majorId ($majorName)',
        );
      }

      majorPeriodsList.add(
        _MajorPeriodInfo(majorId, majorName, majorStartTime, majorEndTime),
      );
    }

    return majorPeriodsList;
  }

  /// Returns 1~7 for Monday~Sunday, or null if today is not in the current week
  int? _getTodayWeekday() {
    if (curriculumData.calendarDays == null ||
        curriculumData.calendarDays!.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final calendarDay in curriculumData.calendarDays!) {
      if (calendarDay.weekIndex == currentWeek) {
        final dayDate = DateTime(
          calendarDay.year,
          calendarDay.month,
          calendarDay.day,
        );
        if (dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day) {
          return calendarDay.weekday;
        }
      }
    }
    return null;
  }
}

/// Fades its child in and out continuously (~800ms per direction) to draw
/// attention. Renders the child statically when the system requests reduced
/// animations.
class _BlinkingOverlay extends StatefulWidget {
  final Widget child;

  const _BlinkingOverlay({required this.child});

  @override
  State<_BlinkingOverlay> createState() => _BlinkingOverlayState();
}

class _BlinkingOverlayState extends State<_BlinkingOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _blinkDuration = Duration(milliseconds: 800);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _blinkDuration,
  )..repeat(reverse: true);

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
