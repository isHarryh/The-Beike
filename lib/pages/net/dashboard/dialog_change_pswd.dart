import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/net.dart';

class NetChangePasswordDialog extends StatefulWidget {
  const NetChangePasswordDialog({super.key});

  @override
  State<NetChangePasswordDialog> createState() =>
      _NetChangePasswordDialogState();
}

class _NetChangePasswordDialogState extends State<NetChangePasswordDialog> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    return password.length >= 8 && password.length <= 16;
  }

  bool get _isChangeAllowed {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    return oldPassword.isNotEmpty &&
        newPassword.isNotEmpty &&
        confirmPassword.isNotEmpty;
  }

  Future<void> _handleChangePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate new password and confirm password match
    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = '新密码的填写不一致';
      });
      return;
    }

    // Validate password requirements
    if (!_isPasswordValid(newPassword)) {
      setState(() {
        _errorMessage = '密码要求是 8~16 位';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call service to change password
      await _serviceProvider.netService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      // Error occurred during changing password
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Logout and update cached credentials
      if (mounted) {
        try {
          await _serviceProvider.logoutFromNetService();
        } catch (e) {
          if (mounted) {}
        }

        final cachedData = _serviceProvider.storeService
            .getConfig<NetUserIntegratedData>(
              "net_account_data",
              NetUserIntegratedData.fromJson,
            );
        if (cachedData != null) {
          // Clear only the password field
          final updatedLoginData = NetUserIntegratedData(
            account: cachedData.account,
            password: '',
          );
          _serviceProvider.storeService.putConfig<NetUserIntegratedData>(
            "net_account_data",
            updatedLoginData,
          );
        }

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // Error occurred during post steps
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
      title: const Text('更改密码'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('您正在更改校园网的密码。请您输入原密码和新密码。', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _oldPasswordController,
              decoration: const InputDecoration(labelText: '原密码'),
              obscureText: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                // Trigger rebuild for button state
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: '新密码'),
              obscureText: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                // Trigger rebuild for button state
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: '确认新密码'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {
                // Trigger rebuild for button state
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                "更改密码失败，原因如下：",
                style: TextStyle(color: theme.colorScheme.error),
              ),
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
              : _handleChangePassword,
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
