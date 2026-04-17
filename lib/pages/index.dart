import 'dart:async';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/utils/page_mixins.dart';
import '/types/courses.dart';
import '/types/preferences.dart';
import '/types/sync.dart';

class _FeatureCardConfig {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  const _FeatureCardConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with PageStateMixin, LoadingStateMixin {
  UserInfo? _userInfo;

  ClassItem? _ongoingClass;
  ClassItem? _upcomingClass;
  CurriculumIntegratedData? _curriculumData;
  Timer? _shortRefreshTimer;
  Timer? _longRefreshTimer;
  int _unreadAnnouncementCount = 0;
  Announcement? _firstUnreadDangerAnnouncement;

  // Feature card configurations
  late final List<_FeatureCardConfig> _courseFeatureCards = [
    _FeatureCardConfig(
      title: '选课',
      description: '查看和管理课程',
      icon: Icons.school,
      color: Colors.blue,
      route: '/courses/selection',
    ),
    _FeatureCardConfig(
      title: '考试',
      description: '查看考试时间和地点',
      icon: Icons.assignment,
      color: Colors.orangeAccent,
      route: '/courses/exam',
    ),
    _FeatureCardConfig(
      title: '成绩',
      description: '查看考试成绩',
      icon: Icons.assessment,
      color: Colors.orange,
      route: '/courses/grade',
    ),
  ];

  late final List<_FeatureCardConfig> _netFeatureCards = [
    _FeatureCardConfig(
      title: '流量监视',
      description: '实时监控网络流量',
      icon: Icons.swap_vert,
      color: Colors.green,
      route: '/net/monitor',
    ),
    _FeatureCardConfig(
      title: '自助服务',
      description: '账户管理和账单查询',
      icon: Icons.wifi,
      color: Colors.teal,
      route: '/net/dashboard',
    ),
    _FeatureCardConfig(
      title: '流量查询',
      description: '查看流量与费用明细',
      icon: Icons.receipt_long,
      color: Colors.cyan,
      route: '/net/traffic',
    ),
  ];

  @override
  void onServiceInit() {
    _loadUserInfo();
    _loadCurriculumData();
    _loadUnreadAnnouncementsCount();
    _startTimers();
  }

