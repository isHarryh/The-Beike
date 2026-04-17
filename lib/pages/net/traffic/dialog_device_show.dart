import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/types/net.dart';

class NetOnlineDeviceShowDialog extends StatelessWidget {
  final NetOnlineSession session;
  final ValueListenable<List<NetOnlineSession>> sessionsListenable;

  const NetOnlineDeviceShowDialog({
    super.key,
    required this.session,
    required this.sessionsListenable,
  });

  NetOnlineSession _resolveCurrentSession(List<NetOnlineSession> sessions) {
    if (sessions.isEmpty) {
      return session;
    }

    final sessionId = session.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      for (final candidate in sessions) {
        if ((candidate.sessionId ?? '').trim() == sessionId) {
          return candidate;
        }
      }
    }

    for (final candidate in sessions) {
      if (candidate.ip == session.ip &&
          candidate.mac.toUpperCase() == session.mac.toUpperCase()) {
        return candidate;
      }
    }

    for (final candidate in sessions) {
      if (candidate.mac.toUpperCase() == session.mac.toUpperCase()) {
        return candidate;
      }
    }

    return session;
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60 * 24) {
      final days = minutes ~/ (60 * 24);
      final hours = (minutes % (60 * 24)) ~/ 60;
      return '${days}天${hours}小时';
    }
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final leftMinutes = minutes % 60;
      return '${hours}小时${leftMinutes}分钟';
    }
    return '${minutes}分钟';
  }

  String _formatFlow(double mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(3)} GB';
    }
    return '${mb.toStringAsFixed(3)} MB';
  }

  String _formatMac(String rawMac) {
    var displayMac = rawMac.toUpperCase();
    if (RegExp(r'^[0-9A-F]{12}$').hasMatch(displayMac)) {
      displayMac = displayMac.replaceAllMapped(
        RegExp(r'.{2}'),
        (match) => '${match.group(0)}:',
      );
      displayMac = displayMac.substring(0, displayMac.length - 1);
    }
    return displayMac;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NetOnlineSession>>(
      valueListenable: sessionsListenable,
      builder: (context, sessions, child) {
        final theme = Theme.of(context);
        final currentSession = _resolveCurrentSession(sessions);
        final mac = _formatMac(currentSession.mac);

        return AlertDialog(
          title: const Text('连接详情'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildDetailItem(
                theme,
                'MAC 地址',
                mac,
                isMonospace: true,
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  iconSize: 16,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: currentSession.mac),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('MAC 地址已复制到剪贴板'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  tooltip: '复制',
                  style: IconButton.styleFrom(minimumSize: Size(32, 32)),
                ),
              ),
              _buildDetailItem(
                theme,
                '设备名称',
                currentSession.deviceName.trim().isNotEmpty
                    ? currentSession.deviceName.trim()
                    : '未命名设备',
              ),
              _buildDetailItem(theme, 'IP 地址', currentSession.ip),
              _buildDetailItem(
                theme,
                '上线时间',
                _formatDateTime(currentSession.loginTime),
              ),
              _buildDetailItem(
                theme,
                '使用时长',
                _formatDuration(currentSession.useTimeMinutes),
              ),
              _buildDetailItem(
                theme,
                '下行流量',
                _formatFlow(currentSession.downFlowMb),
              ),
              _buildDetailItem(
                theme,
                '上行流量',
                _formatFlow(currentSession.upFlowMb),
              ),
              _buildDetailItem(theme, '会话 ID', currentSession.sessionId ?? '-'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(
    ThemeData theme,
    String label,
    String value, {
    bool isMonospace = false,
    Widget? trailing,
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
                      child: Text(
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
