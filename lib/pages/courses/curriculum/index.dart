import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/types/preferences.dart';
import '/utils/app_bar.dart';
import '/utils/sync_embeded.dart';
import 'common.dart';
import 'table.dart';

class CurriculumPage extends StatefulWidget {
  const CurriculumPage({super.key});

  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage>
    with TickerProviderStateMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  CurriculumIntegratedData? _curriculumData;
  String? _errorMessage;
  int _currentWeek = 1;
  int _previousWeek = 0;
  bool _isLoading = false;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.linear),
    );

    _loadCurriculumFromCacheOrService();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _serviceProvider.removeListener(_onServiceStatusChanged);
    super.dispose();
  }

  CurriculumSettings getSettings() {
    final cached = _serviceProvider.storeService.getPref<CurriculumSettings>(
      "curriculum",
      CurriculumSettings.fromJson,
    );
    return cached ?? CurriculumSettings.defaultSettings;
  }

  void saveSettings(CurriculumSettings settings) {
    _serviceProvider.storeService.putPref<CurriculumSettings>(
      "curriculum",
      settings,
    );
  }

  bool get isActivated => getSettings().activated;

  void setActivated(bool activated) {
    saveSettings(getSettings()..activated = activated);
  }

  void _onServiceStatusChanged() {
    if (mounted && _serviceProvider.coursesService.isOnline) {
      _loadCurriculumFromCacheOrService();
    }
  }

  Future<void> _loadCurriculumFromCacheOrService() async {
    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _curriculumData = cachedData;
          _errorMessage = null;
          _gotoCurrentDateWeek();
        });
        _fadeAnimationController.forward();
      }
      return;
    }

    final service = _serviceProvider.coursesService;
    if (!service.isOnline) {
      if (mounted) {
        setState(() {
          _curriculumData = null;
          _errorMessage = null;
        });
      }
      return;
    }
  }

  Future<void> _loadCurriculumForTerm(TermInfo termInfo) async {
    final service = _serviceProvider.coursesService;

    if (!service.isOnline) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final futures = await Future.wait([
        service.getCurriculum(termInfo),
        service.getCoursePeriods(termInfo),
        service.getCalendarDays(termInfo).catchError((e) => <CalendarDay>[]),
      ]);

      final classes = futures[0] as List<ClassItem>;
      final periods = futures[1] as List<ClassPeriod>;
      final calendarDays = futures[2] as List<CalendarDay>;

      final integratedData = CurriculumIntegratedData(
        currentTerm: termInfo,
        allClasses: classes,
        allPeriods: periods,
        calendarDays: calendarDays.isEmpty ? null : calendarDays,
      );

      _serviceProvider.storeService.putConfig<CurriculumIntegratedData>(
        "curriculum_data",
        integratedData,
      );

      setActivated(true);

      if (mounted) {
        setState(() {
          _curriculumData = integratedData;
          _isLoading = false;
          _gotoCurrentDateWeek();
        });
        _fadeAnimationController.forward();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '课程表',
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.settings),
              tooltip: '课程表设置',
            ),
          ),
        ],
      ),
      body: SyncPowered(childBuilder: (context) => _buildBody()),
      endDrawer: _buildSettingsDrawer(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '加载失败: $_errorMessage',
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshCurriculumData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    if (cachedData != null) {
      final data = cachedData;
      // Check activated status from settings
      if (isActivated) {
        if (mounted && _curriculumData != data) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _curriculumData = data;
              _gotoCurrentDateWeek();
            });
          });
        }
        return _buildCurriculumView();
      } else {
        // not activated
        return _buildSelectionView(cachedData);
      }
    } else {
      if (!_serviceProvider.coursesService.isOnline) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Container(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.login, size: 64, color: Colors.grey),
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

      return _buildSelectionView(null);
    }
  }

  Widget _buildSelectionView(CurriculumIntegratedData? cachedData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool shouldUseDoubleColumn = constraints.maxWidth > 1000;

          if (shouldUseDoubleColumn && cachedData != null) {
            // Two column layout
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChooseLatestCard(
                        isLoggedIn: _serviceProvider.coursesService.isOnline,
                        getTerms: () =>
                            _serviceProvider.coursesService.getTerms(),
                        onTermSelected: _loadCurriculumForTerm,
                        useFlexLayout: true,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChooseCacheCard(
                        cachedData: cachedData,
                        onSubmit: _activateAndViewCachedData,
                        useFlexLayout: true,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Single column layout
            return Column(
              children: [
                ChooseLatestCard(
                  isLoggedIn: _serviceProvider.coursesService.isOnline,
                  getTerms: () => _serviceProvider.coursesService.getTerms(),
                  onTermSelected: _loadCurriculumForTerm,
                  isLoading: _isLoading,
                ),
                if (cachedData != null)
                  ChooseCacheCard(
                    cachedData: cachedData,
                    onSubmit: _activateAndViewCachedData,
                    isLoading: _isLoading,
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  void _activateAndViewCachedData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    if (cachedData != null) {
      final data = cachedData;

      setActivated(true);

      if (mounted) {
        setState(() {
          _curriculumData = data;
          _isLoading = false;
          _gotoCurrentDateWeek();
        });
        _fadeAnimationController.forward();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCurriculumView() {
    if (_curriculumData == null || _curriculumData!.allClasses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '暂无课程数据',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_curriculumData != null)
              Text(
                '当前查看：${_curriculumData!.currentTerm.year}学年 第${_curriculumData!.currentTerm.season}学期',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearCacheAndSelectTerm,
              child: const Text('重新选择学期'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          _buildWeekSelector(),
          const SizedBox(height: 16),
          Expanded(
            // To avoid animation overflow
            child: ClipRect(
              child: GestureDetector(
                onPanEnd: (details) {
                  if (details.velocity.pixelsPerSecond.dx.abs() > 400) {
                    if (details.velocity.pixelsPerSecond.dx > 0) {
                      // Slide from left
                      _gotoWeekSafe(_currentWeek - 1);
                    } else {
                      // Slide from right
                      _gotoWeekSafe(_currentWeek + 1);
                    }
                  }
                },
                child: _buildCurriculumTableWithAnimation(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCurriculumData() async {
    _serviceProvider.storeService.delConfig("curriculum_data");
    final cachedTerm = _curriculumData?.currentTerm ?? TermInfo.autoDetect();
    setState(() {
      _curriculumData = null;
    });
    await _loadCurriculumForTerm(cachedTerm);
  }

  Future<void> _clearCacheAndSelectTerm() async {
    _serviceProvider.storeService.delConfig("curriculum_data");
    if (mounted) {
      setState(() {
        _curriculumData = null;
        _errorMessage = null;
      });
    }
  }

  Widget _buildWeekSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _gotoWeekSafe(_currentWeek - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _showWeekJumper,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第 $_currentWeek 周',
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
          message: _currentWeek >= _curriculumData!.getMaxValidWeekIndex()
              ? '已经到最大周次了~'
              : '',
          child: IconButton(
            onPressed: () => _gotoWeekSafe(_currentWeek + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }

  void _showWeekJumper() {
    final maxValidWeek = _curriculumData!.getMaxValidWeekIndex();
    final todayWeek = _curriculumData!.getWeekIndexToday();

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
                children: List.generate(maxValidWeek, (index) {
                  final week = index + 1;
                  final isCurrentWeek = week == _currentWeek;
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

  void _gotoWeekSafe(int newWeek) {
    newWeek = newWeek.clamp(1, _curriculumData!.getMaxValidWeekIndex());

    if (newWeek == _currentWeek) return;

    setState(() {
      _previousWeek = _currentWeek;
      _currentWeek = newWeek;
    });
  }

  void _gotoCurrentDateWeek() {
    final maxValidWeek = _curriculumData!.getMaxValidWeekIndex();
    if (_currentWeek > maxValidWeek) {
      _currentWeek = maxValidWeek;
    }

    final todayWeek = _curriculumData!.getWeekIndexToday();
    if (todayWeek != null && todayWeek >= 1 && todayWeek <= maxValidWeek) {
      _currentWeek = todayWeek;
    }
  }

  Widget _buildCurriculumTableWithAnimation() {
    final settings = getSettings();
    final animationMode = settings.animationMode;

    final slideDirection = (_currentWeek - _previousWeek).clamp(-1, 1);

    Widget tableContent;

    switch (animationMode) {
      case AnimationMode.fade:
        tableContent = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildCurriculumTable(key: ValueKey(_currentWeek)),
        );
        break;

      case AnimationMode.slide:
        tableContent = AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset(slideDirection * 0.4, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
          child: _buildCurriculumTable(key: ValueKey(_currentWeek)),
        );
        break;

      case AnimationMode.none:
        tableContent = _buildCurriculumTable();
        break;
    }

    return AnimatedBuilder(
      animation: _fadeAnimationController,
      builder: (context, child) {
        return FadeTransition(opacity: _fadeAnimation, child: tableContent);
      },
    );
  }

  Widget _buildCurriculumTable({Key? key}) {
    if (_curriculumData == null || _curriculumData!.allPeriods.isEmpty) {
      return Center(
        key: key,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '课时数据未加载',
              style: TextStyle(fontSize: 18, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              '无法显示课表时间信息',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshCurriculumData,
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        try {
          final settings = getSettings();
          final weekDates = _curriculumData!.getWeekdayDaysOf(_currentWeek);

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: CurriculumTable(
              curriculumData: _curriculumData!,
              availableWidth: constraints.maxWidth,
              settings: settings,
              weekDates: weekDates,
              currentWeek: _currentWeek,
            ),
          );
        } catch (e) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  '课表构建失败: $e',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshCurriculumData,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: const Row(
              children: [
                Icon(Icons.settings, size: 24),
                SizedBox(width: 8),
                Text(
                  '课程表设置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_curriculumData != null) ...[
            _buildCurriculumInfo(),
            const Divider(),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                _buildWeekendDisplaySetting(),
                const SizedBox(height: 8),
                _buildTableSizeSetting(),
                const SizedBox(height: 8),
                _buildAnimationModeSetting(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumInfo() {
    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, size: 18),
              const SizedBox(width: 4),
              Text(
                '${_curriculumData!.currentTerm.year}学年 第${_curriculumData!.currentTerm.season}学期',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (cachedData != null)
            Text(
              '缓存时间：${formatCacheTime(cachedData)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _deactivateCurrentData,
              icon: const Icon(Icons.cached),
              label: const Text('切换学期或更新'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deactivateCurrentData() {
    if (_curriculumData != null) {
      // Set activated to false in settings
      setActivated(false);

      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }

      Navigator.of(context).pop();
    }
  }

  Widget _buildWeekendDisplaySetting() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '显示周末',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<WeekendDisplayMode>(
                initialValue: getSettings().weekendMode,
                items: WeekendDisplayMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.displayName),
                  );
                }).toList(),
                onChanged: (WeekendDisplayMode? newMode) {
                  if (newMode != null) {
                    final currentSettings = getSettings();
                    saveSettings(currentSettings..weekendMode = newMode);
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSizeSetting() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '表格尺寸',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<TableSize>(
                initialValue: getSettings().tableSize,
                items: TableSize.values.map((size) {
                  return DropdownMenuItem(
                    value: size,
                    child: Text(size.displayName),
                  );
                }).toList(),
                onChanged: (TableSize? newSize) {
                  if (newSize != null) {
                    final currentSettings = getSettings();
                    saveSettings(currentSettings..tableSize = newSize);
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationModeSetting() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '动画效果',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<AnimationMode>(
                initialValue: getSettings().animationMode,
                items: AnimationMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode.displayName),
                  );
                }).toList(),
                onChanged: (AnimationMode? newMode) {
                  if (newMode != null) {
                    final currentSettings = getSettings();
                    saveSettings(currentSettings..animationMode = newMode);
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
