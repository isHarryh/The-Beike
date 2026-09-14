// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';

/// An entry of [SideNavigation].
class SideNavigationItem {
  final IconData icon;
  final String title;
  final String path;
  final String? category;

  const SideNavigationItem({
    required this.icon,
    required this.title,
    required this.path,
    this.category,
  });
}

/// The side navigation of the app shell.
///
/// It always shows the pinned home entry, plus a [PageView] that switches
/// between the main entries and the more entries. The selected entry is
/// automatically scrolled into view and the more page is automatically
/// shown when the active page belongs to it.
class SideNavigation extends StatefulWidget {
  /// The width of the sidebar when it is not shown as a drawer.
  static const double width = 240.0;

  /// The app name shown in the banner.
  static const String appName = '大贝壳';

  /// The app icon shown in the banner.
  static const IconData appIcon = Icons.waves;

  /// The pinned home entry which is always visible.
  static const SideNavigationItem homeItem = SideNavigationItem(
    icon: Icons.home,
    title: '主页',
    path: '/',
  );

  /// The entries of the main page, grouped by [SideNavigationItem.category].
  static const List<SideNavigationItem> mainItems = [
    SideNavigationItem(
      icon: Icons.account_circle,
      title: '教务账户',
      path: '/courses/account',
      category: '教务',
    ),
    SideNavigationItem(
      icon: Icons.calendar_today,
      title: '课表',
      path: '/courses/curriculum',
      category: '教务',
    ),
    SideNavigationItem(
      icon: Icons.school,
      title: '选课',
      path: '/courses/selection',
      category: '教务',
    ),
    SideNavigationItem(
      icon: Icons.assignment,
      title: '考试',
      path: '/courses/exam',
      category: '教务',
    ),
    SideNavigationItem(
      icon: Icons.assessment,
      title: '成绩',
      path: '/courses/grade',
      category: '教务',
    ),
    SideNavigationItem(
      icon: Icons.wifi,
      title: '自助服务',
      path: '/net/dashboard',
      category: '校园网',
    ),
    SideNavigationItem(
      icon: Icons.receipt_long,
      title: '流量查询',
      path: '/net/traffic',
      category: '校园网',
    ),
    SideNavigationItem(
      icon: Icons.payments_outlined,
      title: '充值缴费',
      path: '/payment',
      category: '财务',
    ),
    SideNavigationItem(
      icon: Icons.sync,
      title: '跨设备同步',
      path: '/sync',
      category: '同步',
    ),
  ];

  /// The entries of the more page.
  static const List<SideNavigationItem> moreItems = [
    SideNavigationItem(icon: Icons.campaign, title: '公告', path: '/more/anno'),
    SideNavigationItem(
      icon: Icons.cloud_download_outlined,
      title: '更新',
      path: '/more/update',
    ),
    SideNavigationItem(
      icon: Icons.settings,
      title: '设置',
      path: '/more/settings',
    ),
  ];

  /// Whether the page at [path] belongs to the more page.
  static bool isMorePath(String path) =>
      moreItems.any((item) => item.path == path);

  /// Whether this instance is shown as a [Drawer] instead of a sidebar.
  final bool isDrawer;

  /// The path of the currently active page.
  final String currentPath;

  /// Called with the target path when an entry is tapped.
  final void Function(String path) onNavigate;

  const SideNavigation({
    super.key,
    required this.isDrawer,
    required this.currentPath,
    required this.onNavigate,
  });

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  static const Duration _pageSwitchDuration = Duration(milliseconds: 200);
  static const Curve _pageSwitchCurve = Curves.easeInOutCubic;

  late final PageController _pageController;
  late bool _showMore;

  /// The keys used to reveal the selected entry by [Scrollable.ensureVisible].
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _showMore = SideNavigation.isMorePath(widget.currentPath);
    _pageController = PageController(initialPage: _showMore ? 1 : 0);
    _scheduleRevealSelectedItem();
  }

  @override
  void didUpdateWidget(covariant SideNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      // Reposition the page to follow the new active page. A manual switch is
      // only kept while the active page stays unchanged.
      final shouldShowMore = SideNavigation.isMorePath(widget.currentPath);
      if (_showMore != shouldShowMore) {
        _showMore = shouldShowMore;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(shouldShowMore ? 1 : 0);
        }
      }
      _scheduleRevealSelectedItem();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleMore() {
    setState(() {
      _showMore = !_showMore;
    });
    _pageController.animateToPage(
      _showMore ? 1 : 0,
      duration: _pageSwitchDuration,
      curve: _pageSwitchCurve,
    );
  }

  void _scheduleRevealSelectedItem() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final itemContext = _itemKeys[widget.currentPath]?.currentContext;
      if (itemContext == null) return;
      final scrollable = Scrollable.maybeOf(itemContext, axis: Axis.vertical);
      if (scrollable == null) return;
      scrollable.position.ensureVisible(
        itemContext.findRenderObject()!,
        alignment: 0.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isDrawer ? null : SideNavigation.width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: widget.isDrawer
            ? null
            : Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          // Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Row(
              children: [
                Icon(
                  SideNavigation.appIcon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  SideNavigation.appName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Pinned home entry
          _buildItem(
            context,
            icon: SideNavigation.homeItem.icon,
            title: SideNavigation.homeItem.title,
            isSelected: widget.currentPath == SideNavigation.homeItem.path,
            onTap: () => widget.onNavigate(SideNavigation.homeItem.path),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Main page / more page
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMenuPage(context, SideNavigation.mainItems),
                _buildMenuPage(
                  context,
                  SideNavigation.moreItems,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ],
            ),
          ),
          const Divider(),

          // More/collapse switch
          _buildItem(
            context,
            icon: _showMore ? Icons.arrow_back : Icons.more_horiz,
            title: _showMore ? '收起' : '更多',
            isSelected: false,
            onTap: _toggleMore,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuPage(
    BuildContext context,
    List<SideNavigationItem> items, {
    EdgeInsetsGeometry? padding,
  }) {
    final Map<String?, List<SideNavigationItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final children = <Widget>[];

    for (final entry in grouped.entries) {
      final category = entry.key;
      final categoryItems = entry.value;

      if (category != null) {
        children.addAll([
          if (children.isNotEmpty) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
        ]);
      }

      for (final item in categoryItems) {
        children.add(
          _buildItem(
            context,
            key: _itemKeys.putIfAbsent(item.path, () => GlobalKey()),
            icon: item.icon,
            title: item.title,
            isSelected: widget.currentPath == item.path,
            onTap: () => widget.onNavigate(item.path),
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(icon, color: foregroundColor),
              title: Text(title, style: TextStyle(color: foregroundColor)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }
}
