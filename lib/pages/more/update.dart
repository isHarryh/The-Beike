import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/provider.dart';
import '../../services/sync/convert.dart';
import '../../services/update/exceptions.dart';
import '../../types/sync.dart';
import '../../utils/app_bar.dart';
import '../../utils/meta_info.dart';

enum _DownloadPhase { downloading, downloaded, failed }

class _DownloadTask {
  final String url;
  final String savePath;
  final CancelToken cancelToken;
  _DownloadPhase phase = _DownloadPhase.downloading;
  int received = 0;
  int? total;
  String? error;

  _DownloadTask({required this.url, required this.savePath})
    : cancelToken = CancelToken();
}

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _isLoading = false;
  String? _error;
  ReleaseInfo? _releaseInfo;
  bool _expandOtherPlatforms = false;
  _DownloadTask? _download;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  @override
  void dispose() {
    final task = _download;
    if (task != null) {
      if (task.phase == _DownloadPhase.downloading) {
        task.cancelToken.cancel('page disposed');
      }
      ServiceProvider.instance.updateService.deleteFile(task.savePath);
    }
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _releaseInfo = null;
    });

    try {
      final info = await ServiceProvider.instance.syncService.getRelease();
      if (mounted) {
        setState(() {
          _releaseInfo = info;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatVersion(String version) {
    if (!version.startsWith('v')) {
      return 'v$version';
    }
    return version;
  }

  bool get _hasUpdate {
    if (_releaseInfo == null) return false;
    final currentVersion = MetaInfo.instance.appVersion;
    final latestVersion = _releaseInfo!.stableVersion;

    try {
      // Parse versions like "1.0.0" or "v1.0.0"
      final currentStr = currentVersion.split('+')[0].replaceFirst('v', '');
      final latestStr = latestVersion.replaceFirst('v', '');

      final currentParts = currentStr.split('.').map(int.parse).toList();
      final latestParts = latestStr.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final current = i < currentParts.length ? currentParts[i] : 0;
        final latest = i < latestParts.length ? latestParts[i] : 0;
        if (latest > current) return true;
        if (latest < current) return false;
      }
      return false;
    } catch (e) {
      return false; // Fallback
    }
  }

  Future<void> _startDownload(String url) async {
    final release = _releaseInfo;
    if (release == null) return;
    final updateService = ServiceProvider.instance.updateService;

    final current = _download;
    if (current != null) {
      if (current.phase == _DownloadPhase.downloading) return;
      await updateService.deleteFile(current.savePath);
    }

    final version = release.stableVersion.replaceFirst('v', '');
    final ext = MetaInfo.instance.platformName == 'android' ? 'apk' : 'exe';
    final fileName = 'TheBeike-$version.$ext';

    String savePath;
    try {
      savePath = await updateService.getSavePath(fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法准备下载目录: $e')));
      }
      return;
    }

    final task = _DownloadTask(url: url, savePath: savePath);
    setState(() {
      _download = task;
    });

    try {
      await updateService.downloadFile(
        url: url,
        savePath: savePath,
        onProgress: (received, total) {
          if (!mounted || _download != task) return;
          setState(() {
            task
              ..received = received
              ..total = total;
          });
        },
        cancelToken: task.cancelToken,
      );
      if (!mounted || _download != task) return;
      setState(() {
        task.phase = _DownloadPhase.downloaded;
      });
    } catch (e) {
      if (!mounted || _download != task) return;
      await updateService.deleteFile(savePath);
      if (task.cancelToken.isCancelled) {
        setState(() {
          _download = null;
        });
        return;
      }
      setState(() {
        task
          ..phase = _DownloadPhase.failed
          ..error = e.toString();
      });
    }
  }

  void _cancelDownload() {
    _download?.cancelToken.cancel('user cancelled');
  }

  Future<void> _clearDownload() async {
    final task = _download;
    if (task == null) return;
    await ServiceProvider.instance.updateService.deleteFile(task.savePath);
    if (mounted) {
      setState(() {
        _download = null;
      });
    }
  }

  Future<void> _install() async {
    final task = _download;
    if (task == null) return;
    final isWindows = MetaInfo.instance.platformName == 'windows';

    try {
      await ServiceProvider.instance.updateService.install(task.savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isWindows ? '安装程序已启动，当前应用会自动关闭' : '已发起安装，请在系统提示中完成安装',
            ),
          ),
        );
      }
    } on UpdateServicePermissionDenied {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('需要"安装未知应用"权限才能安装更新'),
          action: SnackBarAction(label: '去设置', onPressed: openAppSettings),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('安装失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '版本更新'),
      body: RefreshIndicator(
        onRefresh: _checkUpdate,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVersionCards(context),
              const SizedBox(height: 36),
              if (_releaseInfo != null) _buildDownloadLinks(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionCards(BuildContext context) {
    final theme = Theme.of(context);
    final latestText = _releaseInfo != null
        ? _formatVersion(_releaseInfo!.stableVersion)
        : (_isLoading ? '请稍后' : 'N/A');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.commit, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '版本信息',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _isLoading ? null : _checkUpdate,
            ),
            const SizedBox(width: 2),
            _buildStatusChip(theme),
            const SizedBox(width: 2),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _VersionPill(
              title: '当前',
              value: _formatVersion(MetaInfo.instance.appVersion),
              color: !_hasUpdate
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              textColor: !_hasUpdate
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward_ios, size: 16),
            ),
            _VersionPill(
              title: '最新',
              value: latestText,
              color: _hasUpdate
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              textColor: _hasUpdate
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadLinks(BuildContext context) {
    if (_releaseInfo == null || _releaseInfo!.stableDownloads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: Text('暂无可用下载链接')),
      );
    }

    final updateService = ServiceProvider.instance.updateService;
    final canInstallInApp = updateService.supportsInAppUpdate && _hasUpdate;
    final currentPlatform = MetaInfo.instance.platformName.toLowerCase();
    final downloads = _releaseInfo!.stableDownloads;
    final currentEntry = downloads.entries
        .where((e) => e.key.toLowerCase() == currentPlatform)
        .firstOrNull;
    final otherPlatforms = downloads.entries
        .where((e) => e.key.toLowerCase() != currentPlatform)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.download_done, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              '安装包下载',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (currentEntry != null)
          _PlatformDownloadsCard(
            title: _releaseInfo!.getDisplayPlatformName(currentEntry.key),
            sources: currentEntry.value,
            releaseInfo: _releaseInfo!,
            downloadTask: _download,
            onDownload: canInstallInApp ? _startDownload : null,
            onCancel: _cancelDownload,
            onInstall: _install,
            onClear: _clearDownload,
          ),
        if (otherPlatforms.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: ExpansionTile(
              title: const Text('其他平台'),
              initiallyExpanded: _expandOtherPlatforms,
              onExpansionChanged: (v) => setState(() {
                _expandOtherPlatforms = v;
              }),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    children: otherPlatforms
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PlatformDownloadsCard(
                              title: _releaseInfo!.getDisplayPlatformName(
                                entry.key,
                              ),
                              sources: entry.value,
                              releaseInfo: _releaseInfo!,
                              downloadTask: _download,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    if (_isLoading) {
      return Chip(
        avatar: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('正在检查'),
      );
    }
    if (_error != null) {
      return Chip(
        avatar: const Icon(Icons.error_outline, color: Colors.red),
        label: const Text('检查失败'),
        backgroundColor: theme.colorScheme.errorContainer,
        labelStyle: TextStyle(
          color: theme.colorScheme.onErrorContainer,
          fontSize: 12,
        ),
      );
    }
    return Chip(
      avatar: Icon(
        _hasUpdate ? Icons.upgrade : Icons.verified,
        color: _hasUpdate ? theme.colorScheme.primary : Colors.green,
      ),
      label: Text(_hasUpdate ? '发现新版本' : '已是最新版'),
    );
  }
}

class _PlatformDownloadsCard extends StatelessWidget {
  final String title;
  final Map<String, String> sources;
  final ReleaseInfo releaseInfo;
  final _DownloadTask? downloadTask;
  final void Function(String url)? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onInstall;
  final VoidCallback? onClear;

  const _PlatformDownloadsCard({
    required this.title,
    required this.sources,
    required this.releaseInfo,
    this.downloadTask,
    this.onDownload,
    this.onCancel,
    this.onInstall,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...sources.entries.map(
              (entry) => _DownloadSourceTile(
                name: releaseInfo.getDisplayDownloadChannelName(entry.key),
                tip: releaseInfo.getDisplayDownloadChannelTip(entry.key),
                url: entry.value,
                isRecommended: releaseInfo.getIsRecommendedChannel(entry.key),
                downloadTask: downloadTask,
                onDownload: onDownload,
                onCancel: onCancel,
                onInstall: onInstall,
                onClear: onClear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadSourceTile extends StatelessWidget {
  final String name;
  final String tip;
  final String url;
  final bool isRecommended;
  final _DownloadTask? downloadTask;
  final void Function(String url)? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onInstall;
  final VoidCallback? onClear;

  const _DownloadSourceTile({
    required this.name,
    required this.tip,
    required this.url,
    required this.isRecommended,
    this.downloadTask,
    this.onDownload,
    this.onCancel,
    this.onInstall,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = downloadTask?.url == url ? downloadTask : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '推荐',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                if (tip.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      tip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTrailing(context, task),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, _DownloadTask? task) {
    final theme = Theme.of(context);
    if (task != null) {
      return switch (task.phase) {
        _DownloadPhase.downloading => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 96,
                  child: LinearProgressIndicator(
                    value: task.total != null && task.total! > 0
                        ? (task.received / task.total!)
                              .clamp(0.0, 1.0)
                              .toDouble()
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatProgress(task),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '取消下载',
              onPressed: onCancel,
            ),
          ],
        ),
        _DownloadPhase.downloaded => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onInstall,
              icon: const Icon(Icons.download_done, size: 18),
              label: const Text('安装'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '删除安装包',
              onPressed: onClear,
            ),
          ],
        ),
        _DownloadPhase.failed => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '下载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: '重试',
              onPressed: onDownload == null ? null : () => onDownload!(url),
            ),
          ],
        ),
      };
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDownload != null)
          IconButton(
            icon: const Icon(Icons.download, size: 22),
            color: theme.colorScheme.primary,
            tooltip: '下载并安装',
            onPressed: () => onDownload!(url),
          ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: '复制链接',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('下载链接已复制')));
          },
        ),
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 20),
          color: theme.colorScheme.primary,
          tooltip: '打开链接',
          onPressed: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('无法打开下载链接')));
              }
            }
          },
        ),
      ],
    );
  }

  String _formatProgress(_DownloadTask task) {
    final total = task.total;
    if (total == null || total <= 0) {
      return '${(task.received / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    final percent = (task.received / total * 100).clamp(0, 100).floor();
    return '$percent%';
  }
}

class _VersionPill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final Color textColor;

  const _VersionPill({
    required this.title,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
