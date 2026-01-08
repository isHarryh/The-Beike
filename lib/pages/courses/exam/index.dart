import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ExamInfo>? _allExams;
  List<ExamInfo>? _filteredExams;

  bool _isLoading = false;
  String? _errorMessage;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);
    _loadExams();
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (mounted && _serviceProvider.coursesService.isOnline) {
      setState(() {
        _loadExams();
      });
    }
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    final service = _serviceProvider.coursesService;

    if (!forceRefresh && mounted && _allExams != null) {
      setState(() {
        _allExams = null;
        _filteredExams = null;
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    if (mounted && service.isOnline) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final currentTerm = TermInfo.autoDetect();
        final exams = await service.getExams(currentTerm);
        if (mounted) {
          setState(() {
            _allExams = exams;
            _filteredExams = exams;
            _isLoading = false;
            if (_currentSearchQuery.isNotEmpty) {
              _performSearch(_currentSearchQuery);
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _refreshExams() async {
    await _loadExams(forceRefresh: true);
  }

  void _performSearch(String query) {
    if (_allExams == null) return;

    setState(() {
      _currentSearchQuery = query;
      if (query.isEmpty) {
        _filteredExams = _allExams;
      } else {
        _filteredExams = _searchExams(_allExams!, query);
      }
    });
  }

  List<ExamInfo> _searchExams(List<ExamInfo> exams, String query) {
    final queryLower = query.toLowerCase();
    final List<ExamInfo> priorityResults = [];
    final Set<String> addedIds = <String>{};

    // 1. 课程名称及alt名称模糊匹配
    for (final exam in exams) {
      final classNameMatch = exam.courseName.toLowerCase().contains(queryLower);
      final classNameAltMatch =
          exam.courseNameAlt?.toLowerCase().contains(queryLower) ?? false;

      if (classNameMatch || classNameAltMatch) {
        final id =
            '${exam.courseId}_${exam.examDate.toString()}_${exam.minorId}';
        if (!addedIds.contains(id)) {
          priorityResults.add(exam);
          addedIds.add(id);
        }
      }
    }

    // 2. 课程代码模糊匹配
    for (final exam in exams) {
      final courseIdMatch = exam.courseId.toLowerCase().contains(queryLower);

      if (courseIdMatch) {
        final id =
            '${exam.courseId}_${exam.examDate.toString()}_${exam.minorId}';
        if (!addedIds.contains(id)) {
          priorityResults.add(exam);
          addedIds.add(id);
        }
      }
    }

    // 3. 考场及alt名称模糊匹配
    for (final exam in exams) {
      final examRoomMatch = exam.examRoom.toLowerCase().contains(queryLower);
      final examRoomAltMatch =
          exam.examRoomAlt?.toLowerCase().contains(queryLower) ?? false;
      final examBuildingMatch =
          exam.examBuilding?.toLowerCase().contains(queryLower) ?? false;
      final examBuildingAltMatch =
          exam.examBuildingAlt?.toLowerCase().contains(queryLower) ?? false;

      if (examRoomMatch ||
          examRoomAltMatch ||
          examBuildingMatch ||
          examBuildingAltMatch) {
        final id =
            '${exam.courseId}_${exam.examDate.toString()}_${exam.minorId}';
        if (!addedIds.contains(id)) {
          priorityResults.add(exam);
          addedIds.add(id);
        }
      }
    }

    return priorityResults;
  }

  void _clearSearch() {
    _searchController.clear();
    _performSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '考试查询'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final service = _serviceProvider.coursesService;

    if (!service.isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.only(right: 8.0),
                child: const Icon(Icons.login, size: 64, color: Colors.grey),
              ),
              onPressed: () => context.router.pushPath('/courses/account'),
            ),
            const SizedBox(height: 16),
            const Text(
              '请先登录',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载考试信息...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              '加载失败',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshExams, child: const Text('重试')),
          ],
        ),
      );
    }

    // No data
    if (_allExams == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无考试数据', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(padding: const EdgeInsets.all(12), child: _buildActionBar()),
        Expanded(child: _buildTableOrEmptyState()),
      ],
    );
  }

  Widget _buildTableOrEmptyState() {
    if (_filteredExams == null || _filteredExams!.isEmpty) {
      if (_currentSearchQuery.isNotEmpty) {
        // Searching but no data
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                '没有找到匹配"$_currentSearchQuery"的考试',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearSearch,
                child: const Text('清除搜索'),
              ),
            ],
          ),
        );
      } else {
        // No searching and no data
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '暂无考试数据',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        );
      }
    }

    return _buildResponsiveTable();
  }

  Widget _buildActionBar() {
    final service = _serviceProvider.coursesService;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索课程名称或考场位置...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _currentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: _performSearch,
              onSubmitted: _performSearch,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: (service.isOnline && !_isLoading) ? _refreshExams : null,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(_isLoading ? '刷新中...' : '刷新'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final columnConfig = [
          {'name': '课程代码', 'minWidth': 100.0, 'flex': 2, 'isNumeric': false},
          {'name': '课程名称', 'minWidth': 120.0, 'flex': 3, 'isNumeric': false},
          {'name': '考试类型', 'minWidth': 100.0, 'flex': 2, 'isNumeric': false},
          {'name': '日期', 'minWidth': 100.0, 'flex': 3, 'isNumeric': false},
          {'name': '时间', 'minWidth': 100.0, 'flex': 3, 'isNumeric': false},
          {'name': '考场位置', 'minWidth': 120.0, 'flex': 3, 'isNumeric': false},
        ];

        final totalMinWidth = columnConfig.fold<double>(
          0,
          (sum, col) => sum + (col['minWidth'] as double),
        );
        final totalFlex = columnConfig.fold<int>(
          0,
          (sum, col) => sum + (col['flex'] as int),
        );

        final needsHorizontalScroll = availableWidth < totalMinWidth;

        Widget table;
        if (needsHorizontalScroll) {
          final columnWidths = columnConfig
              .map((col) => col['minWidth'] as double)
              .toList();
          table = _buildFixedWidthTable(
            columnConfig,
            columnWidths,
            totalMinWidth,
          );
        } else {
          final extraWidth = availableWidth - totalMinWidth;
          final columnWidths = columnConfig.map((col) {
            final minWidth = col['minWidth'] as double;
            final flex = col['flex'] as int;
            final extraForThisColumn = extraWidth * (flex / totalFlex);
            return minWidth + extraForThisColumn;
          }).toList();
          table = _buildFixedWidthTable(
            columnConfig,
            columnWidths,
            availableWidth,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            child: table,
          ),
        );
      },
    );
  }

  Widget _buildFixedWidthTable(
    List<Map<String, Object>> columnConfig,
    List<double> columnWidths,
    double tableWidth,
  ) {
    return SizedBox(
      width: tableWidth,
      child: Column(
        children: [
          // Table header
          Container(
            height: 60.0,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                ),
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              children: columnConfig.asMap().entries.map((entry) {
                final index = entry.key;
                final column = entry.value;

                return _buildHeaderCell(
                  column['name'] as String,
                  columnWidths[index],
                  isNumeric: column['isNumeric'] as bool,
                );
              }).toList(),
            ),
          ),

          // Data rows
          ..._filteredExams!.asMap().entries.map((entry) {
            final exam = entry.value;

            return Container(
              height: 90.0,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(children: _buildDataRow(exam, columnWidths)),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildDataRow(ExamInfo exam, List<double> columnWidths) {
    return [
      _buildDataCell(_buildCourseIdCell(exam), columnWidths[0]),
      _buildDataCell(_buildClassNameCell(exam), columnWidths[1]),
      _buildDataCell(_buildExamRangeCell(exam), columnWidths[2]),
      _buildDataCell(_buildExamDateCell(exam), columnWidths[3]),
      _buildDataCell(_buildExamTimeCell(exam), columnWidths[4]),
      _buildDataCell(_buildExamRoomCell(exam), columnWidths[5]),
    ];
  }

  Widget _buildHeaderCell(String text, double width, {bool isNumeric = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: isNumeric ? TextAlign.center : TextAlign.left,
        maxLines: 2,
      ),
    );
  }

  Widget _buildDataCell(Widget child, double width, {bool isNumeric = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: isNumeric ? Alignment.center : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildCourseIdCell(ExamInfo exam) {
    return Text(
      exam.courseId,
      style: const TextStyle(fontSize: 14),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildClassNameCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.courseName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (exam.courseNameAlt != null &&
            exam.courseNameAlt!.isNotEmpty &&
            exam.courseNameAlt != exam.courseName)
          Text(
            exam.courseNameAlt!,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }

  Widget _buildExamRangeCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examRange,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        Text(
          "${exam.termYear}学年 第${exam.termSeason}学期",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildExamDateCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examDateDisplay,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        Text(
          "第${exam.examWeek}周 ${exam.examDayName}",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildExamTimeCell(ExamInfo exam) {
    final now = DateTime.now();
    final startTime = exam.getStartTime();
    String? remainingText;

    if (startTime != null) {
      final difference = startTime.difference(now);
      if (!difference.isNegative) {
        final days = difference.inDays;
        if (days < 21) {
          final hours = difference.inHours % 24;
          remainingText = '剩余 $days 天 $hours 小时';
        } else {
          remainingText = '剩余 $days 天';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examTime,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (remainingText != null)
          Text(
            remainingText,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
      ],
    );
  }

  Widget _buildExamRoomCell(ExamInfo exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          exam.examRoom,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        if (exam.examBuilding != null &&
            exam.examBuilding!.isNotEmpty &&
            exam.examBuilding != exam.examRoom)
          Text(
            exam.examBuilding!,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
      ],
    );
  }
}
