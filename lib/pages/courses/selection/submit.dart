import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';
import '/services/provider.dart';
import 'common.dart';

enum CourseSelectionStatus {
  idle, // 未开始
  sending, // 请求中
  success, // 已成功
  cancelled, // 已取消
  errorTimeout, // 请求超时
  errorApi, // 服务器返回错误
  errorNetwork, // 网络问题
}

class TaskStatusInfo {
  final Color color;
  final IconData icon;
  final String text;

  TaskStatusInfo({required this.color, required this.icon, required this.text});

  factory TaskStatusInfo.fromTask(
    CourseSelectionTask task, {
    bool complex = true,
  }) {
    return _createStatusInfo(task.status, complex: complex, task: task);
  }

  static TaskStatusInfo _createStatusInfo(
    CourseSelectionStatus status, {
    bool complex = false,
    CourseSelectionTask? task,
  }) {
    switch (status) {
      case CourseSelectionStatus.idle:
        return TaskStatusInfo(
          color: Colors.grey,
          icon: Icons.timer,
          text: '待提交',
        );
      case CourseSelectionStatus.sending:
        if (complex &&
            task != null &&
            task.previousStatus != null &&
            _isFailureStatus(task.previousStatus!)) {
          final previousInfo = _createStatusInfo(
            task.previousStatus!,
            complex: false,
          );
          return TaskStatusInfo(
            color: previousInfo.color,
            icon: previousInfo.icon,
            text: '${_getStatusDisplayName(task.previousStatus!)} - 重试中',
          );
        } else {
          return TaskStatusInfo(
            color: Colors.blue,
            icon: Icons.timer,
            text: '提交中',
          );
        }
      case CourseSelectionStatus.success:
        return TaskStatusInfo(
          color: Colors.green.shade600,
          icon: Icons.check_circle,
          text: '成功',
        );
      case CourseSelectionStatus.cancelled:
        if (complex &&
            task != null &&
            task.previousStatus != null &&
            _isFailureStatus(task.previousStatus!)) {
          return TaskStatusInfo(
            color: Colors.grey,
            icon: Icons.not_interested,
            text: '${_getStatusDisplayName(task.previousStatus!)} - 已取消',
          );
        } else {
          return TaskStatusInfo(
            color: Colors.grey,
            icon: Icons.not_interested,
            text: '已取消',
          );
        }
      case CourseSelectionStatus.errorTimeout:
        return TaskStatusInfo(
          color: Colors.orange,
          icon: Icons.timer_off,
          text: '超时',
        );
      case CourseSelectionStatus.errorApi:
        return TaskStatusInfo(color: Colors.red, icon: Icons.error, text: '失败');
      case CourseSelectionStatus.errorNetwork:
        return TaskStatusInfo(
          color: Colors.red,
          icon: Icons.error,
          text: '网络错误',
        );
    }
  }

  static bool _isFailureStatus(CourseSelectionStatus status) {
    return status == CourseSelectionStatus.errorTimeout ||
        status == CourseSelectionStatus.errorApi ||
        status == CourseSelectionStatus.errorNetwork;
  }

  static String _getStatusDisplayName(CourseSelectionStatus status) {
    switch (status) {
      case CourseSelectionStatus.errorTimeout:
        return '超时';
      case CourseSelectionStatus.errorApi:
        return '失败';
      case CourseSelectionStatus.errorNetwork:
        return '网络错误';
      default:
        return '未知';
    }
  }
}

class CourseSelectionTask {
  final CourseInfo course;
  CourseSelectionStatus status;
  String? errorMessage;
  DateTime? startTime;
  DateTime? endTime;
  int retryCount;
  CourseSelectionStatus? previousStatus;

  CourseSelectionTask({
    required this.course,
    this.status = CourseSelectionStatus.idle,
    this.errorMessage,
    this.startTime,
    this.endTime,
    this.retryCount = 0,
    this.previousStatus,
  });

