// Copyright (c) 2025, Harry Huang

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'utils/app_bar.dart';
import 'utils/back_handle.dart';
import 'pages/index.dart';
import 'pages/courses/selection/index.dart';
import 'pages/courses/curriculum/index.dart';
import 'pages/courses/exam/index.dart';
import 'pages/courses/grade/index.dart';
import 'pages/courses/account/index.dart';
import 'pages/net/dashboard/index.dart';
import 'pages/net/monitor/index.dart';
import 'pages/sync/index.dart';
import 'pages/more/anno.dart';
import 'pages/more/settings.dart';
import 'pages/more/update.dart';

// App constants
class _AppConstants {
  static const double wideScreenBreakpoint = 768.0;
  static const double sideNavigationWidth = 240.0;
  static const String appName = '大贝壳';
  static const IconData appIcon = Icons.waves;

  static const List<_NavigationItem> navigationItems = [
    _NavigationItem(icon: Icons.home, title: '主页', path: '/'),
    _NavigationItem(
      icon: Icons.account_circle,
      title: '教务账户',
      path: '/courses/account',
      category: '教务',
    ),
    _NavigationItem(
      icon: Icons.calendar_today,
      title: '课表',
      path: '/courses/curriculum',
      category: '教务',
    ),
    _NavigationItem(
      icon: Icons.school,
      title: '选课',
      path: '/courses/selection',
      category: '教务',
    ),
    _NavigationItem(
      icon: Icons.assignment,
      title: '考试',
      path: '/courses/exam',
      category: '教务',
    ),
    _NavigationItem(
      icon: Icons.assessment,
      title: '成绩',
      path: '/courses/grade',
      category: '教务',
    ),
    _NavigationItem(
      icon: Icons.swap_vert,
      title: '流量监视',
      path: '/net/monitor',
      category: '校园网',
    ),
    _NavigationItem(
      icon: Icons.wifi,
      title: '自助服务',
      path: '/net/dashboard',
      category: '校园网',
    ),
    _NavigationItem(
      icon: Icons.sync,
      title: '跨设备同步',
      path: '/sync',
      category: '同步',
    ),
  ];
}

class _NavigationItem {
  final IconData icon;
  final String title;
  final String path;
  final String? category;

  const _NavigationItem({
    required this.icon,
    required this.title,
    required this.path,
    this.category,
  });
}

