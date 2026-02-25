import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';
import 'detail.dart';
import 'submit.dart';
import 'common.dart';
import 'filter.dart';

class CourseListPage extends StatefulWidget {
  final TermInfo termInfo;
  final VoidCallback? onRetry;

  const CourseListPage({super.key, required this.termInfo, this.onRetry});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage>
    with SingleTickerProviderStateMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final TextEditingController _searchController = TextEditingController();

  List<CourseTab> _courseTabs = [];
  CourseTab? _selectedTab;

  List<CourseInfo> _courses = [];
  List<CourseInfo> _filteredCourses = [];

  List<String> _selectedCourseIds = [];
  String? _expandedCourseId; // Current expanded course ID

  bool _isLoading = false;
  bool _isLoadingCourses = false;
  String? _errorMessage;

  late final AnimationController _tabLoadBarController;
  late final Animation<double> _tabLoadBarAnimation;

  String _currentSearchQuery = '';
  Filterers _filterers = Filterers();
  List<String> _availableCourseTypes = [];
  List<String> _availableCourseCategories = [];
  double _minAvailableCredits = 0;
  double _maxAvailableCredits = 10;
  double _minAvailableHours = 0;
  double _maxAvailableHours = 100;

  @override
  void initState() {
    super.initState();
    _tabLoadBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 3000),
    );
    _tabLoadBarAnimation = CurvedAnimation(
      parent: _tabLoadBarController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _loadCourseTabs();
  }

  @override
  void dispose() {
    _tabLoadBarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseTabs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tabs = await _serviceProvider.coursesService.getCourseTabs(
        widget.termInfo,
      );
      if (!mounted) return;

      setState(() {
        _courseTabs = tabs;
        if (tabs.isNotEmpty) {
          _selectedTab = tabs.first;
          _loadCourses(); // Load first tab
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCourses() async {
    if (_selectedTab == null || !mounted) return;

    final currentTabId = _selectedTab!.tabId;

    setState(() {
      _isLoadingCourses = true;
      _errorMessage = null;
      _expandedCourseId = null;
    });
    _startTabLoadBar();

    try {
      // Get all courses in the tab (both selectable and already selected)
      final courses = await _serviceProvider.coursesService.getCoursesByTab(
        widget.termInfo,
        _selectedTab!.tabId,
      );

      // Ignore loaded actions if the tab has changed
      if (!mounted || _selectedTab?.tabId != currentTabId) return;

      // Remove duplicates
      final courseMap = <String, CourseInfo>{};
      for (final course in courses) {
        courseMap[course.courseId] = course;
      }
      final uniqueCourses = courseMap.values.toList();

      // Calculate available course types
      final courseTypes =
          uniqueCourses
              .map((course) => course.courseType)
              .where((type) => type.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      // Calculate available course categories
      final courseCategories =
          uniqueCourses
              .map((course) => course.courseCategory)
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      // Calculate available credits range
      final creditsList = uniqueCourses
          .map((course) => course.credits)
          .toList();
      final minCredits = creditsList.isNotEmpty
          ? creditsList.reduce((a, b) => a < b ? a : b)
          : 0.0;
      final maxCredits = creditsList.isNotEmpty
          ? creditsList.reduce((a, b) => a > b ? a : b)
          : 10.0;

      // Calculate available hours range
      final hoursList = uniqueCourses.map((course) => course.hours).toList();
      final minHours = hoursList.isNotEmpty
          ? hoursList.reduce((a, b) => a < b ? a : b)
          : 0.0;
      final maxHours = hoursList.isNotEmpty
          ? hoursList.reduce((a, b) => a > b ? a : b)
          : 100.0;

      // Separate courses into selected and unselected for display order
      final selectedInTab = uniqueCourses
          .where((course) => course.isSelected)
          .toList();
      final unselectedInTab = uniqueCourses
          .where((course) => !course.isSelected)
          .toList();

      // Combine with selected courses first
      final combinedCourses = [...selectedInTab, ...unselectedInTab];

      setState(() {
        _courses = combinedCourses;
        _filteredCourses = combinedCourses;
        _selectedCourseIds = selectedInTab.map((c) => c.courseId).toList();
        _availableCourseTypes = courseTypes;
        _availableCourseCategories = courseCategories;
        _minAvailableCredits = minCredits;
        _maxAvailableCredits = maxCredits;
        _minAvailableHours = minHours;
        _maxAvailableHours = maxHours;
        _isLoadingCourses = false;
        _filterers.clear();

        // Reset filters to extreme values
        _filterers = Filterers(
          minCredits: minCredits,
          maxCredits: maxCredits,
          minHours: minHours,
          maxHours: maxHours,
        );

        // Reapply searching
        if (_currentSearchQuery.isNotEmpty) {
          _filteredCourses = _searchCourses(_courses, _currentSearchQuery);
        }
      });
      _finishTabLoadBar();
    } catch (e) {
      if (!mounted || _selectedTab?.tabId != currentTabId) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoadingCourses = false;
      });
      _finishTabLoadBar();
    }
  }

  bool get _isTabSwitchDisabled {
    return _isLoadingCourses || _tabLoadBarAnimation.value > 0;
  }

  void _startTabLoadBar() {
    _tabLoadBarController.stop();
    _tabLoadBarController.value = 0;
    _tabLoadBarController.forward();
  }

  void _finishTabLoadBar() {
    if (_tabLoadBarController.status == AnimationStatus.reverse) return;
    _tabLoadBarController.reverse(from: _tabLoadBarController.value);
  }

  Future<void> _syncSelectedCoursesAfterSubmit() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allSelectedCourses = await _serviceProvider.coursesService
          .getAllSelectedCourses(widget.termInfo);

      _selectedCourseIds = allSelectedCourses
          .map((course) => course.courseId)
          .toList();

      final selectionState = _serviceProvider.coursesService
          .getCourseSelectionState();

      final remainingWantedCourses = selectionState.wantedCourses.where((
        course,
      ) {
        return !_selectedCourseIds.contains(course.courseId);
      }).toList();

      final updatedState = CourseSelectionState(
        termInfo: selectionState.termInfo,
        wantedCourses: remainingWantedCourses,
      );
      _serviceProvider.coursesService.updateCourseSelectionState(updatedState);

      if (mounted) {
        setState(() {
          _isLoading = false;
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

  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;
      _applyFilters();
    });
  }

  bool _isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  void _showFilterDialog() {
    if (_isWideScreen(context)) {
      // 宽屏模式下，筛选条件在侧边栏中实时更新，不需要弹窗
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FilterDialog(
          initialFilter: _filterers,
          availableCourseTypes: _availableCourseTypes,
          availableCourseCategories: _availableCourseCategories,
          minAvailableCredits: _minAvailableCredits,
          maxAvailableCredits: _maxAvailableCredits,
          minAvailableHours: _minAvailableHours,
          maxAvailableHours: _maxAvailableHours,
          onApply: (Filterers filter) {
            setState(() {
              _filterers = filter;
              _applyFilters();
            });
          },
          onReset: () {
            setState(() {
              _filterers.clear();
              _applyFilters();
            });
          },
        );
      },
    );
  }

  void _applyFilters() {
    List<CourseInfo> filtered = _courses;

    if (_currentSearchQuery.isNotEmpty) {
      filtered = _searchCourses(filtered, _currentSearchQuery);
    }

    if (_filterers.courseType != null && _filterers.courseType!.isNotEmpty) {
      filtered = filtered
          .where((course) => course.courseType == _filterers.courseType)
          .toList();
    }

    if (_filterers.courseCategory != null &&
        _filterers.courseCategory!.isNotEmpty) {
      filtered = filtered
          .where((course) => course.courseCategory == _filterers.courseCategory)
          .toList();
    }

    if (_filterers.minCredits != null && _filterers.maxCredits != null) {
      filtered = filtered
          .where(
            (course) =>
                course.credits >= _filterers.minCredits! &&
                course.credits <= _filterers.maxCredits!,
          )
          .toList();
    }

    if (_filterers.minHours != null && _filterers.maxHours != null) {
      filtered = filtered
          .where(
            (course) =>
                course.hours >= _filterers.minHours! &&
                course.hours <= _filterers.maxHours!,
          )
          .toList();
    }

    setState(() {
      _filteredCourses = filtered;
    });
  }

  List<CourseInfo> _searchCourses(List<CourseInfo> courses, String query) {
    final queryLower = query.toLowerCase();

    final List<CourseInfo> priorityResults = [];
    final Set<String> addedIds = <String>{};

    // 1. 课程代码精确匹配
    for (final course in courses) {
      final courseIdMatch = course.courseId.toLowerCase().contains(queryLower);

      if (courseIdMatch) {
        if (!addedIds.contains(course.courseId)) {
          priorityResults.add(course);
          addedIds.add(course.courseId);
        }
      }
    }

    // 2. 课程名称模糊匹配
    for (final course in courses) {
      final courseNameMatch = course.courseName.toLowerCase().contains(
        queryLower,
      );

      if (courseNameMatch) {
        if (!addedIds.contains(course.courseId)) {
          priorityResults.add(course);
          addedIds.add(course.courseId);
        }
      }
    }

    // 3. 课程alt名称模糊匹配
    for (final course in courses) {
      final courseNameAltMatch =
          course.courseNameAlt?.toLowerCase().contains(queryLower) ?? false;

      if (courseNameAltMatch) {
        if (!addedIds.contains(course.courseId)) {
          priorityResults.add(course);
          addedIds.add(course.courseId);
        }
      }
    }

    return priorityResults;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentSearchQuery = '';
      _filterers.clear();
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    final selectionState = _serviceProvider.coursesService
        .getCourseSelectionState();

    final isWideScreen = _isWideScreen(context);

    return Scaffold(
      appBar: PageAppBar(
        title: '选择课程',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [buildTermInfoDisplay(context, widget.termInfo)],
      ),
      body: isWideScreen
          ? Row(
              children: [
                FilterSidebar(
                  filter: _filterers,
                  availableCourseTypes: _availableCourseTypes,
                  availableCourseCategories: _availableCourseCategories,
                  minAvailableCredits: _minAvailableCredits,
                  maxAvailableCredits: _maxAvailableCredits,
                  minAvailableHours: _minAvailableHours,
                  maxAvailableHours: _maxAvailableHours,
                  onFilterChanged: (Filterers filter) {
                    setState(() {
                      _filterers = filter;
                      _applyFilters();
                    });
                  },
                  onReset: () {
                    setState(() {
                      _filterers.clear();
                      _applyFilters();
                    });
                  },
                ),
                Expanded(child: content),
              ],
            )
          : content,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: selectionState.wantedCourses.isNotEmpty
            ? _buildFloatingActionButtons(selectionState)
            : const SizedBox.shrink(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_courseTabs.isEmpty) {
      return const Center(child: Text('暂无可选课程标签页'));
    }

    return _buildCourseContent();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _loadCourseTabs();
                    widget.onRetry?.call();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseContent() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildTabBar(),
        ),

        const Divider(height: 1),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索课程代码、名称...',
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
              if (!_isWideScreen(context)) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text('高级筛选'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: _selectedTab != null
              ? _buildTabContent(_selectedTab!)
              : const Center(child: Text('请选择标签页')),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _tabLoadBarController,
      builder: (context, child) {
        final isTabSwitchDisabled = _isTabSwitchDisabled;

        return SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _tabLoadBarAnimation.value,
                    child: Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _courseTabs.map((tab) {
                      final isSelected = _selectedTab?.tabId == tab.tabId;

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            tab.tabName,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.4)
                                : Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          onSelected: isTabSwitchDisabled
                              ? null
                              : (selected) {
                                  if (selected &&
                                      mounted &&
                                      _selectedTab?.tabId != tab.tabId) {
                                    setState(() {
                                      _selectedTab = tab;
                                      _courses = [];
                                      _filteredCourses = [];
                                      _selectedCourseIds = [];
                                      _availableCourseTypes = [];
                                      _availableCourseCategories = [];
                                      _filterers.clear();
                                      _currentSearchQuery = '';
                                      _searchController.clear();
                                      _expandedCourseId = null;
                                      _errorMessage = null;
                                    });
                                    _loadCourses();
                                  }
                                },
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          checkmarkColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent(CourseTab tab) {
    if (_isLoadingCourses) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载课程数据...'),
          ],
        ),
      );
    }

    if (_filteredCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.question_mark_rounded,
              size: 80,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _courses.isNotEmpty ? '未找到符合条件的课程' : '暂无课程数据',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return _buildResponsiveCourseTable();
  }

  Widget _buildResponsiveCourseTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final columnConfig = [
          {'name': '', 'minWidth': 80.0, 'flex': 0, 'isNumeric': false},
          {'name': '课程代码', 'minWidth': 80.0, 'flex': 2, 'isNumeric': false},
          {'name': '课程名称', 'minWidth': 120.0, 'flex': 4, 'isNumeric': false},
          {'name': '性质', 'minWidth': 60.0, 'flex': 1, 'isNumeric': false},
          {'name': '类别', 'minWidth': 60.0, 'flex': 1, 'isNumeric': false},
          {'name': '学分', 'minWidth': 60.0, 'flex': 1, 'isNumeric': true},
          {'name': '学时', 'minWidth': 60.0, 'flex': 1, 'isNumeric': true},
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

        List<double> columnWidths;
        double tableWidth;

        if (needsHorizontalScroll) {
          columnWidths = columnConfig
              .map((col) => col['minWidth'] as double)
              .toList();
          tableWidth = totalMinWidth;
        } else {
          final extraWidth = availableWidth - totalMinWidth;
          columnWidths = columnConfig.map((col) {
            final minWidth = col['minWidth'] as double;
            final flex = col['flex'] as int;
            final extraForThisColumn = extraWidth * (flex / totalFlex);
            return minWidth + extraForThisColumn;
          }).toList();
          tableWidth = availableWidth;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                Container(
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: _CourseTableHeader(
                    columnConfig: columnConfig,
                    columnWidths: columnWidths,
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      final isExpanded = _expandedCourseId == course.courseId;

                      return _CourseTableRow(
                        course: course,
                        termInfo: widget.termInfo,
                        isExpanded: isExpanded,
                        columnWidths: columnWidths,
                        onToggle: () {
                          setState(() {
                            _expandedCourseId = isExpanded
                                ? null
                                : course.courseId;
                          });
                        },
                        onSelectionChanged: () {
                          // Ensure refreshed
                          setState(() {});
                        },
                        onRefreshRequired: _loadCourses,
                        selectedCourseIds: _selectedCourseIds,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButtons(CourseSelectionState selectionState) {
    return Row(
      children: [
        // Clear button
        Container(
          height: 28,
          width: 28,
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                // Pop dialog to confirm to clear
                if (await alertClearSelectedWarning(context) == true) {
                  setState(() {
                    for (final course
                        in selectionState.wantedCourses.toList()) {
                      _serviceProvider.coursesService.removeCourseFromSelection(
                        course.courseId,
                        course.classDetail?.classId,
                      );
                    }
                  });
                }
              },
              child: Icon(
                Icons.clear,
                color: Theme.of(context).colorScheme.error,
                size: 16,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Submit button
        Expanded(
          child: Container(
            height: 52,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CourseSubmitPage(termInfo: widget.termInfo),
                    ),
                  );

                  if (mounted) {
                    await _syncSelectedCoursesAfterSubmit();
                    await _loadCourses();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${selectionState.wantedCourses.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '准备提交',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseTableHeader extends StatelessWidget {
  final List<Map<String, Object>> columnConfig;
  final List<double> columnWidths;

  const _CourseTableHeader({
    required this.columnConfig,
    required this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: columnConfig.asMap().entries.map((entry) {
          final index = entry.key;
          final column = entry.value;
          final columnName = column['name'] as String;
          final width = columnWidths[index];
          final isNumeric = column['isNumeric'] as bool;

          return _buildHeaderCell(columnName, width, isNumeric: isNumeric);
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, {bool isNumeric = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: isNumeric ? TextAlign.center : TextAlign.left,
      ),
    );
  }
}

class _CourseTableRow extends StatefulWidget {
  final CourseInfo course;
  final TermInfo termInfo;
  final bool isExpanded;
  final List<double> columnWidths;
  final VoidCallback onToggle;
  final VoidCallback onSelectionChanged;
  final VoidCallback onRefreshRequired;
  final List<String> selectedCourseIds;

  const _CourseTableRow({
    required this.course,
    required this.termInfo,
    required this.isExpanded,
    required this.columnWidths,
    required this.onToggle,
    required this.onSelectionChanged,
    required this.onRefreshRequired,
    required this.selectedCourseIds,
  });

  @override
  State<_CourseTableRow> createState() => _CourseTableRowState();
}

class _CourseTableRowState extends State<_CourseTableRow>
    with TickerProviderStateMixin {
  late AnimationController _iconRotationController;
  late Animation<double> _iconRotationAnimation;

  int _getSelectedCountForCourse() {
    final serviceProvider = ServiceProvider.instance;
    final selectionState = serviceProvider.coursesService
        .getCourseSelectionState();
    return selectionState.wantedCourses
        .where((course) => course.courseId == widget.course.courseId)
        .length;
  }

  Widget _buildSelectionStatusIndicator() {
    final selectedCount = _getSelectedCountForCourse();
    final isAlreadySelected = widget.selectedCourseIds.contains(
      widget.course.courseId,
    );

    if (selectedCount == 0 && !isAlreadySelected) {
      return const SizedBox.shrink();
    }

    // For already selected courses
    if (isAlreadySelected && selectedCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '已选',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // For courses in current selection
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+ $selectedCount',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _iconRotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconRotationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_CourseTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _iconRotationController.forward();
      } else {
        _iconRotationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _iconRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: widget.onToggle,
          splashColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: widget.isExpanded
              ? const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                )
              : BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isExpanded
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
              borderRadius: widget.isExpanded
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    )
                  : null,
              border: widget.isExpanded
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
            ),
            child: Row(
              children: [
                _buildDataCell(
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _iconRotationAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _iconRotationAnimation.value * 3.1415927,
                            child: Icon(
                              Icons.expand_more,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildSelectionStatusIndicator(),
                    ],
                  ),
                  widget.columnWidths[0],
                  needCenter: true,
                ),
                _buildDataCell(
                  Text(
                    widget.course.courseId,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  widget.columnWidths[1],
                ),
                _buildNameCell(
                  widget.course.courseName,
                  widget.course.courseNameAlt,
                  widget.columnWidths[2],
                ),
                _buildDataCell(
                  Text(
                    widget.course.courseType,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  widget.columnWidths[3],
                ),
                _buildDataCell(
                  Text(
                    widget.course.courseCategory,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  widget.columnWidths[4],
                ),
                _buildDataCell(
                  Text(
                    widget.course.credits.toString(),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  widget.columnWidths[5],
                  needCenter: true,
                ),
                _buildDataCell(
                  Text(
                    widget.course.hours.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  widget.columnWidths[6],
                  needCenter: true,
                ),
              ],
            ),
          ),
        ),

        CourseDetailCard(
          course: widget.course,
          termInfo: widget.termInfo,
          isExpanded: widget.isExpanded,
          onToggle: widget.onToggle,
          onSelectionChanged: widget.onSelectionChanged,
          onRefreshRequired: widget.onRefreshRequired,
          selectedCourseIds: widget.selectedCourseIds,
        ),
      ],
    );
  }

  Widget _buildDataCell(Widget child, double width, {bool needCenter = false}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: needCenter ? Alignment.center : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildNameCell(String name, String? nameAlt, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          if (nameAlt?.isNotEmpty == true)
            Text(
              nameAlt!,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
