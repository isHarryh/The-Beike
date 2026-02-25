import 'package:flutter/foundation.dart';
import '/services/base.dart';
import '/types/sync.dart';

enum SyncStatusType { idle, syncing, success, failure }

class SyncStatus {
  final SyncStatusType type;
  final DateTime timestamp;

  SyncStatus({required this.type, required this.timestamp});

  bool get isSuccess => type == SyncStatusType.success;
  bool get isFailure => type == SyncStatusType.failure;
  bool get isSyncing => type == SyncStatusType.syncing;
}

abstract class BaseSyncService extends ChangeNotifier with BaseService {
  SyncStatus? _lastSyncStatus;

  SyncStatus? get lastSyncStatus => _lastSyncStatus;

  void recordSyncStatus(SyncStatusType type) {
    _lastSyncStatus = SyncStatus(type: type, timestamp: DateTime.now());
    notifyListeners();
  }

  /// Gets announcements from the server.
  Future<List<Announcement>> getAnnouncements();

  /// Gets release info from the server.
  Future<ReleaseInfo?> getRelease();

  /// Registers a new device and get a unique device ID.
  Future<String> registerDevice({
    required String deviceOs,
    required String deviceName,
  });

  /// Creates a new sync group.
  Future<String> createGroup({
    required String deviceId,
    required String byytCookie,
  });

  /// Opens pairing mode and get a pair code.
  Future<PairingInfo> openPairing({
    required String deviceId,
    required String groupId,
  });

  /// Makes the pair code deleted immediately.
  Future<void> closePairing({
    required String pairCode,
    required String groupId,
  });

  /// Gets normal devices that have joined the sync group.
  Future<List<DeviceInfo>> listDevices({
    required String groupId,
    String? deviceId,
  });

  /// Joins a sync group using the given pair code.
  Future<JoinGroupResult> joinGroup({
    required String deviceId,
    required String pairCode,
  });

  /// Removes the given device from a sync group.
  Future<void> leaveGroup({required String deviceId, required String groupId});

  /// Syncs config with the server.
  Future<Map<String, dynamic>?> update({
    required String deviceId,
    required String groupId,
    required Map<String, dynamic> config,
  });
}
