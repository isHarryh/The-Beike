// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';
import '/services/provider.dart';

mixin PageStateMixin<T extends StatefulWidget> on State<T> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  ServiceProvider get serviceProvider => _serviceProvider;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);
    onServiceInit();
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (mounted) {
      onServiceStatusChanged();
    }
  }

  /// Override this method to initialize service-related data
  void onServiceInit() {}

  /// Override this method to handle service status changes
  void onServiceStatusChanged() {}
}

mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        if (loading) _errorMessage = null;
      });
    }
  }

  void setError(String? error) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  void clearError() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
  }
}
