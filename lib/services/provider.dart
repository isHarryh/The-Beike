import 'package:flutter/foundation.dart';
import '/services/courses/base.dart';
import '/services/courses/ustb_byyt.dart';
import '/services/courses/exceptions.dart';
import '/services/store/base.dart';
import '/services/store/general.dart';
import '/services/net/base.dart';
import '/services/net/drcom_net.dart';
import '/services/sync/base.dart';
import '/services/sync/sync_service.dart';
import '/types/courses.dart';
import '/types/sync.dart';
import '/types/preferences.dart';

class ServiceProvider extends ChangeNotifier {
  final List<VoidCallback> _serviceListenerDisposers = [];

  // Course Service
  late BaseCoursesService _coursesService;

  // Net Service
  late BaseNetService _netService;

  // Sync Service
  late BaseSyncService _syncService;

  // Store Service
  late BaseStoreService _storeService;

  // Singleton
  static final ServiceProvider _instance = ServiceProvider._internal();
  static ServiceProvider get instance => _instance;

  ServiceProvider._internal() {
    _coursesService = UstbByytService();
    _netService = DrcomNetService();
    _syncService = SyncService();
    _storeService = GeneralStoreService();

    _bindService(_coursesService);
    _bindService(_netService);
    _bindService(_syncService);
  }

  BaseCoursesService get coursesService => _coursesService;

  BaseNetService get netService => _netService;

  BaseSyncService get syncService => _syncService;

  BaseStoreService get storeService => _storeService;

  Future<void> initializeServices() async {
    await _storeService.initialize();

    // Load and restore service baseUrl settings
    await _loadServiceSettings();

    // Try to restore login from cache after store service is initialized
    await _tryAutoLogin();

    // Try to load curriculum data after login
    if (coursesService.isOnline) {
      await _loadCurriculumData();
    }
  }

  Future<void> _loadServiceSettings() async {
    try {
      final settingsPreference = storeService
          .getPref<ServiceSettingsPreference>(
            "service_settings",
            ServiceSettingsPreference.fromJson,
          );

      if (settingsPreference != null) {
        if (settingsPreference.coursesBaseUrl != null) {
          _coursesService.baseUrl = settingsPreference.coursesBaseUrl!;
        }
        if (settingsPreference.netBaseUrl != null) {
          _netService.baseUrl = settingsPreference.netBaseUrl!;
        }
        if (settingsPreference.syncBaseUrl != null) {
          _syncService.baseUrl = settingsPreference.syncBaseUrl!;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to load service settings: $e');
    }
  }

  Future<void> saveServiceSettings() async {
    try {
      final settingsPreference = ServiceSettingsPreference(
        coursesBaseUrl:
            _coursesService.baseUrl == _coursesService.defaultBaseUrl
            ? null
            : _coursesService.baseUrl,
        netBaseUrl: _netService.baseUrl == _netService.defaultBaseUrl
            ? null
            : _netService.baseUrl,
        syncBaseUrl: _syncService.baseUrl == _syncService.defaultBaseUrl
            ? null
            : _syncService.baseUrl,
      );
      storeService.putPref("service_settings", settingsPreference);
    } catch (e) {
      if (kDebugMode) print('Failed to save service settings: $e');
    }
  }

  Future<void> _loadCurriculumData() async {
    try {
      // Check cache
      final cachedData = storeService.getConfig<CurriculumIntegratedData>(
        "curriculum_data",
        CurriculumIntegratedData.fromJson,
      );

      if (cachedData == null) {
        // Load fresh curriculum data
        await getCurriculumData();
      }
    } catch (e) {
      // Ignore errors during background loading
    }
  }

  Future<CurriculumIntegratedData?> getCurriculumData([
    TermInfo? termInfo,
  ]) async {
    final cachedData = storeService.getConfig<CurriculumIntegratedData>(
      "curriculum_data",
      CurriculumIntegratedData.fromJson,
    );

    if (cachedData != null) {
      return cachedData;
    }

    if (!coursesService.isOnline) {
      return null;
    }

    if (termInfo != null) {
      try {
        return await loadCurriculumForTerm(termInfo);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  Future<CurriculumIntegratedData> loadCurriculumForTerm(
    TermInfo termInfo,
  ) async {
    if (!coursesService.isOnline) {
      throw const CourseServiceOffline();
    }

    final futures = await Future.wait([
      coursesService.getCurriculum(termInfo),
      coursesService.getCoursePeriods(termInfo),
      coursesService
          .getCalendarDays(termInfo)
          .catchError((e) => <CalendarDay>[]),
    ]);

    final classes = futures[0] as List<ClassItem>;
    final periods = futures[1] as List<ClassPeriod>;
    final calendarDays = futures[2] as List<CalendarDay>;

    final integratedData = CurriculumIntegratedData(
      currentTerm: termInfo,
      allClasses: classes,
      allPeriods: periods,
      calendarDays: calendarDays.isEmpty ? null : calendarDays,
    );

    // Cache the data
    storeService.putConfig<CurriculumIntegratedData>(
      "curriculum_data",
      integratedData,
    );

    return integratedData;
  }

  //

  /// Maybe syncs config if last sync was more than 10 seconds ago.
  /// Silently ignores any sync errors.
  Future<void> maybeUpdateConfigAndApplyChanges() async {
    try {
      final syncData = _storeService.getPref<SyncDeviceData>(
        'sync_device',
        SyncDeviceData.fromJson,
      );

      if (syncData == null ||
          syncData.deviceId == null ||
          syncData.groupId == null) {
        return; // No sync data available
      }

      // Check if last sync was too recent
      final lastSync = _syncService.lastSyncStatus;
      if (lastSync != null) {
        final elapsed = DateTime.now().difference(lastSync.timestamp);
        if (elapsed.inSeconds < 10) {
          return; // Too soon, skip update
        }
      }

      // Perform the sync
      final configs = _storeService.getAllConfigs();
      final newConfigs = await _syncService.update(
        deviceId: syncData.deviceId!,
        groupId: syncData.groupId!,
        config: configs,
      );

      // Apply new configs if received
      if (newConfigs != null) {
        _storeService.updateConfigs(newConfigs);
      }
    } catch (e) {
      // Silently ignore sync errors
      if (kDebugMode) {
        print('maybeUpdateConfigAndApplyChanges failed: $e');
      }
    }
  }

  //

  /// Try to restore login from cache on app startup
  Future<void> _tryAutoLogin() async {
    try {
      final cachedData = _storeService.getConfig<UserLoginIntegratedData>(
        "course_account_data",
        UserLoginIntegratedData.fromJson,
      );

      if (cachedData == null) return;

      final data = cachedData;
      final method = data.method;

      if (method == "cookie" || method == "sso") {
        if (data.cookie != null && data.user != null) {
          await _coursesService.login(data.cookie!);
          // Get new user info and verify consistency
          final newUserInfo = await coursesService.getUserInfo();
          assert(
            newUserInfo == data.user,
            "User info mismatch after auto-login with cached cookie",
          );
        }
      }
      // Other methods: do nothing, remain logged out
    } catch (e) {
      // On any exception, remain logged out, auto-login should be silent
      if (kDebugMode) {
        print('Auto-login failed: $e');
      }
    }
  }

  @override
  void dispose() {
    for (final disposer in _serviceListenerDisposers) {
      disposer();
    }
    super.dispose();
  }

  void _bindService(Listenable service) {
    void forward() => notifyListeners();
    service.addListener(forward);
    _serviceListenerDisposers.add(() {
      service.removeListener(forward);
    });
  }
}