  Duration? get duration {
    if (startTime == null) return null;
    final now = DateTime.now();
    final end = endTime ?? now;
    return end.isBefore(startTime!)
        ? Duration.zero
        : end.difference(startTime!);
  }
}

class CourseSubmitPage extends StatefulWidget {
  final TermInfo termInfo;

  const CourseSubmitPage({super.key, required this.termInfo});

  @override
  State<CourseSubmitPage> createState() => _CourseSubmitPageState();
}

class _CourseSubmitPageState extends State<CourseSubmitPage>
    with TickerProviderStateMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  List<CourseSelectionTask> _tasks = [];

  bool _autoRetry = false; // Configurable

  int _concurrencyCount = 1; // Configurable

  bool _isSubmitting = false;
  bool _stopRequested = false;

  // courseKey -> success?
  Map<String, bool> _courseSuccessMap = {};

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.2,
    ).animate(CurvedAnimation(parent: _blinkController, curve: Curves.linear));
    _blinkController.repeat(reverse: true);

    _initializeTasks();
  }

  @override
  void dispose() {
    _requestStopSubmission();
    _isSubmitting = false;
    _blinkController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _requestStopSubmission() {
    if (!_isSubmitting || _stopRequested) return;
    _safeSetState(() {
      _stopRequested = true;
      for (final task in _tasks) {
        if (task.status == CourseSelectionStatus.idle) {
          task.status = CourseSelectionStatus.cancelled;
          task.endTime = DateTime.now();
          task.errorMessage = '已停止';
        }
      }
    });
  }

  void _initializeTasks() {
    final selectionState = _serviceProvider.coursesService
        .getCourseSelectionState();
    _tasks = [];
    _courseSuccessMap = {};

    // Create multiple tasks per course
    for (final course in selectionState.wantedCourses) {
      final courseKey = course.uniqueKey;
      for (int i = 0; i < _concurrencyCount; i++) {
        _tasks.add(CourseSelectionTask(course: course));
      }
      _courseSuccessMap[courseKey] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _requestStopSubmission();
        }
      },
      child: Scaffold(
        appBar: PageAppBar(
          title: '提交选课',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),

          actions: [buildTermInfoDisplay(context, widget.termInfo)],
        ),
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildStepIndicator(context, 3),
                const SizedBox(height: 24),
                _buildAutoRetrySwitch(),
                const SizedBox(height: 16),
                _buildConcurrencySelector(),
                const SizedBox(height: 16),
                _buildTasksList(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSubmitButton(),
        ),
      ],
    );
  }

  Widget _buildAutoRetrySwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.refresh,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动重试',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  '选课失败时自动重试，适用于抢课和退课候补',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoRetry,
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _autoRetry = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildConcurrencySelector() {
    final maxConcurrency = kDebugMode ? 50 : 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '协程数量',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  '每个课程的并发请求数，适用于抢课',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: _concurrencyCount,
            items: List.generate(maxConcurrency, (index) => index + 1)
                .map(
                  (count) =>
                      DropdownMenuItem(value: count, child: Text('$count')),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _concurrencyCount = value;
                        _initializeTasks(); // Re-init
                      });
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    final Map<String, List<CourseSelectionTask>> groupedTasks = {};
    final Map<String, CourseInfo> courseMap = {};

    for (final task in _tasks) {
      final courseKey = task.course.uniqueKey;
      groupedTasks.putIfAbsent(courseKey, () => []).add(task);
      courseMap[courseKey] = task.course;
    }

    final uniqueCourseCount = groupedTasks.keys.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选课提交队列 ($uniqueCourseCount 课程)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        groupedTasks.isEmpty
            ? SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无选择的课程',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: groupedTasks.keys.map((courseKey) {
                  final courseTasks = groupedTasks[courseKey]!;
                  final course = courseMap[courseKey]!;
                  return _buildCourseGroup(course, courseTasks);
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildCourseGroup(
    CourseInfo course,
    List<CourseSelectionTask> courseTasks,
  ) {
    final hasSuccess = courseTasks.any(
      (task) => task.status == CourseSelectionStatus.success,
    );
    final isRunning = courseTasks.any(
      (task) => task.status == CourseSelectionStatus.sending,
    );
    final allIdle = courseTasks.every(
      (task) => task.status == CourseSelectionStatus.idle,
    );

    final courseStatusColor = hasSuccess
        ? Colors.green
        : isRunning
        ? Colors.blue
        : allIdle
        ? Colors.grey
        : Colors.red;

    final courseStatusText = hasSuccess
        ? '成功'
        : isRunning
        ? '进行中'
        : allIdle
        ? '待开始'
        : '失败';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.book, color: courseStatusColor, size: 24),
            title: Text(
              course.courseName +
                  (course.classDetail?.extraName != null
                      ? ' ${course.classDetail?.extraName}'
                      : ''),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '课程编号: ${course.courseId}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: courseStatusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                courseStatusText,
                style: TextStyle(
                  color: courseStatusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          if (!allIdle || _isSubmitting) ...[
            const Divider(height: 1),
            ...courseTasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              return _buildCoroutineItem(task, index + 1);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCoroutineItem(CourseSelectionTask task, int coroutineIndex) {
    final statusInfo = TaskStatusInfo.fromTask(task);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: _buildCoroutineIcon(task, statusInfo),
          ),

          const SizedBox(width: 12),

          Row(
            children: [
              Text(
                '协程$coroutineIndex: ',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                statusInfo.text,
                style: TextStyle(
                  color: statusInfo.color,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          Flexible(
            child: Container(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                runSpacing: 2,
                children: [
                  if (task.errorMessage != null)
                    Text(
                      task.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  if (task.retryCount > 0)
                    Text(
                      '共重试 ${task.retryCount} 次',
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  if (task.duration != null)
                    Text(
                      '${(task.duration!.inMilliseconds / 1000).toStringAsFixed(2)}s',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoroutineIcon(
    CourseSelectionTask task,
    TaskStatusInfo statusInfo,
  ) {
    if (task.status == CourseSelectionStatus.sending) {
      return AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _blinkAnimation.value,
            child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
          );
        },
      );
    } else {
      return Icon(statusInfo.icon, color: statusInfo.color, size: 20);
    }
  }

  Widget _buildSubmitButton() {
    final canStop = _isSubmitting && !_stopRequested;
    final canSubmit = _tasks.isNotEmpty && !_isSubmitting;
    final isDisabled = _tasks.isEmpty && !_isSubmitting;

    return Container(
      height: 56,
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
        color: isDisabled
            ? Colors.grey.shade400
            : _isSubmitting
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: canStop
              ? _requestStopSubmission
              : canSubmit
              ? _handleSubmit
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSubmitting)
                  Icon(
                    _stopRequested ? Icons.hourglass_empty : Icons.stop_circle,
                    color: Colors.white,
                    size: 20,
                  )
                else
                  Icon(
                    _tasks.isEmpty ? Icons.warning : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isSubmitting
                      ? _stopRequested
                          ? '停止中...'
                          : '停止提交'
                      : _tasks.isEmpty
                      ? '请先选择课程'
                      : '提交选课申请',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    // Reset
    _initializeTasks();
    _stopRequested = false;

    final Set<String> uniqueCourses = {};
    for (final task in _tasks) {
      uniqueCourses.add(task.course.uniqueKey);
    }
    final courseCount = uniqueCourses.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提交选课'),
        content: Text('确认提交 $courseCount 门课程的选课申请？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startSubmission();
            },
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSubmission() async {
    _safeSetState(() {
      _isSubmitting = true;
      _stopRequested = false;
    });

    try {
      final startupInterval = (1000 / _concurrencyCount).round();

      final futures = <Future>[];
      for (int i = 0; i < _tasks.length; i++) {
        final task = _tasks[i];
        final delay = Duration(milliseconds: startupInterval * i);
        final future = Future.delayed(delay, () => _executeTask(task));
        futures.add(future);
      }

      await Future.wait(futures);

      if (mounted) {
        if (_stopRequested) {
          _showStopResult();
        } else {
          _showSubmitResult();
        }
      }
    } catch (e) {
      // ignored
    } finally {
      _safeSetState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _executeTask(CourseSelectionTask task) async {
    int maxRetries = _autoRetry ? 33550336 : 1;

    for (int retry = 0; retry < maxRetries; retry++) {
      if (_stopRequested) {
        _safeSetState(() {
          task.endTime = DateTime.now();
          task.status = CourseSelectionStatus.cancelled;
          task.errorMessage = '已停止';
        });
        return;
      }

      final courseKey = task.course.uniqueKey;
      if (_courseSuccessMap[courseKey] == true) {
        _safeSetState(() {
          if (task.status != CourseSelectionStatus.idle) {
            task.previousStatus = task.status;
          }
          task.status = CourseSelectionStatus.cancelled;
          task.errorMessage = '同课程其他协程已成功';
        });
        return;
      }

      if (retry > 0) {
        task.previousStatus = task.status;
      }

      _safeSetState(() {
        task.status = CourseSelectionStatus.sending;
        task.startTime = DateTime.now();
        task.retryCount = retry;
        task.errorMessage = null;
      });

      try {
        final success = await _serviceProvider.coursesService
            .sendCourseSelection(widget.termInfo, task.course)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException(null),
            );

        _safeSetState(() {
          task.endTime = DateTime.now();
          if (success) {
            task.status = CourseSelectionStatus.success;
            _courseSuccessMap[courseKey] = true;
          } else {
            task.status = CourseSelectionStatus.errorApi;
            task.errorMessage = '选课失败';
          }
        });

        if (success) {
          return;
        }
      } on TimeoutException catch (_) {
        _safeSetState(() {
          task.endTime = DateTime.now();
          task.status = CourseSelectionStatus.errorTimeout;
          task.errorMessage = '超时';
        });
      } catch (e) {
        _safeSetState(() {
          task.endTime = DateTime.now();

          if (e.toString().contains('网络') || e.toString().contains('network')) {
            task.status = CourseSelectionStatus.errorNetwork;
            task.errorMessage = '网络错误';
          } else {
            task.status = CourseSelectionStatus.errorApi;
            task.errorMessage = e.toString().replaceAll('Exception: ', '');
          }
        });
      }

      if (_stopRequested) {
        _safeSetState(() {
          task.endTime = DateTime.now();
          task.status = CourseSelectionStatus.cancelled;
          task.errorMessage = '已停止';
        });
        return;
      }

      if (retry < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
  }

  void _showSubmitResult() {
    final Map<String, bool> courseResults = {};

    for (final task in _tasks) {
      final courseKey = task.course.uniqueKey;
      if (task.status == CourseSelectionStatus.success) {
        courseResults[courseKey] = true;
      } else if (!courseResults.containsKey(courseKey)) {
        courseResults[courseKey] = false;
      }
    }

    int successCourseCount = courseResults.values
        .where((success) => success)
        .length;
    int totalCourseCount = courseResults.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(successCourseCount == totalCourseCount ? '提交完成' : '提交结果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功：$successCourseCount / $totalCourseCount 门课程'),
            if (successCourseCount < totalCourseCount) ...[
              const SizedBox(height: 8),
              const Text(
                '部分课程选课失败，请检查详情或稍后重试。',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showStopResult() {
    final Map<String, bool> courseResults = {};

    for (final task in _tasks) {
      final courseKey = task.course.uniqueKey;
      if (task.status == CourseSelectionStatus.success) {
        courseResults[courseKey] = true;
      } else if (!courseResults.containsKey(courseKey)) {
        courseResults[courseKey] = false;
      }
    }

    int successCourseCount = courseResults.values
        .where((success) => success)
        .length;
    int totalCourseCount = courseResults.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('提交已停止'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功：$successCourseCount / $totalCourseCount 门课程'),
            const SizedBox(height: 8),
            const Text(
              '已停止后续提交。',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
