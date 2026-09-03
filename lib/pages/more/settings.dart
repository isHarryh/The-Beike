import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/utils/app_bar.dart';
import '/main.dart';
import '/types/preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  bool _isClearingCache = false;
  bool _isClearingPrefs = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '设置'),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildAppearanceSection(),
          _buildDataSection(),
          if (kDebugMode) _buildServiceSection(),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '外观',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildThemeModeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeSelector() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('配色方案', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                ThemeManager.currentThemeMode.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(switch (ThemeManager.currentThemeMode) {
            ThemeMode.system => Icons.brightness_auto,
            ThemeMode.light => Icons.light_mode,
            ThemeMode.dark => Icons.dark_mode,
          }),
          onPressed: () {
            ThemeManager.updateThemeMode(
              switch (ThemeManager.currentThemeMode) {
                ThemeMode.system => ThemeMode.light,
                ThemeMode.light => ThemeMode.dark,
                ThemeMode.dark => ThemeMode.system,
              },
            );
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '数据',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '除非您在使用本软件时出现问题，或技术支持人员要求您这么做，否则请勿轻易操作。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            _buildDataItem(
              title: '配置数据',
              subtitle: '清除所有配置数据，包括已登录的账号会话、数据缓存等。',
              isLoading: _isClearingCache,
              onPressed: () => _clearData(
                isPrefs: false,
                dialogMessage: '确定要清除所有配置数据吗？此操作不可撤销。',
                successMessage: '配置数据已清除',
                failureMessage: '清除配置数据失败',
                action: () => _serviceProvider.storeService.delAllConfig(),
              ),
            ),
            const SizedBox(height: 8),
            _buildDataItem(
              title: '偏好设置',
              subtitle: '清除所有偏好设置，包括跨设备同步的绑定、本地设置等。',
              isLoading: _isClearingPrefs,
              onPressed: () => _clearData(
                isPrefs: true,
                dialogMessage: '确定要清除所有偏好设置吗？此操作不可撤销。',
                successMessage: '偏好设置已清除',
                failureMessage: '清除偏好设置失败',
                action: () => _serviceProvider.storeService.delAllPref(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem({
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('清除'),
        ),
      ],
    );
  }

  Widget _buildServiceSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API 配置',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '仅供开发人员调试使用。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            _ServiceUrlField(
              label: '教务服务',
              defaultValue: _serviceProvider.coursesService.defaultBaseUrl,
              currentValue: _serviceProvider.coursesService.baseUrl,
              onChanged: (value) {
                _serviceProvider.coursesService.baseUrl = value;
                _serviceProvider.saveServiceSettings();
              },
            ),
            const SizedBox(height: 16),
            _ServiceUrlField(
              label: '校园网管理服务',
              defaultValue: _serviceProvider.netService.defaultBaseUrl,
              currentValue: _serviceProvider.netService.baseUrl,
              onChanged: (value) {
                _serviceProvider.netService.baseUrl = value;
                _serviceProvider.saveServiceSettings();
              },
            ),
            const SizedBox(height: 16),
            _ServiceUrlField(
              label: '同步服务',
              defaultValue: _serviceProvider.syncService.defaultBaseUrl,
              currentValue: _serviceProvider.syncService.baseUrl,
              onChanged: (value) {
                _serviceProvider.syncService.baseUrl = value;
                _serviceProvider.saveServiceSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearData({
    required bool isPrefs,
    required String dialogMessage,
    required String successMessage,
    required String failureMessage,
    required VoidCallback action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: Text(dialogMessage),
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

    if (confirmed != true) return;

    setState(() {
      if (isPrefs) {
        _isClearingPrefs = true;
      } else {
        _isClearingCache = true;
      }
    });
    try {
      action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$failureMessage: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isPrefs) {
            _isClearingPrefs = false;
          } else {
            _isClearingCache = false;
          }
        });
      }
    }
  }
}

class _ServiceUrlField extends StatefulWidget {
  final String label;
  final String defaultValue;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const _ServiceUrlField({
    required this.label,
    required this.defaultValue,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<_ServiceUrlField> createState() => _ServiceUrlFieldState();
}

class _ServiceUrlFieldState extends State<_ServiceUrlField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onSubmitted: (value) {
                  final newUrl = value.trim().isEmpty
                      ? widget.defaultValue
                      : value.trim();
                  widget.onChanged(newUrl);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '恢复默认',
              onPressed: () {
                _controller.clear();
                widget.onChanged(widget.defaultValue);
              },
            ),
          ],
        ),
      ],
    );
  }
}
