import 'package:flutter/material.dart';
import '/types/net.dart';
import '/utils/app_bar.dart';
import '/utils/page_mixins.dart';
import '/utils/sync_embeded.dart';
import 'bill.dart';
import 'dialog_change_pswd.dart';
import 'dialog_login.dart';
import 'dialog_device_show.dart';
import 'dialog_device_add.dart';

class NetDashboardPage extends StatefulWidget {
  const NetDashboardPage({super.key});

  @override
  State<NetDashboardPage> createState() => _NetDashboardPageState();
}

class _NetDashboardPageState extends State<NetDashboardPage>
    with PageStateMixin, LoadingStateMixin {
  NetUserInfo? _userInfo;
  List<MacDevice>? _macDevices;
  List<MonthlyBill>? _monthlyBills;
  int _selectedYear = DateTime.now().year;

  bool _isLoggingOut = false;
  bool _isLoadingLogin = false;
  bool _isRefreshingDevices = false;
  bool _isLoadingBills = false;
  bool _isRefreshingUser = false;

  bool get _isOnline => serviceProvider.netService.isOnline;

  @override
  void onServiceInit() {
    _refreshData();
  }

  @override
  void onServiceStatusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      if (_isOnline) {
        _refreshData();
      } else {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _monthlyBills = null;
        });
      }
    });
  }

  Future<void> _refreshData() async {
    if (!_isOnline) {
      setState(() {
        _userInfo = null;
        _macDevices = null;
        _monthlyBills = null;
      });
      return;
    }

    setLoading(true);
    try {
      final results = await Future.wait([
        serviceProvider.netService.getUser(),
        serviceProvider.netService.getDeviceList(),
        serviceProvider.netService.getMonthPay(year: _selectedYear),
      ]);
      final info = results[0] as NetUserInfo;
      final macDevices = results[1] as List<MacDevice>;
      final monthlyBills = results[2] as List<MonthlyBill>;
      final sortedBills = List<MonthlyBill>.from(monthlyBills)
        ..sort((a, b) => a.createTime.compareTo(b.createTime));
      if (!mounted) return;
      setState(() {
        _userInfo = info;
        _macDevices = macDevices;
        _monthlyBills = sortedBills;
      });
    } catch (e) {
      if (!mounted) return;
      setError(e.toString());
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _monthlyBills = null;
        });
      }
    } finally {
      if (mounted) {
        setLoading(false);
      }
    }
  }

  Future<void> _refreshUserInfo() async {
    if (!_isOnline) return;
    setState(() => _isRefreshingUser = true);
    try {
      final info = await serviceProvider.netService.getUser();
      if (!mounted) return;
      setState(() => _userInfo = info);
    } catch (e) {
      if (!mounted) return;
      setError('刷新账户信息失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _monthlyBills = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshingUser = false);
    }
  }

  Future<void> _refreshDevices() async {
    if (!_isOnline) return;
    setState(() {
      _isRefreshingDevices = true;
      _macDevices = null;
    });
    try {
      final macDevices = await serviceProvider.netService.getDeviceList();
      if (!mounted) return;
      setState(() => _macDevices = macDevices);
    } catch (e) {
      if (!mounted) return;
      setError('刷新设备列表失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _monthlyBills = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshingDevices = false);
    }
  }

  Future<void> _refreshBills() async {
    if (!_isOnline) return;
    setState(() {
      _isLoadingBills = true;
      _monthlyBills = null;
    });
    try {
      final monthlyBills = await serviceProvider.netService.getMonthPay(
        year: _selectedYear,
      );
      final sortedBills = List<MonthlyBill>.from(monthlyBills)
        ..sort((a, b) => a.createTime.compareTo(b.createTime));
      if (!mounted) return;
      setState(() => _monthlyBills = sortedBills);
    } catch (e) {
      if (!mounted) return;
      setError('刷新月度账单失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _monthlyBills = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingBills = false);
    }
  }

  Future<void> _showLoginDialog() async {
    setState(() => _isLoadingLogin = true);
    try {
      final result = await showDialog<NetUserIntegratedData>(
        context: context,
        builder: (context) => NetLoginDialog(),
      );

      if (result != null) {
        await _refreshData();
      }
    } finally {
      if (mounted) setState(() => _isLoadingLogin = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => NetChangePasswordDialog(),
      );

      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('更改校园网密码成功')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更改校园网密码失败：$e')));
        _refreshUserInfo();
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    setState(() => _isLoggingOut = true);
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认登出'),
          content: const Text(
            '确定要退出校园网自助服务账号吗？'
            '\n\n'
            '这不会影响本机的校园网连接。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await serviceProvider.logoutFromNetService();
          // Clear cached login data
          serviceProvider.storeService.delConfig("net_account_data");
          if (mounted) {
            setState(() {
              _userInfo = null;
              _macDevices = null;
              _monthlyBills = null;
            });
          }
        } catch (e) {
          if (mounted) setError('登出发生错误：$e');
          if (!serviceProvider.netService.isOnline) {
            setState(() {
              _userInfo = null;
              _macDevices = null;
              _monthlyBills = null;
            });
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _handleUnbindMac(MacDevice device) async {
    final normalizedMac = device.mac.toLowerCase();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解绑设备'),
        content: Text(
          '确定要解绑物理地址（MAC 地址）为 ${device.mac.toUpperCase()} 的设备吗？'
          '\n\n'
          '解绑后，该设备需要重新登录校园网。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await serviceProvider.netService.setMacUnbounded(normalizedMac);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('解绑设备成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('解绑设备失败：$e')));
      }
    } finally {
      await _refreshDevices();
    }
  }

  Future<void> _showAddDeviceDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const NetAddDeviceDialog(),
    );

    if (result != null) {
      await _handleAddDevice(result['mac']!, result['name'] ?? '');
    }
  }

  Future<void> _handleAddDevice(String mac, String name) async {
    final macRegex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$|^[0-9A-Fa-f]{12}$',
    );
    if (!macRegex.hasMatch(mac)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MAC 地址格式不正确')));
      }
      return;
    }

    try {
      await serviceProvider.netService.setMacBounded(mac, terminalName: name);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加设备成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加设备失败：$e')));
      }
    } finally {
      await _refreshDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '校园网自助服务'),
      body: SyncPowered(childBuilder: (context) => _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage ?? '未知错误',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: clearError,
                            icon: Icon(
                              Icons.close,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                if (_isOnline && _userInfo != null) ...[
                  _buildUserInfoCard(
                    theme,
                    _userInfo!,
                    onLogout: _showLogoutDialog,
                  ),
                  const SizedBox(height: 16),
                  _buildMacListCard(theme),
                  if (_monthlyBills != null || _isLoadingBills) ...[
                    const SizedBox(height: 16),
                    NetMonthlyBillSection(
                      year: _selectedYear,
                      bills: _monthlyBills ?? [],
                      onYearChanged: (newYear) {
                        if (newYear < 1970 || newYear > DateTime.now().year) {
                          return;
                        }
                        setState(() {
                          _selectedYear = newYear;
                        });
                        _refreshBills();
                      },
                      isLoading: _isLoadingBills,
                    ),
                  ],
                ],

                if (_userInfo == null && (!_isOnline || hasError))
                  _buildLoginPromptCard(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPromptCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_open,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('管理校园网账户', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '登录后，您可以在此查看校园网的账户余额、已绑定的设备和月度账单情况。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoadingLogin ? null : () => _showLoginDialog(),
              icon: _isLoadingLogin
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(
    ThemeData theme,
    NetUserInfo info, {
    required VoidCallback onLogout,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('校园网账户', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: _isRefreshingUser ? null : _refreshUserInfo,
                  icon: _isRefreshingUser
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${info.realName} (${info.accountName})',
                  style: theme.textTheme.headlineSmall,
                  maxLines: 2,
                ),
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  color: theme.colorScheme.error,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: _isLoggingOut ? null : _showLogoutDialog,
                  icon: _isLoggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  theme,
                  icon: Icons.account_balance_wallet,
                  label: '余额',
                  value: '¥${info.moneyLeft.toStringAsFixed(2)}',
                ),
                _buildActionChip(
                  theme,
                  icon: Icons.data_usage,
                  label: '剩余流量',
                  value:
                      '${(info.flowLeft / 1024).toStringAsFixed(2)} GB', // Assuming MB input
                ),
                if (info.plan != null)
                  _buildActionChip(
                    theme,
                    icon: Icons.wifi,
                    label: '套餐',
                    value: info.plan!.planName,
                  ),
                _buildActionChip(
                  theme,
                  icon: Icons.lock,
                  label: '密码',
                  value: '修改密码',
                  onPressed: _isLoggingOut ? null : _showChangePasswordDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onPressed,
  }) {
    if (onPressed != null) {
      return ActionChip(
        avatar: Icon(icon, size: 18),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        onPressed: onPressed,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      );
    }

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    );
  }

  Widget _buildMacListCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.devices_other,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('已绑定设备', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: _isRefreshingDevices ? null : _refreshDevices,
                  icon: _isRefreshingDevices
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_macDevices == null)
              SizedBox(
                height: 80,
                child: Center(
                  child: Text('正在载入设备列表', style: theme.textTheme.bodyMedium),
                ),
              )
            else if (_macDevices!.isEmpty)
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    '未能加载设备列表\n或没有已绑定的设备',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _macDevices!.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = _macDevices![index];
                  return _buildMacListTile(theme, context, device);
                },
              ),
            const SizedBox(height: 16),
            if (_macDevices != null && _macDevices!.length < 5)
              Center(
                child: OutlinedButton.icon(
                  onPressed: _showAddDeviceDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('手动添加设备'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacListTile(
    ThemeData theme,
    BuildContext context,
    MacDevice device,
  ) {
    var displayMac = device.mac.toUpperCase();
    // Add colons if missing for better readability
    if (RegExp(r'^[0-9A-F]{12}$').hasMatch(displayMac)) {
      displayMac = displayMac.replaceAllMapped(
        RegExp(r'.{2}'),
        (match) => '${match.group(0)}:',
      );
      displayMac = displayMac.substring(
        0,
        displayMac.length - 1,
      ); // remove last colon
    }

    final deviceName = device.name.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              size: 22,
              device.isOnline ? Icons.link : Icons.link_off,
              color: device.isOnline
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayMac,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  deviceName.isNotEmpty ? deviceName : '未命名设备',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 20,
            color: theme.colorScheme.primary,
            onPressed: () => showDialog(
              context: context,
              builder: (context) => NetDeviceShowDialog(device: device),
            ),
            icon: const Icon(Icons.info_outline),
            tooltip: '详情',
          ),
          IconButton(
            iconSize: 20,
            color: theme.colorScheme.error,
            onPressed: () => _handleUnbindMac(device),
            icon: const Icon(Icons.delete_outline),
            tooltip: '解绑设备',
          ),
        ],
      ),
    );
  }
}
