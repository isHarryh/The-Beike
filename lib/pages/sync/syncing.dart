import 'dart:async';
import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/sync.dart';

class SyncingCard extends StatefulWidget {
  final ServiceProvider serviceProvider;
  final SyncDeviceData syncData;
  final ValueChanged<dynamic> onError;

  const SyncingCard({
    super.key,
    required this.serviceProvider,
    required this.syncData,
    required this.onError,
  });

  @override
  State<SyncingCard> createState() => _SyncingCardState();
}

class _SyncingCardState extends State<SyncingCard> {
  bool _isSyncing = false;

  // Debounce and refresh
  static const Duration _debounceInterval = Duration(seconds: 3);
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update UI (time display, button state)
        });
      }
    });
  }

  int _getSecondsUntilNextSync() {
    final syncStatus = widget.serviceProvider.syncService.lastSyncStatus;
    if (syncStatus == null) return 0;

    final elapsed = DateTime.now().difference(syncStatus.timestamp);
    final remaining = _debounceInterval.inSeconds - elapsed.inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 1000;

    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: isWideScreen
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildSyncNowSection(),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildSyncStatusSection(),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSyncNowSection(),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSyncStatusSection(),
                ),
              ],
            ),
    );
  }

  Widget _buildSyncNowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.sync_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '立即同步',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '您的配置将在不同设备间自动同步。当然，您也可以在这里手动触发一次配置同步。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: _buildSyncButton()),
      ],
    );
  }

  Widget _buildSyncButton() {
    final secondsRemaining = _getSecondsUntilNextSync();
    final canSync = secondsRemaining == 0 && !_isSyncing;

    String buttonLabel;
    if (_isSyncing) {
      buttonLabel = '同步中...';
    } else if (secondsRemaining > 0) {
      buttonLabel = '立即同步 (${secondsRemaining}s)';
    } else {
      buttonLabel = '立即同步';
    }

    return FilledButton.icon(
      onPressed: canSync ? _handleSyncNow : null,
      icon: _isSyncing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.cloud_sync_outlined),
      label: Text(buttonLabel),
    );
  }

  Widget _buildSyncStatusSection() {
    final syncStatus = widget.serviceProvider.syncService.lastSyncStatus;
    final isSuccess = syncStatus?.isSuccess ?? false;
    final hasStatus = syncStatus != null;

    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isSuccess ? colorScheme.primary : colorScheme.error;
    final containerColor = hasStatus
        ? (isSuccess
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.errorContainer.withValues(alpha: 0.3))
        : colorScheme.surfaceContainerHigh.withValues(alpha: 0.3);
    final onContainerColor = hasStatus
        ? (isSuccess ? colorScheme.primary : colorScheme.error)
        : colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '上次同步状态',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasStatus
                  ? statusColor.withValues(alpha: 0.15)
                  : colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasStatus
                    ? (isSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline)
                    : Icons.history_toggle_off_outlined,
                color: onContainerColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasStatus ? (isSuccess ? '同步成功' : '同步失败') : '暂无同步记录',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: onContainerColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      hasStatus
                          ? _formatTime(syncStatus.timestamp)
                          : '您可手动执行同步',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleSyncNow() async {
    if (widget.syncData.deviceId == null || widget.syncData.groupId == null) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      // Sync status is already recorded by the service
      await widget.serviceProvider.syncAndApplyConfig();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