  @override
  void onServiceStatusChanged() {
    // Schedule the state update for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
        _loadUserInfo();
        _loadCurriculumData();
        _loadUnreadAnnouncementsCount();
      }
    });
  }

  @override
  void dispose() {
    _shortRefreshTimer?.cancel();
    _longRefreshTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _shortRefreshTimer?.cancel();
    _shortRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadCurriculumData();
      }
    });

    _longRefreshTimer?.cancel();
    _longRefreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (mounted) {
        _loadUnreadAnnouncementsCount();
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final service = serviceProvider.coursesService;

    if (!service.isOnline) {
      if (mounted) {
        setState(() {
          _userInfo = null;
        });
      }
      return;
    }

    try {
      final userInfo = await serviceProvider.coursesService.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userInfo = null;
        });
      }
    }
  }

  Future<void> _loadCurriculumData() async {
    try {
      final curriculumData = await serviceProvider.getCurriculumData();

      if (mounted) {
        final newOngoingClass = curriculumData?.getClassOngoing();
        final newUpcomingClass = curriculumData?.getClassUpcoming();

        if (_ongoingClass != newOngoingClass ||
            _upcomingClass != newUpcomingClass ||
            _curriculumData != curriculumData) {
          setState(() {
            _curriculumData = curriculumData;
            _ongoingClass = newOngoingClass;
            _upcomingClass = newUpcomingClass;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _curriculumData = null;
          _ongoingClass = null;
          _upcomingClass = null;
        });
      }
    }
  }

  Future<void> _loadUnreadAnnouncementsCount() async {
    try {
      final announcements = await serviceProvider.syncService
          .getAnnouncements();
      final store = serviceProvider.storeService;
      var readMap =
          store.getConfig<AnnouncementReadMap>(
            'announcement_read',
            AnnouncementReadMap.fromJson,
          ) ??
          AnnouncementReadMap.defaultMap;

      int count = 0;
      Announcement? firstUnreadDanger;

      for (final announcement in announcements) {
        final key = announcement.calculateKey();
        if (!readMap.readTimestamp.containsKey(key)) {
          count++;

          // Find the first unread DANGER announcement
          if (firstUnreadDanger == null &&
              announcement.group.toLowerCase() == 'danger') {
            firstUnreadDanger = announcement;
          }
        }
      }

      if (mounted) {
        setState(() {
          _unreadAnnouncementCount = count;
          _firstUnreadDangerAnnouncement = firstUnreadDanger;
        });
      }
    } catch (e) {
      // Ignore errors for background check
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '欢迎来到大贝壳~',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _buildAnnouncementButton(),
                ),
              ],
            ),
            if (_firstUnreadDangerAnnouncement != null)
              _buildDangerAnnouncementCallout()
            else ...[
              const SizedBox(height: 8),
              Text(
                '北京科技大学校园助手',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 32),
            _buildFeatureGrid(),
            const SizedBox(height: 32),
            _buildNetFeatureGrid(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () async {
            await context.router.pushPath('/more/anno');
            // Refresh count when returning from announcement page
            _loadUnreadAnnouncementsCount();
          },
          icon: const Icon(Icons.notifications_outlined),
          tooltip: '公告',
        ),
        if (_unreadAnnouncementCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadAnnouncementCount > 9
                    ? '9+'
                    : _unreadAnnouncementCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDangerAnnouncementCallout() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main callout card
          GestureDetector(
            onTap: () async {
              await context.router.pushPath('/more/anno');
              // Refresh count when returning from announcement page
              _loadUnreadAnnouncementsCount();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _firstUnreadDangerAnnouncement!.title,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.red,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          // Arrow pointing to top-right
          Positioned(
            right: 16,
            top: -8,
            child: CustomPaint(
              size: const Size(16, 8),
              painter: _ArrowPainter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrowScreen = constraints.maxWidth < 600;
        final theme = Theme.of(context);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '教务',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "本研一体教务管理系统",
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              if (isNarrowScreen) ...[
                _buildNarrowLayout(),
              ] else ...[
                _buildWideLayout(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        SizedBox(
          height: (_ongoingClass != null || _upcomingClass != null) ? 200 : 140,
          child: _buildCurriculumCard(context, isWideScreen: false),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 100, child: _buildAccountCard(context)),
        ..._courseFeatureCards.map((card) {
          return Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: _buildFeatureCard(
                  context,
                  card.title,
                  card.description,
                  card.icon,
                  card.color,
                  () => context.router.pushPath(card.route),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: _buildCurriculumCard(context, isWideScreen: true),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: _buildCardRow([
            _buildAccountCard(context),
            _courseFeatureCards[0],
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: _buildCardRow([
            _courseFeatureCards[1],
            _courseFeatureCards[2],
          ]),
        ),
      ],
    );
  }

  Widget _buildCardRow(List<dynamic> items) {
    return Row(
      children: items.asMap().entries.expand((entry) {
        final index = entry.key;
        final item = entry.value;
        return [
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: item is Widget
                ? item
                : _buildFeatureCard(
                    context,
                    item.title,
                    item.description,
                    item.icon,
                    item.color,
                    () => context.router.pushPath(item.route),
                  ),
          ),
        ];
      }).toList(),
    );
  }

  Widget _buildCurriculumCard(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.router.pushPath('/courses/curriculum'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.8),
                primaryColor,
                primaryColor.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildCurriculumContent(isWideScreen: isWideScreen),
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumContent({required bool isWideScreen}) {
    if (isWideScreen) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 36, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '课表',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '查看每周课程安排',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (_ongoingClass != null || _upcomingClass != null) ...[
            const SizedBox(width: 16),
            Container(
              constraints: BoxConstraints(maxWidth: 290),
              child: _buildMultipleClassPreviews(),
            ),
          ],
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '课表',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_ongoingClass != null || _upcomingClass != null) ...[
            const SizedBox(height: 16),
            _buildMultipleClassPreviews(),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              '查看每周课程安排',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildMultipleClassPreviews() {
    final classes = <ClassItem?>[];
    if (_ongoingClass != null) classes.add(_ongoingClass);
    if (_upcomingClass != null) classes.add(_upcomingClass);

    return SizedBox(
      height: 105,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final classItem = classes[index]!;
          final isOngoing = classItem == _ongoingClass;
          return _buildSingleClassPreview(classItem, isOngoing);
        },
      ),
    );
  }

  Widget _buildSingleClassPreview(ClassItem classItem, bool isOngoing) {
    final startTime = classItem.getMinStartTime(
      _curriculumData?.allPeriods ?? [],
    );
    final endTime = classItem.getMaxEndTime(_curriculumData?.allPeriods ?? []);
    String? periodTimeRange = startTime != null && endTime != null
        ? '${startTime.format(context)} - ${endTime.format(context)}'
        : null;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOngoing ? '进行中' : '接下来',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classItem.className,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          if (periodTimeRange != null)
            Text(
              periodTimeRange,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          Text(
            classItem.locationName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetFeatureGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrowScreen = constraints.maxWidth < 600;
        final theme = Theme.of(context);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '校园网',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "校园网自助服务与流量监控",
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              if (isNarrowScreen) ...[
                _buildNetNarrowLayout(),
              ] else ...[
                _buildNetWideLayout(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetNarrowLayout() {
    return Column(
      children: _netFeatureCards.asMap().entries.expand((entry) {
        final index = entry.key;
        final card = entry.value;
        return [
          if (index > 0) const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: _buildFeatureCard(
              context,
              card.title,
              card.description,
              card.icon,
              card.color,
              () => context.router.pushPath(card.route),
            ),
          ),
        ];
      }).toList(),
    );
  }

  Widget _buildNetWideLayout() {
    return SizedBox(height: 120, child: _buildCardRow(_netFeatureCards));
  }

  Widget _buildAccountCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.router.pushPath('/courses/account'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_circle, size: 32, color: Colors.lightBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '教务账户',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final service = serviceProvider.coursesService;

                  if (service.isOnline && _userInfo != null) {
                    return Text(
                      '已作为${_userInfo!.userName}登录',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  } else if (service.isPending) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('处理中', style: TextStyle(fontSize: 14)),
                      ],
                    );
                  } else if (service.hasError) {
                    return Text(
                      '教务账户登录失败',
                      style: TextStyle(fontSize: 14, color: Colors.red[700]),
                    );
                  } else {
                    return Text(
                      '尚未登录教务账户',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for the upward-pointing arrow
class _ArrowPainter extends CustomPainter {
  final Color color;

  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Create an upward-pointing triangle
    path.moveTo(size.width / 2, 0); // Top point
    path.lineTo(0, size.height); // Bottom left
    path.lineTo(size.width, size.height); // Bottom right
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
