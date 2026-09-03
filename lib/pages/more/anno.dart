import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '/services/provider.dart';
import '/types/sync.dart';
import '/types/preferences.dart';
import '/utils/app_bar.dart';
import '/utils/sync_embeded.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  List<Announcement>? _announcements;
  String? _errorMessage;
  bool _isLoading = true;
  int? _expandedIndex;
  Set<String> _unreadKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final announcements = await _serviceProvider.syncService
          .getAnnouncements();

      // Process read status
      await _processReadStatus(announcements);

      if (mounted) {
        setState(() {
          _announcements = announcements;
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

  AnnouncementReadMap _loadReadMap() {
    return _serviceProvider.storeService.getConfig<AnnouncementReadMap>(
          'announcement_read',
          AnnouncementReadMap.fromJson,
        ) ??
        AnnouncementReadMap.defaultMap;
  }

  Future<void> _processReadStatus(List<Announcement> announcements) async {
    final store = _serviceProvider.storeService;
    final readMap = _loadReadMap();

    // Find unread announcements
    final currentKeys = announcements.map((a) => a.calculateKey()).toSet();
    final unreadKeys = <String>{};
    for (final announcement in announcements) {
      final key = announcement.calculateKey();
      if (!readMap.readTimestamp.containsKey(key)) {
        unreadKeys.add(key);
      }
    }

    // Remove deleted announcements from read map
    final keysToRemove = readMap.readTimestamp.keys
        .where((key) => !currentKeys.contains(key))
        .toList();
    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        readMap.readTimestamp.remove(key);
      }
      store.putConfig('announcement_read', readMap);
    }

    _unreadKeys = unreadKeys;
  }

  Future<void> _markReadStatus(Announcement announcement, bool isRead) async {
    final key = announcement.calculateKey();
    final store = _serviceProvider.storeService;
    final readMap = _loadReadMap();

    if (isRead) {
      // Update read timestamp
      readMap.readTimestamp[key] = DateTime.now();
      store.putConfig('announcement_read', readMap);
      setState(() {
        _unreadKeys.remove(key);
      });
    } else {
      // Remove from read timestamp to mark as unread
      readMap.readTimestamp.remove(key);
      store.putConfig('announcement_read', readMap);
      setState(() {
        _unreadKeys.add(key);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '公告'),
      body: SyncPowered(
        childBuilder: (context) => RefreshIndicator(
          onRefresh: _loadAnnouncements,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('加载公告失败', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAnnouncements,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_announcements!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('暂无公告', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _announcements!.length,
        itemBuilder: (context, index) {
          final announcement = _announcements![index];
          final isExpanded = _expandedIndex == index;
          final key = announcement.calculateKey();
          final isUnread = _unreadKeys.contains(key);

          return _AnnouncementCard(
            announcement: announcement,
            isExpanded: isExpanded,
            isUnread: isUnread,
            onExpandChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedIndex = index;
                  _markReadStatus(announcement, true);
                } else if (_expandedIndex == index) {
                  _expandedIndex = null;
                }
              });
            },
            onMarkReadStatus: (isRead) => _markReadStatus(announcement, isRead),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  final Announcement announcement;
  final bool isExpanded;
  final bool isUnread;
  final ValueChanged<bool> onExpandChanged;
  final ValueChanged<bool> onMarkReadStatus;

  const _AnnouncementCard({
    required this.announcement,
    required this.isExpanded,
    required this.isUnread,
    required this.onExpandChanged,
    required this.onMarkReadStatus,
  });

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Helper methods for group-based styling
  Color _getBorderColor() {
    final group = widget.announcement.group.toLowerCase();
    switch (group) {
      case 'info':
        return Colors.blue;
      case 'warn':
        return Colors.orange;
      case 'danger':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String? _getGroupLabelText() {
    final group = widget.announcement.group.toLowerCase();
    switch (group) {
      case 'info':
        return '普通公告';
      case 'warn':
        return '重要公告';
      case 'danger':
        return '紧急公告';
      default:
        return null; // Don't show label for unknown groups
    }
  }

  // Helper method to format date
  String? _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }

    try {
      // Try to parse the date string
      DateTime dateTime = DateTime.parse(dateString);
      // Format as yyyy-MM-dd
      return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } catch (e) {
      // If parsing fails, return null to hide the date
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    if (widget.isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(_AnnouncementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !oldWidget.isExpanded) {
      _animationController.forward();
    } else if (!widget.isExpanded && oldWidget.isExpanded) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _getBorderColor(), width: 4)),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and expand button
            InkWell(
              borderRadius: BorderRadius.circular(8),
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => widget.onExpandChanged(!widget.isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title (without unread indicator)
                          Text(
                            widget.announcement.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Meta info (date)
                          Row(
                            children: [
                              if (_formatDate(widget.announcement.date) !=
                                  null) ...[
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(widget.announcement.date)!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expand/collapse button or unread indicator
                    if (widget.isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getBorderColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '未读',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      )
                    else
                      RotationTransition(
                        turns: Tween<double>(
                          begin: -0.25,
                          end: 0.25,
                        ).animate(_animationController),
                        child: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Expanded content
            ClipRect(
              child: SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeInOutCubic,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group and Language tags with mark as unread button
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side: Group and Language tags
                          Row(
                            children: [
                              // Group tag
                              if (_getGroupLabelText() != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getGroupLabelText()!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Language tag if available
                              if (widget.announcement.language != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.translate,
                                        size: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.announcement.language!
                                            .toUpperCase(),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!widget.isUnread && kDebugMode)
                            // Right side: Mark as unread button
                            TextButton.icon(
                              onPressed: () => widget.onMarkReadStatus(false),
                              icon: Icon(
                                Icons.mark_email_unread,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              label: Text(
                                '标为未读',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                minimumSize: Size.zero,
                              ),
                            ),
                        ],
                      ),
                      // Content (Markdown)
                      MarkdownBlock(
                        data: widget.announcement.markdown,
                        config: config,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
