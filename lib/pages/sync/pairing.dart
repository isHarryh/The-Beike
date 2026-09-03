import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/services/provider.dart';
import '/types/sync.dart';
import '/types/courses.dart';

class SyncPairingCard extends StatefulWidget {
  final ServiceProvider serviceProvider;
  final ValueChanged<SyncDeviceData> onSyncDataChanged;
  final VoidCallback onSuccess;
  final ValueChanged<dynamic> onError;

  const SyncPairingCard({
    super.key,
    required this.serviceProvider,
    required this.onSyncDataChanged,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<SyncPairingCard> createState() => _SyncPairingCardState();
}

class _SyncPairingCardState extends State<SyncPairingCard> {
  bool _isLoading = false;

  String? _pairCode;
  DateTime? _pairCodeExpiry;
  List<DeviceInfo>? _devices;

  bool _showJoinInput = false;
  final TextEditingController _joinCodeController = TextEditingController();

  SyncDeviceData? _syncData;

  // Device list refresh management
  Timer? _refreshTimer;

  // Track if pairing was manually closed
  String? _lastClosedPairCode;

  @override
  void initState() {
    super.initState();
    _initializeDevice();
  }

  @override
  void didUpdateWidget(SyncPairingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeDevice();
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeDevice() async {
    final cache = widget.serviceProvider.storeService.getPref<SyncDeviceData>(
      'sync_device',
      SyncDeviceData.fromJson,
    );

    // Check if group state changed
    final oldGroupId = _syncData?.groupId;
    final newGroupId = cache?.groupId;
    final groupChanged = oldGroupId != newGroupId;

    if (mounted) {
      setState(() {
        _syncData = cache;
        // If group was reset or changed, clear pairing-related state
        if (groupChanged && newGroupId == null) {
          _pairCode = null;
          _pairCodeExpiry = null;
          _devices = null;
          _showJoinInput = false;
          _joinCodeController.clear();
          _lastClosedPairCode = null;
          _refreshTimer?.cancel();
        }
      });
    }

    if (_syncData?.groupId != null) {
      // First time refresh
      await _refreshDeviceList();
      // Start periodic refresh
      _startPeriodicRefresh();
    }
  }

  String _getDeviceOsIcon(String os) {
    switch (os.toLowerCase()) {
      case 'windows':
        return '🪟';
      case 'mac':
        return '🍎';
      case 'linux':
        return '🐧';
      case 'ios':
        return '📱';
      case 'android':
        return '🤖';
      default:
        return '💻';
    }
  }

  Future<void> _saveSyncData(SyncDeviceData data) async {
    widget.serviceProvider.storeService.putPref<SyncDeviceData>(
      'sync_device',
      data,
    );

    if (mounted) {
      setState(() => _syncData = data);
    }
    widget.onSyncDataChanged(data);
  }

  Future<void> _refreshDeviceList() async {
    if (_syncData?.groupId == null) return;
    if (kDebugMode) {
      print('Refreshing device list...');
    }

    try {
      final devices = await widget.serviceProvider.syncService.listDevices(
        groupId: _syncData!.groupId!,
        deviceId: _syncData!.deviceId,
      );

      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    } catch (e) {
      // Silent failure for polling
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();

    // Determine refresh interval based on pairing status
    final interval = _pairCode != null
        ? const Duration(seconds: 2) // During pairing: 2s
        : const Duration(seconds: 10); // Normal: 10s

    _refreshTimer = Timer.periodic(interval, (timer) async {
      if (!mounted || _syncData?.groupId == null) {
        timer.cancel();
        return;
      }
      await _refreshDeviceList();
    });
  }

  Future<void> _createGroup() async {
    String? byytCookie;

    try {
      final courseData = widget.serviceProvider.storeService.getConfig(
        'course_account_data',
        (json) => UserLoginIntegratedData.fromJson(json),
      );
      byytCookie = courseData?.cookie;
    } catch (e) {
      // Ignore error if cache not found
    }

    if (byytCookie == null || byytCookie.isEmpty) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要验证'),
          content: const Text('为了保证信息安全，创建同步组之前需要先登录教务账户，是否立即登录？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('前往登录'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        context.router.pushPath('/courses/account');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final groupId = await widget.serviceProvider.syncService.createGroup(
        deviceId: _syncData!.deviceId!,
        byytCookie: byytCookie,
      );

      await _saveSyncData(_syncData!.copyWith(groupId: groupId));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('同步组创建成功')));
      }
      widget.onSuccess();

      await _refreshDeviceList();

      await _openPairing();
    } catch (e) {
      widget.onError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openPairing() async {
    try {
      // If user manually closed pairing before, close it on server side
      if (_lastClosedPairCode != null) {
        try {
          await widget.serviceProvider.syncService.closePairing(
            pairCode: _lastClosedPairCode!,
            groupId: _syncData!.groupId!,
          );
        } catch (e) {
          // Silently ignore errors from closePairing
        }
        _lastClosedPairCode = null;
      }

      final pairingInfo = await widget.serviceProvider.syncService.openPairing(
        deviceId: _syncData!.deviceId!,
        groupId: _syncData!.groupId!,
      );

      if (mounted) {
        setState(() {
          _pairCode = pairingInfo.pairCode;
          _pairCodeExpiry = DateTime.now().add(
            Duration(seconds: pairingInfo.ttl),
          );
        });
        // Switch to fast refresh mode
        _startPeriodicRefresh();
        _startPairCodeExpiryPolling();
        widget.onSuccess();
      }
    } catch (e) {
      widget.onError(e);
    }
  }

  void _startPairCodeExpiryPolling() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _pairCode == null) return;

      if (_pairCodeExpiry != null && DateTime.now().isAfter(_pairCodeExpiry!)) {
        if (mounted) {
          setState(() {
            _pairCode = null;
            _pairCodeExpiry = null;
            _lastClosedPairCode = null;
          });
          // Switch back to normal refresh mode
          _startPeriodicRefresh();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('配对码已过期')));
        }
        return;
      }

      _startPairCodeExpiryPolling();
    });
  }

  void _toggleJoinInput() {
    setState(() {
      _showJoinInput = !_showJoinInput;
      if (!_showJoinInput) {
        _joinCodeController.clear();
      }
    });
  }

  Future<void> _joinGroup() async {
    final pairCode = _joinCodeController.text.trim();

    if (pairCode.isEmpty) {
      widget.onError('请输入配对码');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.serviceProvider.syncService.joinGroup(
        deviceId: _syncData!.deviceId!,
        pairCode: pairCode,
      );

      if (result.groupId.isEmpty) {
        throw Exception('服务器未返回有效的组ID');
      }

      final updatedData = _syncData!.copyWith(groupId: result.groupId);
      await _saveSyncData(updatedData);

      setState(() {
        _devices = result.devices;
        _showJoinInput = false;
        _joinCodeController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('成功加入同步组')));
      }
      widget.onSuccess();
    } catch (e) {
      widget.onError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeDeviceFromGroup(DeviceInfo device) async {
    final isCurrentDevice = device.deviceId == _syncData?.deviceId;
    final actionText = isCurrentDevice ? '确认退出' : '确认移除';
    final title = isCurrentDevice ? '退出同步组' : '移除设备';
    String message = isCurrentDevice
        ? '确定要退出当前同步组吗?'
        : '确定要从同步组中移除 ${device.deviceName} 吗?';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await widget.serviceProvider.syncService.leaveGroup(
        deviceId: device.deviceId ?? '',
        groupId: _syncData!.groupId!,
      );

      if (isCurrentDevice) {
        final updatedData = SyncDeviceData(
          deviceId: _syncData!.deviceId,
          deviceOs: _syncData!.deviceOs,
          deviceName: _syncData!.deviceName,
          groupId: null,
        );
        await _saveSyncData(updatedData);

        setState(() {
          _pairCode = null;
          _pairCodeExpiry = null;
          _lastClosedPairCode = null;
          _devices = null;
        });

        // Stop refresh timer when leaving group
        _refreshTimer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已退出当前同步组')));
        }
        widget.onSuccess();
      } else {
        await _refreshDeviceList();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已移除所选设备')));
        }
        widget.onSuccess();
      }
    } catch (e) {
      widget.onError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGroup = _syncData?.groupId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在等待服务器响应...'),
                  ],
                ),
              ),
            ),
          )
        else if (hasGroup)
          Card(child: _buildGroupedLayout())
        else
          _buildNoGroupSection(),
      ],
    );
  }

  Widget _buildNoGroupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '同步组',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  ),
                );
              },
              child: _showJoinInput
                  ? KeyedSubtree(
                      key: const ValueKey('join_input'),
                      child: _buildJoinInputSection(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('no_group_actions'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.link_off,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '当前设备还未加入任何同步组~ 您可以：',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _createGroup,
                                  icon: const Icon(Icons.add_box, size: 32),
                                  label: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '发起',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                      Text(
                                        '创建一个同步组',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size.fromHeight(80),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleJoinInput,
                                  icon: const Icon(Icons.handshake, size: 32),
                                  label: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '加入',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                      Text(
                                        '加入已有同步组',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size.fromHeight(80),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.vpn_key,
                size: 20,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                '输入配对码',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _joinCodeController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(8),
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 100,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleJoinInput,
                  icon: const Icon(Icons.close),
                  label: const Text('取消'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSecondaryContainer,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _joinGroup,
                  icon: const Icon(Icons.login),
                  label: const Text('加入'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedLayout() {
    final isWideScreen = MediaQuery.of(context).size.width > 1000;
    final currentDevice = _devices?.firstWhere(
      (d) => d.deviceId == _syncData?.deviceId,
      orElse: () => DeviceInfo(deviceId: '', deviceOs: '', deviceName: ''),
    );

    Widget pairingContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      child: _pairCode != null
          ? _buildPairCodeSection()
          : _buildOpenPairingButton(),
    );

    if (isWideScreen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.group,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '同步组',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (currentDevice?.deviceId?.isNotEmpty ?? false) ...[
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () =>
                              _removeDeviceFromGroup(currentDevice!),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('退出'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  pairingContent,
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildDeviceList(),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.group,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '同步组',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentDevice?.deviceId?.isNotEmpty ?? false) ...[
                      Spacer(),
                      TextButton.icon(
                        onPressed: () => _removeDeviceFromGroup(currentDevice!),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('退出'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                pairingContent,
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDeviceList(),
          ),
        ],
      );
    }
  }

  Widget _buildOpenPairingButton() {
    return Container(
      key: const ValueKey('open_pairing_button'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: _openPairing,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.waving_hand,
                    size: 40,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '查看配对码',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '以便其他设备加入当前同步组',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPairCodeSection() {
    return Container(
      key: const ValueKey('pair_code_section'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.numbers,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '配对码',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _pairCode!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_pairCodeExpiry != null)
                Expanded(child: _buildTtlCountdown())
              else
                const Spacer(),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final currentPairCode = _pairCode;
                  setState(() {
                    _pairCode = null;
                    _pairCodeExpiry = null;
                    _lastClosedPairCode = currentPairCode;
                  });
                  // Switch back to normal refresh mode
                  _startPeriodicRefresh();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('关闭'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTtlCountdown() {
    if (_pairCodeExpiry == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final expiry = _pairCodeExpiry;
        if (expiry == null) return const SizedBox.shrink();

        final totalSeconds = expiry
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 9999);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalSeconds s 后失效',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceList() {
    final deviceCount = _devices?.length ?? 0;
    final hasDevices = deviceCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.devices_other,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '组内设备',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$deviceCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (hasDevices)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _devices!.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 0,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, index) {
              final device = _devices![index];
              final isCurrentDevice = device.deviceId == _syncData?.deviceId;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 1),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCurrentDevice
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.3)
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentDevice
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _getDeviceOsIcon(device.deviceOs),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.deviceName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: isCurrentDevice
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isCurrentDevice
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: kDebugMode
                      ? Text(
                          device.deviceId ?? '',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: !isCurrentDevice
                      ? IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 20),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _removeDeviceFromGroup(device),
                          tooltip: '移除此设备',
                        )
                      : Container(
                          margin: const EdgeInsets.only(right: 1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '当前',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                ),
              );
            },
          )
        else
          // Empty state when no devices
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '暂时没有找到组内设备',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
