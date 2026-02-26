import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '/services/provider.dart';
import '/types/courses.dart';

// Alerts and dialogs

Future<bool?> alertWarning(BuildContext context, String content, String tip) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('选课警告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: const TextStyle(fontSize: 16)),
            if (tip.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tip,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('否'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('是'),
          ),
        ],
      );
    },
  );
}

Future<bool?> alertClassDuplicatedWarning(BuildContext context) {
  return alertWarning(context, '您真的要在同一课程下选择多个讲台吗？', '服务器很可能会拒绝你所选的多余的讲台。');
}

Future<bool?> alertClassFullWarning(BuildContext context) {
  return alertWarning(
    context,
    '您真的要选择容量已满的讲台吗？',
    '提交选课后，服务器很可能会拒绝您目前的请求，但采用特定的重试策略则有机会实现退课候补。',
  );
}

Future<bool?> alertClearSelectedWarning(BuildContext context) {
  return alertWarning(context, '您真的要清除备选课程列表吗？', '');
}

Future<bool?> alertDeselectCourseWarning(
  BuildContext context,
  String courseName,
) {
  return alertWarning(
    context,
    '您真的要退选课程“$courseName”吗？',
    '退选后，您可能无法再次选入该课程（特别是在讲台已满的情况下）。',
  );
}

class CourseDeselectionDialog extends StatefulWidget {
  final TermInfo termInfo;
  final CourseInfo course;
  final Function(bool success) onDeselectionComplete;

  const CourseDeselectionDialog({
    super.key,
    required this.termInfo,
    required this.course,
    required this.onDeselectionComplete,
  });

  @override
  State<CourseDeselectionDialog> createState() =>
      _CourseDeselectionDialogState();
}

class _CourseDeselectionDialogState extends State<CourseDeselectionDialog> {
  bool _isLoading = false;
  bool? _isSuccess;
  String? _errorMessage;

  Future<void> _runDeselection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await ServiceProvider.instance.coursesService
          .sendCourseDeselection(widget.termInfo, widget.course);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = success;
        });
        widget.onDeselectionComplete.call(success);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _errorMessage = e.toString();
        });
        widget.onDeselectionComplete.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess == true) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('退课成功'),
          ],
        ),
        content: Text(
          '您已退选课程“${widget.course.courseName}”。',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      );
    }

    if (_isSuccess == false) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('退课失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('发起的退选请求未能成功。', style: TextStyle(fontSize: 16)),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '错误原因：${_errorMessage!}',
                  style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning,
            color: Theme.of(context).colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('退课'),
        ],
      ),
      content: _isLoading
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('正在发起退课请求...', style: TextStyle(fontSize: 16)),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '您真的要退选课程“${widget.course.courseName}”吗？',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '退课后，您可能无法再次选入该课程。您应在知晓退课风险的前提下继续。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      actions: [
        if (!_isLoading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          ElevatedButton(onPressed: _runDeselection, child: const Text('确认退课')),
        ],
      ],
    );
  }
}

// Indicators

Widget buildStepIndicator(BuildContext context, int currentStep) {
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
        _buildStepItem(context, '选择学期', 1, currentStep == 1),
        _buildStepConnector(context),
        _buildStepItem(context, '选择课程', 2, currentStep == 2),
        _buildStepConnector(context),
        _buildStepItem(context, '提交选课', 3, currentStep == 3),
      ],
    ),
  );
}

Widget _buildStepItem(
  BuildContext context,
  String title,
  int stepNumber,
  bool isActive,
) {
  return Expanded(
    child: Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildStepConnector(BuildContext context) {
  return Container(
    height: 2,
    width: 20,
    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
  );
}

Widget buildTermInfoDisplay(BuildContext context, TermInfo termInfo) {
  return Container(
    margin: const EdgeInsets.only(right: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 2),
        Text(
          '${termInfo.year}-${termInfo.season}',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

// Cooldown Handler

class CooldownHandler {
  final TickerProvider vsync;
  final Duration forwardDuration;
  final Duration reverseDuration;
  final Curve curve;
  final Curve reverseCurve;

  late final AnimationController controller;
  late final Animation<double> animation;

  CooldownHandler({
    required this.vsync,
    this.forwardDuration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 3000),
    this.curve = Curves.easeOut,
    this.reverseCurve = Curves.easeIn,
  }) {
    controller = AnimationController(
      vsync: vsync,
      duration: forwardDuration,
      reverseDuration: reverseDuration,
    );
    animation = CurvedAnimation(
      parent: controller,
      curve: curve,
      reverseCurve: reverseCurve,
    );
  }

  bool get isCoolingDown => controller.value > 0.001;

  void start({bool Function()? isMounted}) {
    _runAfterBuild(() {
      if (isMounted != null && !isMounted()) return;
      controller.stop();
      controller.value = 0;
      controller.forward();
    });
  }

  void finish({bool Function()? isMounted}) {
    _runAfterBuild(() {
      if (isMounted != null && !isMounted()) return;
      if (controller.status == AnimationStatus.reverse) return;
      controller.reverse(from: controller.value);
    });
  }

  void dispose() {
    controller.dispose();
  }

  void _runAfterBuild(VoidCallback action) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks;
    if (shouldDefer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
      return;
    }
    action();
  }
}