// App router definition with auto_route package
// See: https://github.com/Milad-Akarie/auto_route_library
class AppRouter {
  static final router = RootStackRouter.build(
    routes: [
      NamedRouteDef(
        name: 'HomeRoute',
        path: '/',
        builder: (context, data) => const MainLayout(child: HomePage()),
      ),
      NamedRouteDef(
        name: 'CourseAccountRoute',
        path: '/courses/account',
        builder: (context, data) => const MainLayout(child: AccountPage()),
      ),
      NamedRouteDef(
        name: 'CurriculumRoute',
        path: '/courses/curriculum',
        builder: (context, data) => const MainLayout(child: CurriculumPage()),
      ),
      NamedRouteDef(
        name: 'CourseSelectionRoute',
        path: '/courses/selection',
        builder: (context, data) =>
            const MainLayout(child: CourseSelectionPage()),
      ),
      NamedRouteDef(
        name: 'ExamRoute',
        path: '/courses/exam',
        builder: (context, data) => const MainLayout(child: ExamPage()),
      ),
      NamedRouteDef(
        name: 'GradeRoute',
        path: '/courses/grade',
        builder: (context, data) => const MainLayout(child: GradePage()),
      ),
      NamedRouteDef(
        name: 'NetMonitorRoute',
        path: '/net/monitor',
        builder: (context, data) => const MainLayout(child: NetMonitorPage()),
      ),
      NamedRouteDef(
        name: 'NetDashboardRoute',
        path: '/net/dashboard',
        builder: (context, data) => const MainLayout(child: NetDashboardPage()),
      ),
      NamedRouteDef(
        name: 'SettingsRoute',
        path: '/more/settings',
        builder: (context, data) => const MainLayout(child: SettingsPage()),
      ),
      NamedRouteDef(
        name: 'SyncRoute',
        path: '/sync',
        builder: (context, data) => const MainLayout(child: SyncPage()),
      ),
      NamedRouteDef(
        name: 'AnnouncementRoute',
        path: '/more/anno',
        builder: (context, data) => const MainLayout(child: AnnouncementPage()),
      ),
      NamedRouteDef(
        name: 'UpdateRoute',
        path: '/more/update',
        builder: (context, data) => const MainLayout(child: UpdatePage()),
      ),
    ],
  );
}

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isWideScreen = false;
  Widget? _cachedChild;

  // GlobalKey to maintain page state during screen size transitions
  // Using an instance key instead of a static map prevents duplicate key errors
  // when the same page is pushed multiple times in the navigation stack.
  final GlobalKey _contentKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final newIsWideScreen = size.width > _AppConstants.wideScreenBreakpoint;
    if (_isWideScreen != newIsWideScreen) {
      setState(() {
        _isWideScreen = newIsWideScreen;
      });
    }
  }

  String get _currentPath {
    if (context.mounted) {
      final routeData = context.routeData;
      return routeData.path;
    }
    return '/';
  }

  void _navigateToPage(String path) {
    if (context.mounted && _currentPath != path) {
      if (_isWideScreen) {
        context.router.replacePath('/');
        context.router.pushPath(path);
      } else {
        context.router.pushPath(path);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _cachedChild ??= widget.child;

    Widget content;
    if (_isWideScreen) {
      content = Scaffold(
        body: Row(
          children: [
            _SideNavigation(
              isDrawer: false,
              currentPath: _currentPath,
              onNavigate: _navigateToPage,
            ),
            Expanded(
              child: KeyedSubtree(key: _contentKey, child: _cachedChild!),
            ),
          ],
        ),
      );
    } else {
      content = Scaffold(
        appBar: const TopAppBar(),
        drawer: Drawer(
          child: _SideNavigation(
            isDrawer: true,
            currentPath: _currentPath,
            onNavigate: _navigateToPage,
          ),
        ),
        body: KeyedSubtree(key: _contentKey, child: _cachedChild!),
      );
    }

    return _currentPath == '/'
        ? DoubleBackToExitWrapper(child: content)
        : CommonPopWrapper(child: content);
  }
}

class _SideNavigation extends StatefulWidget {
  final bool isDrawer;
  final String currentPath;
  final void Function(String path) onNavigate;

  const _SideNavigation({
    required this.isDrawer,
    required this.currentPath,
    required this.onNavigate,
  });

  @override
  State<_SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<_SideNavigation> {
  late final PageController _pageController;
  late bool _showMore;

  static const Set<String> _initiallyShowMorePaths = {
    '/more/anno',
    '/more/update',
    '/more/settings',
  };

  @override
  void initState() {
    super.initState();
    _showMore = _initiallyShowMorePaths.contains(widget.currentPath);
    _pageController = PageController(initialPage: _showMore ? 1 : 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeItem = _AppConstants.navigationItems[0];
    final mainItems = _AppConstants.navigationItems.sublist(1);

    return Container(
      width: widget.isDrawer ? null : _AppConstants.sideNavigationWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: widget.isDrawer
            ? null
            : Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          // Banner
          if (!widget.isDrawer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              child: Row(
                children: [
                  Icon(
                    _AppConstants.appIcon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    _AppConstants.appName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                border: Border(bottom: BorderSide.none),
              ),
              child: Row(
                children: [
                  Icon(
                    _AppConstants.appIcon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    _AppConstants.appName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Navigation item
          _buildNavItem(
            context: context,
            icon: homeItem.icon,
            title: homeItem.title,
            isSelected: widget.currentPath == homeItem.path,
            onTap: () => widget.onNavigate(homeItem.path),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListView(children: _buildNavItems(context, mainItems)),
                ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildNavItem(
                      context: context,
                      icon: Icons.campaign,
                      title: '公告',
                      isSelected: widget.currentPath == '/more/anno',
                      onTap: () => widget.onNavigate('/more/anno'),
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.cloud_download_outlined,
                      title: '更新',
                      isSelected: widget.currentPath == '/more/update',
                      onTap: () => widget.onNavigate('/more/update'),
                    ),
                    _buildNavItem(
                      context: context,
                      icon: Icons.settings,
                      title: '设置',
                      isSelected: widget.currentPath == '/more/settings',
                      onTap: () => widget.onNavigate('/more/settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          _buildNavItem(
            context: context,
            icon: _showMore ? Icons.arrow_back : Icons.more_horiz,
            title: _showMore ? '收起' : '更多',
            isSelected: false,
            onTap: () {
              setState(() {
                _showMore = !_showMore;
              });
              _pageController.animateToPage(
                _showMore ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(
    BuildContext context,
    List<_NavigationItem> items,
  ) {
    final Map<String?, List<_NavigationItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final groupedItems = grouped;
    final widgets = <Widget>[];

    for (final entry in groupedItems.entries) {
      final category = entry.key;
      final categoryItems = entry.value;

      if (category != null) {
        widgets.addAll([
          if (widgets.isNotEmpty) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
        ]);
      }

      for (final item in categoryItems) {
        widgets.add(
          _buildNavItem(
            context: context,
            icon: item.icon,
            title: item.title,
            isSelected: widget.currentPath == item.path,
            onTap: () => widget.onNavigate(item.path),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }
}
