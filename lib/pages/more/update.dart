import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  String? _selectedPlatform;
  String? _selectedChannel;
  bool _redownloadRevealed = false;
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

  String _formatVersion(String version) =>
      version.startsWith('v') ? version : 'v$version';

  bool get _hasUpdate {
    if (_releaseInfo == null) return false;
    final currentVersion = MetaInfo.instance.appVersion;
    final latestVersion = _releaseInfo!.stableVersion;

    try {
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
      return false;
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

  void _dismissFailedDownload() {
    setState(() {
      _download = null;
    });
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
              if (_releaseInfo != null) _buildDownloadSection(context),
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

  MapEntry<String, Map<String, String>>? get _selectedPlatformEntry {
    final downloads = _releaseInfo?.stableDownloads;
    if (downloads == null || downloads.isEmpty) return null;
    final selected = _selectedPlatform;
    if (selected != null && downloads.containsKey(selected)) {
      return MapEntry(selected, downloads[selected]!);
    }
    final current = MetaInfo.instance.platformName.toLowerCase();
    for (final e in downloads.entries) {
      if (e.key.toLowerCase() == current) return e;
    }
    return null;
  }

  String _effectiveChannelKey(MapEntry<String, Map<String, String>> entry) {
    final release = _releaseInfo!;
    final selected = _selectedChannel;
    if (selected != null && entry.value.containsKey(selected)) {
      return selected;
    }
    final recommended = entry.value.keys
        .where((c) => release.getIsRecommendedChannel(c))
        .firstOrNull;
    return recommended ?? entry.value.keys.first;
  }

  String? _channelNameOfUrl(String url) {
    final downloads = _releaseInfo?.stableDownloads;
    if (downloads == null) return null;
    for (final platform in downloads.entries) {
      for (final channel in platform.value.entries) {
        if (channel.value == url) {
          return _releaseInfo!.getDisplayDownloadChannelName(channel.key);
        }
      }
    }
    return null;
  }

  Widget _buildDownloadSection(BuildContext context) {
    final theme = Theme.of(context);
    if (_releaseInfo!.stableDownloads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text('暂无可用下载链接', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final task = _download;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.download_done, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text(
              '安装包下载',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: task == null
                ? _buildCtaBody(context)
                : _buildTaskBody(context, task),
          ),
        ),
      ],
    );
  }

  Widget _buildCtaBody(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _selectedPlatformEntry;

    if (entry == null || entry.value.isEmpty) {
      return Text(
        '暂无适用于当前平台的下载链接。',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final release = _releaseInfo!;
    final channelKey = _effectiveChannelKey(entry);
    final url = entry.value[channelKey]!;
    final isCurrentPlatform =
        entry.key.toLowerCase() == MetaInfo.instance.platformName.toLowerCase();
    final canInstallInApp =
        isCurrentPlatform &&
        ServiceProvider.instance.updateService.supportsInAppUpdate;

    if (!_hasUpdate && canInstallInApp && !_redownloadRevealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                '已是最新版本',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '如安装包损坏或需要重装，可重新下载。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _redownloadRevealed = true;
              }),
              child: const Text('重新下载安装包'),
            ),
          ),
        ],
      );
    }

    Widget buildHeader({required bool centered}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            '${release.getDisplayPlatformName(entry.key)} ${release.getDisplayDownloadChannelName(channelKey)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: centered ? TextAlign.center : null,
          ),
          const SizedBox(height: 2),
          Text(
            release.getDisplayDownloadChannelTip(channelKey),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: centered ? TextAlign.center : null,
          ),
        ],
      );
    }

    final switchButton = TextButton.icon(
      onPressed: _showSelectionSheet,
      icon: const Icon(Icons.swap_horiz, size: 18),
      label: const Text('更换下载源或操作系统'),
      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 480
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: buildHeader(centered: false)),
                    const SizedBox(width: 12),
                    switchButton,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeader(centered: true),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: switchButton),
                  ],
                ),
        ),
        const Divider(height: 24),
        SizedBox(
          width: double.infinity,
          child: canInstallInApp
              ? FilledButton.icon(
                  onPressed: () => _startDownload(url),
                  icon: const Icon(Icons.download),
                  label: const Text('一键下载并安装'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                )
              : FilledButton.icon(
                  onPressed: () => _openDownloadUrl(context, url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('跳转查看'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => _QrDialog(
                    platformName: release.getDisplayPlatformName(entry.key),
                    channelName: release.getDisplayDownloadChannelName(
                      channelKey,
                    ),
                    url: url,
                  ),
                ),
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('扫码下载'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _copyDownloadUrl(context, url),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制链接'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskBody(BuildContext context, _DownloadTask task) {
    final versionText = _formatVersion(_releaseInfo!.stableVersion);
    return switch (task.phase) {
      _DownloadPhase.downloading => _buildDownloadingBody(
        context,
        task,
        versionText,
      ),
      _DownloadPhase.downloaded => _buildDownloadedBody(
        context,
        task,
        versionText,
      ),
      _DownloadPhase.failed => _buildFailedBody(context, task, versionText),
    };
  }

  Widget _buildDownloadingBody(
    BuildContext context,
    _DownloadTask task,
    String versionText,
  ) {
    final theme = Theme.of(context);
    final total = task.total;
    final hasTotal = total != null && total > 0;
    final progress = hasTotal
        ? (task.received / total).clamp(0.0, 1.0).toDouble()
        : null;
    final channelName = _channelNameOfUrl(task.url);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '正在下载 $versionText',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '取消下载',
              onPressed: _cancelDownload,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              hasTotal
                  ? '${_formatBytes(task.received)} / ${_formatBytes(total)}'
                  : _formatBytes(task.received),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (progress != null)
              Text(
                '${(progress * 100).floor()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (channelName != null) ...[
          const SizedBox(height: 4),
          Text(
            '通过 $channelName 下载',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadedBody(
    BuildContext context,
    _DownloadTask task,
    String versionText,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.download_done, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$versionText 安装包已就绪',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.system_update_alt),
                label: const Text('立即安装'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _clearDownload,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFailedBody(
    BuildContext context,
    _DownloadTask task,
    String versionText,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$versionText 下载失败',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          task.error ?? '未知错误',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () => _startDownload(task.url),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _dismissFailedDownload,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('返回'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    final mb = bytes / 1024 / 1024;
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} GB';
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  void _showSelectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _SelectionSheet(
        releaseInfo: _releaseInfo!,
        onSelect: (platform, channel) {
          Navigator.pop(sheetContext);
          setState(() {
            _selectedPlatform = platform;
            _selectedChannel = channel;
          });
        },
      ),
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

void _copyDownloadUrl(BuildContext context, String url) {
  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('下载链接已复制')));
}

Future<void> _openDownloadUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开下载链接')));
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

class _SelectionSheet extends StatelessWidget {
  final ReleaseInfo releaseInfo;
  final void Function(String platform, String channel) onSelect;

  const _SelectionSheet({required this.releaseInfo, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '其他下载源或操作系统',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            ...releaseInfo.stableDownloads.entries.map(
              (entry) => _buildPlatformGroup(context, entry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformGroup(
    BuildContext context,
    MapEntry<String, Map<String, String>> entry,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(releaseInfo.getDisplayPlatformName(entry.key)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: entry.value.entries
                  .map(
                    (channel) => _buildChannelRow(context, entry.key, channel),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(
    BuildContext context,
    String platform,
    MapEntry<String, String> channel,
  ) {
    final theme = Theme.of(context);
    final name = releaseInfo.getDisplayDownloadChannelName(channel.key);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.cloud_download_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (releaseInfo.getIsRecommendedChannel(channel.key)) ...[
            const SizedBox(width: 4),
            const _MiniBadge('推荐'),
          ],
        ],
      ),
      onTap: () => onSelect(platform, channel.key),
    );
  }
}

class _QrDialog extends StatelessWidget {
  final String platformName;
  final String channelName;
  final String url;

  const _QrDialog({
    required this.platformName,
    required this.channelName,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '扫码下载程序',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$platformName · $channelName',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _copyDownloadUrl(context, url),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制链接'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openDownloadUrl(context, url),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('在浏览器打开'),
            ),
          ],
        ),
      ),
    );
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
