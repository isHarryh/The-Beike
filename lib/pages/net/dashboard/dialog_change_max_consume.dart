import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/provider.dart';

class NetChangeMaxConsumeDialog extends StatefulWidget {
  final int? currentMaxConsume;

  const NetChangeMaxConsumeDialog({super.key, this.currentMaxConsume});

  @override
  State<NetChangeMaxConsumeDialog> createState() =>
      _NetChangeMaxConsumeDialogState();
}

class _NetChangeMaxConsumeDialogState extends State<NetChangeMaxConsumeDialog> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  late TextEditingController _consumeLimitController;
  bool _enableLimit = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _enableLimit =
        widget.currentMaxConsume != null && widget.currentMaxConsume! < 999999;
    _consumeLimitController = TextEditingController(
      text: _enableLimit ? widget.currentMaxConsume!.toString() : '',
    );
  }

  @override
  void dispose() {
    _consumeLimitController.dispose();
    super.dispose();
  }

  bool get _isChangeAllowed {
    if (!_enableLimit) {
      return true; // Always allow disabling
    }
    final limitStr = _consumeLimitController.text.trim();
    if (limitStr.isEmpty) {
      return false;
    }
    final limit = int.tryParse(limitStr);
    return limit != null && limit >= 0 && limit <= 200;
  }

  Future<void> _handleChangeConsume() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      int? maxConsume;
      if (_enableLimit) {
        final limitStr = _consumeLimitController.text.trim();
        maxConsume = int.parse(limitStr);
      }

      await _serviceProvider.netService.changeConsumeProtect(
        maxConsume: maxConsume,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('更改限额'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '您可以设置每周期的最大消费额度，从而控制套餐外的余额消耗。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用限额'),
              value: _enableLimit,
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _enableLimit = value ?? false;
                        if (!_enableLimit) {
                          _consumeLimitController.clear();
                        }
                      });
                    },
            ),
            if (_enableLimit) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _consumeLimitController,
                      decoration: const InputDecoration(
                        labelText: '限额 (0~200 元)',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      enabled: !_isLoading,
                      onChanged: (_) => setState(() {
                        // Trigger rebuild for button state
                      }),
                    ),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text('修改失败', style: TextStyle(color: theme.colorScheme.error)),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: (_isLoading || !_isChangeAllowed)
              ? null
              : _handleChangeConsume,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('修改'),
        ),
      ],
    );
  }
}
