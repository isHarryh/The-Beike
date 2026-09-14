// Copyright (c) 2025, Harry Huang

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'utils/app_bar.dart';
import 'utils/back_handle.dart';
import 'utils/side_navigation.dart';
import 'pages/index.dart';
import 'pages/courses/selection/index.dart';
import 'pages/courses/curriculum/index.dart';
import 'pages/courses/exam/index.dart';
import 'pages/courses/grade/index.dart';
import 'pages/courses/account/index.dart';
import 'pages/net/dashboard/index.dart';
import 'pages/net/traffic/index.dart';
import 'pages/payment/index.dart';
import 'pages/sync/index.dart';
import 'pages/more/anno.dart';
import 'pages/more/settings.dart';
import 'pages/more/update.dart';

// App router definition with auto_route package
// See: https://github.com/Milad-Akarie/auto_route_library
class AppRouter {
  static final router = RootStackRouter.build(
    routes: [
      // The single application shell. It hosts the side navigation and
      // renders every page inside its nested router, so switching pages
      // never rebuilds the shell itself.
      NamedRouteDef(
        name: 'MainLayoutRoute',
        path: '/',
        builder: (context, data) => const MainLayout(),
        children: [
          NamedRouteDef(
            name: 'HomeRoute',
            path: '',
            builder: (context, data) =>
                const DoubleBackToExitWrapper(child: HomePage()),
          ),
          NamedRouteDef(
            name: 'CourseAccountRoute',
            path: 'courses/account',
            builder: (context, data) =>
                const CommonPopWrapper(child: AccountPage()),
          ),
          NamedRouteDef(
            name: 'CurriculumRoute',
            path: 'courses/curriculum',
            builder: (context, data) =>
                const CommonPopWrapper(child: CurriculumPage()),
          ),
          NamedRouteDef(
            name: 'CourseSelectionRoute',
            path: 'courses/selection',
            builder: (context, data) =>
                const CommonPopWrapper(child: CourseSelectionPage()),
          ),
          NamedRouteDef(
            name: 'ExamRoute',
            path: 'courses/exam',
            builder: (context, data) =>
                const CommonPopWrapper(child: ExamPage()),
          ),
          NamedRouteDef(
            name: 'GradeRoute',
            path: 'courses/grade',
            builder: (context, data) =>
                const CommonPopWrapper(child: GradePage()),
          ),
          NamedRouteDef(
            name: 'NetDashboardRoute',
            path: 'net/dashboard',
            builder: (context, data) =>
                const CommonPopWrapper(child: NetDashboardPage()),
          ),
          NamedRouteDef(
            name: 'NetTrafficRoute',
            path: 'net/traffic',
            builder: (context, data) =>
                const CommonPopWrapper(child: NetTrafficPage()),
          ),
          NamedRouteDef(
            name: 'PaymentRoute',
            path: 'payment',
            builder: (context, data) =>
                const CommonPopWrapper(child: PaymentPage()),
          ),
          NamedRouteDef(
            name: 'SyncRoute',
            path: 'sync',
            builder: (context, data) =>
                const CommonPopWrapper(child: SyncPage()),
          ),
          NamedRouteDef(
            name: 'AnnouncementRoute',
            path: 'more/anno',
            builder: (context, data) =>
                const CommonPopWrapper(child: AnnouncementPage()),
          ),
          NamedRouteDef(
            name: 'UpdateRoute',
            path: 'more/update',
            builder: (context, data) =>
                const CommonPopWrapper(child: UpdatePage()),
          ),
          NamedRouteDef(
            name: 'SettingsRoute',
            path: 'more/settings',
            builder: (context, data) =>
                const CommonPopWrapper(child: SettingsPage()),
          ),
        ],
      ),
    ],
  );
}

/// The application shell that combines [SideNavigation] with the nested
/// router rendering the active page.
class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      builder: (context, content) => _MainLayoutBody(content: content),
    );
  }
}

class _MainLayoutBody extends StatefulWidget {
  final Widget content;

  const _MainLayoutBody({required this.content});

  @override
  State<_MainLayoutBody> createState() => _MainLayoutBodyState();
}

class _MainLayoutBodyState extends State<_MainLayoutBody> {
  static const double _wideScreenBreakpoint = 768.0;

  bool _isWideScreen = false;

  // GlobalKey to maintain the nested router state during screen size changes
  final GlobalKey _contentKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final newIsWideScreen = size.width > _wideScreenBreakpoint;
    if (_isWideScreen != newIsWideScreen) {
      setState(() {
        _isWideScreen = newIsWideScreen;
      });
    }
  }

  /// Converts the router's relative path (e.g. `sync`) to the app path
  /// (e.g. `/sync`). The home path is an empty string in the router.
  static String _toAppPath(String routerPath) {
    final trimmed = routerPath.replaceFirst(RegExp(r'^/+'), '');
    return trimmed.isEmpty ? '/' : '/$trimmed';
  }

  void _navigateToPage(String path) {
    final router = AutoRouter.of(context);
    if (_toAppPath(router.topRoute.path) == path) {
      return;
    }
    final relativePath = path.replaceFirst(RegExp(r'^/+'), '');
    router.navigatePath(relativePath);
    if (!_isWideScreen) {
      // Close the drawer.
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watches the nested router so that the layout is rebuilt on navigation.
    final router = AutoRouter.of(context, watch: true);
    final currentPath = _toAppPath(router.topRoute.path);
    final content = KeyedSubtree(key: _contentKey, child: widget.content);

    if (_isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            SideNavigation(
              isDrawer: false,
              currentPath: currentPath,
              onNavigate: _navigateToPage,
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: const TopAppBar(),
      drawer: Drawer(
        child: SideNavigation(
          isDrawer: true,
          currentPath: currentPath,
          onNavigate: _navigateToPage,
        ),
      ),
      body: content,
    );
  }
}
