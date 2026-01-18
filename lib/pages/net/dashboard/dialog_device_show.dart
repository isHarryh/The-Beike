import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/types/net.dart';

class NetDeviceShowDialog extends StatefulWidget {
  final MacDevice device;
  final Future<bool> Function(String newName)? onRename;

  const NetDeviceShowDialog({super.key, required this.device, this.onRename});

  @override
  State<NetDeviceShowDialog> createState() => _NetDeviceShowDialogState();
}

class _NetDeviceShowDialogState extends State<NetDeviceShowDialog> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.device.name.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleEditingName() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _submitRename() async {
    if (widget.onRename != null) {
      final newName = _controller.text.trim();
      if (newName.isEmpty || newName == widget.device.name.trim()) {
        setState(() {
          _isEditing = false;
          _controller.text = widget.device.name.trim();
        });
        return;
      }

      if (await widget.onRename!(newName) == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('重命名设备成功')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('重命名设备失败')));
        }
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = widget.device;
    var displayMac = device.mac.toUpperCase();
    if (RegExp(r'^[0-9A-F]{12}$').hasMatch(displayMac)) {
      displayMac = displayMac.replaceAllMapped(
        RegExp(r'.{2}'),
        (match) => '${match.group(0)}:',
      );
      displayMac = displayMac.substring(0, displayMac.length - 1);
    }

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('设备详情')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: device.isOnline
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: device.isOnline
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  size: 20,
                  device.isOnline ? Icons.link : Icons.link_off,
                  color: device.isOnline ? Colors.green.shade700 : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  device.isOnline ? '在线' : '离线',
                  style: TextStyle(
                    color: device.isOnline
                        ? Colors.green.shade700
                        : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildDetailItem(
            theme,
            'MAC 地址',
            displayMac,
            isMonospace: true,
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              iconSize: 16,
              onPressed: () async {
                final rawMac = device.mac.toUpperCase();
                await Clipboard.setData(ClipboardData(text: rawMac));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('MAC 地址已复制到剪贴板'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              tooltip: '复制',
              style: IconButton.styleFrom(minimumSize: Size(32, 32)),
            ),
          ),
          _buildDetailItem(
            theme,
            '设备名称',
            _isEditing
                ? ''
                : (device.name.trim().isNotEmpty
                      ? device.name.trim()
                      : '未命名设备'),
            trailing: widget.onRename != null
                ? IconButton(
                    icon: Icon(_isEditing ? Icons.check : Icons.edit),
                    iconSize: 16,
                    onPressed: _isEditing ? _submitRename : _toggleEditingName,
                    tooltip: _isEditing ? '保存' : '编辑',
                    style: IconButton.styleFrom(minimumSize: Size(32, 32)),
                  )
                : null,
            customValue: _isEditing
                ? TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyLarge,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitRename(),
                    autofocus: true,
                  )
                : null,
          ),
          _buildDetailItem(
            theme,
            '设备类型',
            device.isDumbDevice ? '哑终端设备' : '常规设备',
          ),
          _buildDetailItem(theme, '最近登录时间', device.lastOnlineTime),
          _buildDetailItem(theme, '最近登录 IP', device.lastOnlineIp),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    ThemeData theme,
    String label,
    String value, {
    bool isMonospace = false,
    Widget? trailing,
    Widget? customValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          customValue ??
                          Text(
                            value,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontFamily: isMonospace ? 'monospace' : null,
                            ),
                          ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
