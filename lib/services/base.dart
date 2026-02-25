import 'package:flutter/foundation.dart';

enum ServiceStatus {
  online, // Logged in
  offline, // Not logged in
  pending, // Transaction in progress
  error, // Error occurred
}

/// Provides common service status management and notifies listeners on change.
///
/// All services that require login or expose state should mix this in on top of
/// [ChangeNotifier], then call `addListener` from the provider to propagate
/// updates to the UI. The helper guards (`runLogin`, `runLogout`) standardize
/// status transitions for login-related flows.
mixin BaseService on ChangeNotifier {
  ServiceStatus _status = ServiceStatus.offline;
  String? _errorMessage;
  String? _baseUrl;

  ServiceStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isOnline => _status == ServiceStatus.online;
  bool get isOffline => _status == ServiceStatus.offline;
  bool get isPending => _status == ServiceStatus.pending;
  bool get hasError => _status == ServiceStatus.error;

  String get defaultBaseUrl => '';
  String get baseUrl => _baseUrl ?? defaultBaseUrl;

  set baseUrl(String url) {
    _baseUrl = url;
    notifyListeners();
  }

  void setStatus(ServiceStatus status, [String? errorMessage]) {
    // Avoid needless rebuilds
    if (_status == status && _errorMessage == errorMessage) return;
    _status = status;
    _errorMessage = errorMessage;
    onStatusChanged(status, errorMessage);
    notifyListeners();
  }

  void setOnline() => setStatus(ServiceStatus.online);

  void setOffline() => setStatus(ServiceStatus.offline);

  void setPending() => setStatus(ServiceStatus.pending);

  void setError([String? message]) => setStatus(ServiceStatus.error, message);

  /// Wrap a login-like action so every service uses consistent status changes.
  @protected
  Future<T> runLogin<T>(Future<T> Function() action) async {
    setPending();
    try {
      final result = await action();
      setOnline();
      return result;
    } catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  /// Wrap a logout-like action and always end in offline state.
  @protected
  Future<void> runLogout(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (kDebugMode) {
        print('Logout action failed: $e');
      }
    } finally {
      setOffline();
    }
  }

  /// Override to hook status changes inside a service without re-registering
  /// listeners in the provider.
  void onStatusChanged(ServiceStatus status, String? errorMessage) {}
}
