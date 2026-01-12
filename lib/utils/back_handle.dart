// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DoubleBackToExitWrapper extends StatefulWidget {
  final Widget child;
  final String snackBarMessage;
  final Duration interval;

  const DoubleBackToExitWrapper({
    super.key,
    required this.child,
    this.snackBarMessage = '再返回一次即可退出应用',
    this.interval = const Duration(seconds: 2),
  });

  @override
  State<DoubleBackToExitWrapper> createState() =>
      _DoubleBackToExitWrapperState();
}

class _DoubleBackToExitWrapperState extends State<DoubleBackToExitWrapper> {
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > widget.interval) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.snackBarMessage),
              duration: widget.interval,
            ),
          );
          return;
        }

        await SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}

/// A wrapper that intercepts the back button to show a snackbar and then pops.
class CommonPopWrapper extends StatefulWidget {
  final Widget child;

  const CommonPopWrapper({super.key, required this.child});

  @override
  State<CommonPopWrapper> createState() => _CommonPopWrapperState();
}

class _CommonPopWrapperState extends State<CommonPopWrapper> {
  bool _canPop = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        setState(() {
          _canPop = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop(result);
          }
        });
      },
      child: widget.child,
    );
  }
}
