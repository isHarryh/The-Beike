import 'package:flutter/material.dart';

class NetAddDeviceDialog extends StatefulWidget {
  const NetAddDeviceDialog({super.key});

  @override
  State<NetAddDeviceDialog> createState() => _NetAddDeviceDialogState();
}

class _NetAddDeviceDialogState extends State<NetAddDeviceDialog> {
  final _macController = TextEditingController();
  final _nameController = TextEditingController(text: '我的设备');

  @override
  void dispose() {
    _macController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final mac = _macController.text.trim();
    final name = _nameController.text.trim();
    if (mac.isNotEmpty) {
      Navigator.of(context).pop({'mac': mac, 'name': name});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('添加设备'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('请输入设备的物理地址（MAC 地址）和设备名称。', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _macController,
              decoration: const InputDecoration(
                labelText: 'MAC 地址',
                hintText: '例如: A1B2C3D4E5F6',
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '设备名称',
                hintText: '（可选）',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
