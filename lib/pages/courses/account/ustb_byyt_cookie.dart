import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/utils/login_dialog.dart';

Future<void> showCookieLoginDialog(
  BuildContext context, {
  Function(String method, String cookie)? onLoginSuccess,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _CookieLoginDialog(onLoginSuccess: onLoginSuccess);
    },
  );
}

class _CookieLoginDialog extends StatefulWidget {
  final Function(String method, String cookie)? onLoginSuccess;

  const _CookieLoginDialog({this.onLoginSuccess});

  @override
  State<_CookieLoginDialog> createState() => _CookieLoginDialogState();
}

class _CookieLoginDialogState extends State<_CookieLoginDialog> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final TextEditingController _cookieController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    _cookieController.dispose();
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (mounted) {
      final service = _serviceProvider.coursesService;
      if (service.isOnline) {
        // Navigate back to account page on successful login
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleLogin() async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid Cookie';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _serviceProvider.coursesService.login(cookie);

      // Notify success
      widget.onLoginSuccess?.call("cookie", cookie);

      if (mounted) {
        setState(() {
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return LoginDialog(
      title: 'Cookie登录',
      description: '本研一体教务管理系统',
      icon: Icons.cookie_outlined,
      iconColor: Theme.of(context).colorScheme.error,
      headerColor: Theme.of(context).colorScheme.errorContainer,
      onHeaderColor: Theme.of(context).colorScheme.onErrorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '高级用户模式',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '此模式需要您从浏览器中获取有效的会话Cookie并输入。\n'
                  '如果您不清楚您在做什么，请勿使用此功能。',
                  style: TextStyle(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cookie input
          Text(
            'Cookie输入',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cookieController,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              hintText: '请粘贴您的会话Cookie...\n例如：SESSION=xxxxxx; INCO=xxxxxx',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 20),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Login button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('登录中...'),
                      ],
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '使用Cookie登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
