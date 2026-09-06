import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ustb_sso/ustb_sso.dart';
import '/services/provider.dart';
import '/types/payment.dart';
import '/utils/login_dialog.dart';
import '/utils/ustb_sso.dart';

Future<void> showPaymentLoginDialog(
  BuildContext context, {
  VoidCallback? onLoginSuccess,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _PaymentLoginDialog(onLoginSuccess: onLoginSuccess);
    },
  );
}

class _PaymentLoginDialog extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const _PaymentLoginDialog({this.onLoginSuccess});

  @override
  State<_PaymentLoginDialog> createState() => _PaymentLoginDialogState();
}

class _PaymentLoginDialogState extends State<_PaymentLoginDialog> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    super.dispose();
  }

  void _onServiceStatusChanged() {
    final service = _serviceProvider.paymentService;
    if (mounted && service.isOnline) {
      Navigator.of(context).pop();
      widget.onLoginSuccess?.call();
    }
  }

  /// Completes the SSO handshake and extracts the payment token.
  ///
  /// The platform hands the token back in the callback URL (e.g.
  /// `https://xyjf.ustb.edu.cn/#/casLogin?token=...`), which the final URL of
  /// the completed SSO chain usually already carries; otherwise the session
  /// replays the SSO entry and follows the redirect hops to reach it.
  Future<String?> _extractXyjfToken(
    HttpSession session,
    http.Response response,
  ) async {
    // The final landing URL of the completed SSO chain may already carry it.
    final carriedToken = _extractTokenFromResponse(response);
    if (carriedToken != null) return carriedToken;

    final param = Prefabs.xyjfUstbEduCn;
    const entryUrl = 'https://sso.ustb.edu.cn/idp/authCenter/authenticate';

    // Starting from the entry's Location (which carries the authorization
    // code) is essential; a bare callback request fails ticket validation.
    final entry = await session.get(
      entryUrl,
      params: {
        'client_id': param.entityId,
        'redirect_uri': param.redirectUri,
        'login_return': 'true',
        'state': param.state,
        'response_type': 'code',
      },
      redirect: false,
    );
    final entryLocation = _responseLocation(entry);
    if (entryLocation == null) {
      throw Exception('SSO did not return an authorization redirect.');
    }

    var uri = Uri.parse(entryUrl).resolve(entryLocation);
    for (var hop = 0; hop < 8; hop++) {
      final token = _extractTokenFromUri(uri);
      if (token != null) return token;

      final hopResponse = await session.get(uri.toString(), redirect: false);
      final location =
          _responseLocation(hopResponse) ?? _locationValueFromBody(hopResponse);
      if (location == null) break;
      uri = uri.resolve(location);
    }
    return _extractTokenFromUri(uri);
  }

  String? _extractTokenFromResponse(http.Response response) {
    final url = response.request?.url;
    return url == null ? null : _extractTokenFromUri(url);
  }

  String? _responseLocation(http.Response response) =>
      response.headers['location'];

  /// Some callbacks answer with a bridge page instead of a redirect; the
  /// destination then lives in a `var locationValue = "..."` snippet.
  String? _locationValueFromBody(http.Response response) => RegExp(
    r'var locationValue\s*=\s*"([^"]+)"',
  ).firstMatch(response.body)?.group(1);

  String? _extractTokenFromUri(Uri uri) {
    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) return token;
    // Hash routing: the callback may look like /#/casLogin?token=...
    final fragment = uri.fragment;
    final queryIndex = fragment.indexOf('?');
    if (queryIndex >= 0) {
      final fragmentParams = Uri(
        query: fragment.substring(queryIndex + 1),
      ).queryParameters;
      final fragmentToken = fragmentParams['token'];
      if (fragmentToken != null && fragmentToken.isNotEmpty) {
        return fragmentToken;
      }
    }
    // Fallback: scan the whole URL for a JWT-looking token parameter.
    final match = RegExp(
      r'[?&]token=(eyJ[\w-]+\.[\w-]+\.[\w-]+)',
    ).firstMatch(uri.toString());
    return match?.group(1);
  }

  Future<void> _handleSsoSuccess(dynamic response, HttpSession session) async {
    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });
    try {
      final token = await _extractXyjfToken(session, response as http.Response);
      if (token == null) {
        throw Exception('Failed to extract payment token from SSO session.');
      }
      await _loginAndPersist(token);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _errorMessage = '$e';
        });
      }
    }
  }

  Future<void> _loginAndPersist(String token) async {
    final service = _serviceProvider.paymentService;
    await service.login(token);
    final user = service.cachedUserInfo ?? await service.getUserInfo();
    _serviceProvider.storeService.putConfig<PaymentAccountData>(
      'payment_account_data',
      PaymentAccountData(user: user, token: token, method: 'sso'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoginDialog(
      title: '统一身份认证',
      description: '校园缴费平台',
      icon: Icons.payments_outlined,
      iconColor: Theme.of(context).colorScheme.primary,
      headerColor: Theme.of(context).colorScheme.primaryContainer,
      onHeaderColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Column(
        children: [
          UstbSsoAuthWidget(
            applicationParam: Prefabs.xyjfUstbEduCn,
            onSuccess: _handleSsoSuccess,
          ),
          if (_isLoggingIn) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '正在登录到缴费平台...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
