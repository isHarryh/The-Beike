import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/services/base.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';
import '/utils/sync_embeded.dart';
import 'ustb_byyt_cookie.dart';
import 'ustb_byyt_sso.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  UserInfo? _userInfo;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showLoginButton = true;
  String? _currentLoginMethod;
  String? _currentLoginCookie;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);

    // Check current service status and load user info if already online
    final service = _serviceProvider.coursesService;
    _showLoginButton = !service.isOnline;

    if (service.isOnline && _userInfo == null) {
      _loadUserInfoSilently();
    }
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (mounted) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final service = _serviceProvider.coursesService;
          setState(() {
            if (service.isOnline) {
              _showLoginButton = false;
            } else if (service.isOffline || service.hasError) {
              _showLoginButton = true;
            }
            // else: pending
          });

          // Load user info asynchronously after state update
          _loadUserInfoIfOnlineSilently();
        }
      });
    }
  }

  void _writeLoginDataToCache() {
    final method = _currentLoginMethod;
    final cookie = _currentLoginCookie;
    if (method == null) return;

    final existingData = _serviceProvider.storeService
        .getConfig<UserLoginIntegratedData>(
          "course_account_data",
          UserLoginIntegratedData.fromJson,
        );

    final updatedData = UserLoginIntegratedData(
      user: _userInfo,
      method: method,
      cookie: cookie,
      lastSmsPhone: existingData?.lastSmsPhone,
    );

    _serviceProvider.storeService.putConfig<UserLoginIntegratedData>(
      "course_account_data",
      updatedData,
    );

    // Clear after writing
    _currentLoginMethod = null;
    _currentLoginCookie = null;
  }

  Future<void> _loadUserInfoIfOnlineSilently() async {
    final service = _serviceProvider.coursesService;

    if (service.isOnline) {
      await _loadUserInfoSilently();
    } else {
      if (mounted) {
        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _userInfo = null;
              _errorMessage = null;
            });
          }
        });
      }
    }
  }

  Future<void> _loadUserInfoSilently() async {
    try {
      final userInfo = await _serviceProvider.coursesService.getUserInfo();

      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _errorMessage = null;
        });

        // Write login data to cache after user info is loaded
        _writeLoginDataToCache();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认登出'),
          content: const Text('是否确认登出此账户？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      await _serviceProvider.coursesService.logout();

      // Clear user cache data but preserve lastSmsPhone
      final existingData = _serviceProvider.storeService
          .getConfig<UserLoginIntegratedData>(
            "course_account_data",
            UserLoginIntegratedData.fromJson,
          );

      if (existingData != null && existingData.lastSmsPhone != null) {
        // Preserve only the lastSmsPhone
        final preservedData = UserLoginIntegratedData(
          user: null,
          method: null,
          cookie: null,
          lastSmsPhone: existingData.lastSmsPhone,
        );
        _serviceProvider.storeService.putConfig<UserLoginIntegratedData>(
          "course_account_data",
          preservedData,
        );
      } else {
        // No existing data or no lastSmsPhone, remove cache completely
        _serviceProvider.storeService.delConfig("course_account_data");
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _userInfo = null;
          _currentLoginMethod = null;
          _currentLoginCookie = null;
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

  String _getStatusText() {
    final service = _serviceProvider.coursesService;
    switch (service.status) {
      case ServiceStatus.online:
        return '已登录';
      case ServiceStatus.offline:
        return '未登录';
      case ServiceStatus.pending:
        return '处理中';
      case ServiceStatus.error:
        if (service.errorMessage != null &&
            service.errorMessage!.contains('HTTP 302')) {
          // Special case: 302 redirect often indicates session expired
          return '登录可能已过期';
        }
        return '错误';
    }
  }

  Color _getStatusColor() {
    final service = _serviceProvider.coursesService;
    switch (service.status) {
      case ServiceStatus.online:
        return Colors.green;
      case ServiceStatus.offline:
        return Colors.grey;
      case ServiceStatus.pending:
        return Colors.blue;
      case ServiceStatus.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '教务账户'),
      body: SyncPowered(
        onSyncEnd: _loadUserInfoSilently,
        childBuilder: (context) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final service = _serviceProvider.coursesService;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card with login/logout button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    service.isOnline ? Icons.check_circle : Icons.error_outline,
                    color: _getStatusColor(),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本机登录状态',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (service.errorMessage != null)
                          Text(
                            service.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        if (service.isOnline)
                          Text(
                            _getLastHeartbeatText()!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Logout button (only show when logged in)
                  if (!_showLoginButton)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleLogout,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_isLoading ? '请稍后' : '登出'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Login methods section (only show when not logged in)
          if (_showLoginButton) ...[
            Text('登录方式', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // Login methods list
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.security,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    title: const Text('统一身份认证登录'),
                    subtitle: const Text('推荐方式，使用USTB SSO系统安全便捷登录'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showSsoLoginDialog(
                        context,
                        onLoginSuccess: (method, cookie) {
                          _currentLoginMethod = method;
                          _currentLoginCookie = cookie;
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.cookie_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 32,
                    ),
                    title: const Text('使用Cookie登录账户'),
                    subtitle: const Text('适用于高级用户，需要手动提供Cookie'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showCookieLoginDialog(
                        context,
                        onLoginSuccess: (method, cookie) {
                          _currentLoginMethod = method;
                          _currentLoginCookie = cookie;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          // User information section
          if (service.isOnline && _userInfo != null) ...[
            Text('个人信息', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar and name
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            _userInfo!.userName.isNotEmpty
                                ? _userInfo!.userName[0]
                                : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userInfo!.userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_userInfo!.userNameAlt.isNotEmpty)
                                Text(
                                  _userInfo!.userNameAlt,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // User ID
                    _buildDetailRow('学号', _userInfo!.userId, null),
                    const SizedBox(height: 12),
                    // School information
                    _buildDetailRow(
                      '学院',
                      _userInfo!.userSchool,
                      _userInfo!.userSchoolAlt.isNotEmpty
                          ? _userInfo!.userSchoolAlt
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (service.isOnline && _userInfo == null && !_isLoading) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('暂无用户信息')),
              ),
            ),
          ],
          // On error
          if (_errorMessage != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '错误信息',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String? altValue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              if (altValue != null)
                Text(
                  altValue,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _getLastHeartbeatText() {
    final service = _serviceProvider.coursesService;
    final lastHeartbeat = service.getLastHeartbeatTime();

    if (lastHeartbeat == null) {
      return '上次心跳: 暂无';
    }

    // yyyy-MM-dd hh:mm
    final year = lastHeartbeat.year.toString();
    final month = lastHeartbeat.month.toString().padLeft(2, '0');
    final day = lastHeartbeat.day.toString().padLeft(2, '0');
    final hour = lastHeartbeat.hour.toString().padLeft(2, '0');
    final minute = lastHeartbeat.minute.toString().padLeft(2, '0');

    return '上次心跳：$year-$month-$day $hour:$minute';
  }
}
