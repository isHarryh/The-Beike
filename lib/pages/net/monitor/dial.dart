// Copyright (c) 2025, Harry Huang

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class NetDialDrawer extends StatefulWidget {
  const NetDialDrawer({super.key});

  @override
  State<NetDialDrawer> createState() => _NetDialDrawerState();
}

class _NetDialDrawerState extends State<NetDialDrawer> {
  bool _isDialing = false;
  String? _errorMessage;
  DialResult? _result;
  bool _isExpanded = false;

  static const String _endpoint = 'https://api.ip.sb/geoip';
  static const Duration _timeout = Duration(seconds: 10);

  Future<void> _startDial() async {
    setState(() {
      _isDialing = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(_endpoint);
      final startTime = DateTime.now();
      final response = await http.get(uri).timeout(_timeout);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      if (response.statusCode != 200) {
        throw const DialConnectionException();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final clientIp = _asString(data['ip']);
      if (clientIp == null) {
        throw const DialParsingException();
      }

      final result = DialResult(
        clientIp: clientIp,
        country: _asString(data['country']),
        countryCode: _asString(data['country_code']),
        asNumber: _asInt(data['asn']),
        asnOrganization: _asString(data['asn_organization']),
        isp: _asString(data['isp']),
        timezone: _asString(data['timezone']),
        latitude: _asDouble(data['latitude']),
        longitude: _asDouble(data['longitude']),
        roundTripTime: duration,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } on TimeoutException {
      _setConnectionError();
    } on SocketException {
      _setConnectionError();
    } on DialConnectionException {
      _setConnectionError();
    } on DialParsingException {
      _setUnknownError();
    } catch (_) {
      _setUnknownError();
    } finally {
      if (mounted) {
        setState(() {
          _isDialing = false;
        });
      }
    }
  }

  void _setConnectionError() {
    if (!mounted) return;
    setState(() {
      _result = null;
      _errorMessage = '无法连接到拨测服务商，请检查您的网络连接、防火墙和代理设置。';
    });
  }

  void _setUnknownError() {
    if (!mounted) return;
    setState(() {
      _result = null;
      _errorMessage = '发生了未知错误，可能是拨测服务商未按预期返回响应。';
    });
  }

  String _getButtonLabel() {
    if (_isDialing) return '正在拨测';
    if (_result != null || _errorMessage != null) return '重新拨测';
    return '开始拨测';
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  String _formatGeoLocation(double? longitude, double? latitude) {
    if (longitude == null || latitude == null) {
      return 'N/A';
    }
    return '${longitude.toStringAsFixed(3)}, ${latitude.toStringAsFixed(3)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '网络拨测',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '将向第三方服务商发起一次网络拨测，以检查本机的网络情况。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isDialing ? null : _startDial,
                child: _isDialing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('正在拨测'),
                        ],
                      )
                    : Text(_getButtonLabel()),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildResultSection(theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme) {
    if (_result != null) {
      return _buildSuccessCard(theme, _result!);
    }

    if (_errorMessage != null) {
      return _buildErrorCard(theme, _errorMessage!);
    }

    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Card(
      key: const ValueKey('placeholder'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.satellite_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '暂无记录',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '请点击“开始拨测”按钮来发起一次实时网络拨测，帮助你了解当前的出站网络状况。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(ThemeData theme, DialResult result) {
    return Card(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  '拨测成功',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              theme,
              label: '出站 IP',
              valueWidget: _buildIpValueWithCopy(result.clientIp),
              labelTrailing: _buildIpvBadge(result.isIpv6),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              label: '出站归属',
              value: result.countryCode != null || result.country != null
                  ? '${result.countryCode ?? 'N/A'} / ${result.country ?? 'N/A'}'
                  : '未知地区',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '详细信息',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 4),
              Divider(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.15,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                theme,
                label: 'AS 编号',
                value: result.asNumber?.toString() ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                label: 'AS 组织',
                value: result.asnOrganization ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                label: '网络服务提供商',
                value: result.isp ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                label: '时区代码',
                value: result.timezone ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                label: '估计经纬度',
                value: _formatGeoLocation(result.longitude, result.latitude),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                label: '往返耗时',
                value: '${result.roundTripTime} ms',
                valueColor: _getRoundTripTimeColor(result.roundTripTime),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, String error) {
    return Card(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  '拨测失败',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme, {
    required String label,
    String? value,
    Widget? valueWidget,
    Widget? labelTrailing,
    Widget? trailing,
    Color? valueColor,
  }) {
    assert(
      value != null || valueWidget != null,
      'Either value or valueWidget must be provided',
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (labelTrailing != null) ...[
                    const SizedBox(width: 8),
                    labelTrailing,
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (valueWidget != null)
                valueWidget
              else
                Text(
                  value!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildIpvBadge(bool isIpv6) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isIpv6 ? 'IPv6' : 'IPv4',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildIpValueWithCopy(String ipAddress) {
    return Row(
      children: [
        Text(
          ipAddress,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 2),
        IconButton(
          iconSize: 14,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: ipAddress));
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('IP 地址已复制到剪贴板')));
            }
          },
          icon: const Icon(Icons.content_copy),
        ),
      ],
    );
  }

  Color _getRoundTripTimeColor(int roundTripTime) {
    if (roundTripTime < 500) {
      return Colors.green[600]!;
    } else if (roundTripTime < 1000) {
      return Colors.orange[600]!;
    } else {
      return Colors.red[600]!;
    }
  }
}

class DialResult {
  const DialResult({
    required this.clientIp,
    this.country,
    this.countryCode,
    this.asNumber,
    this.asnOrganization,
    this.isp,
    this.timezone,
    this.latitude,
    this.longitude,
    required this.roundTripTime,
  });

  final String clientIp;
  final String? country;
  final String? countryCode;
  final int? asNumber;
  final String? asnOrganization;
  final String? isp;
  final String? timezone;
  final double? latitude;
  final double? longitude;
  final int roundTripTime;

  bool get isIpv6 => clientIp.contains(':');
}

class DialConnectionException implements Exception {
  const DialConnectionException();
}

class DialParsingException implements Exception {
  const DialParsingException();
}
