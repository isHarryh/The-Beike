import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/provider.dart';
import '../../services/sync/convert.dart';
import '../../types/sync.dart';
import '../../utils/app_bar.dart';
import '../../utils/meta_info.dart';

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

  @override
  void initState() {
    super.initState();
    _checkUpdate();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '版本更新', actions: const []),
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

    final currentPlatform = MetaInfo.instance.platformName.toLowerCase();
    final downloads = _releaseInfo!.stableDownloads;
    final currentEntry = downloads.entries.firstWhere(
      (e) => e.key.toLowerCase() == currentPlatform,
      orElse: () => downloads.entries.first,
    );
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
        _PlatformDownloadsCard(
          title: _releaseInfo!.getDisplayPlatformName(currentEntry.key),
          sources: currentEntry.value,
          releaseInfo: _releaseInfo!,
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

  const _PlatformDownloadsCard({
    required this.title,
    required this.sources,
    required this.releaseInfo,
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

  const _DownloadSourceTile({
    required this.name,
    required this.tip,
    required this.url,
    required this.isRecommended,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
