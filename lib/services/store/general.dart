import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '/types/base.dart';
import 'base.dart';

class GeneralStoreService extends BaseStoreService {
  static const String _configDir = 'config';
  static const String _prefDir = 'pref';

  late final String _rootPath;
  late final Directory _configDirectory;
  late final Directory _prefDirectory;

  final Map<String, BaseDataClass> _configMemory = {};
  final Map<String, BaseDataClass> _prefMemory = {};

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final rootDir = await getApplicationSupportDirectory();
      _rootPath = rootDir.path;

      _configDirectory = Directory('$_rootPath/$_configDir');
      _prefDirectory = Directory('$_rootPath/$_prefDir');

      await _configDirectory.create(recursive: true);
      await _prefDirectory.create(recursive: true);

      _initialized = true;
    } catch (e) {
      _initialized = false;
    }
  }

  @override
  void ensureInitialized() {
    if (!_initialized) {
      throw Exception('Store service is not initialized.');
    }
  }

  // Private Helpers

  String _getConfigFilePath(String key) {
    return '${_configDirectory.path}/$key.json';
  }

  String _getPrefFilePath(String key) {
    return '${_prefDirectory.path}/$key.json';
  }

  bool _has(
    String key,
    Map<String, BaseDataClass> memory,
    String Function(String) pathProvider,
  ) {
    ensureInitialized();

    if (memory.containsKey(key)) {
      return true;
    }

    final file = File(pathProvider(key));
    return file.existsSync();
  }

  bool _put<T extends BaseDataClass>(
    String key,
    T value,
    Map<String, BaseDataClass> memory,
    String Function(String) pathProvider,
  ) {
    ensureInitialized();

    try {
      value.updateLastUpdateTime();

      final jsonData = value.toJson();
      final file = File(pathProvider(key));
      file.writeAsStringSync(json.encode(jsonData));

      memory[key] = value;
      return true;
    } catch (e) {
      return false;
    }
  }

  T? _get<T extends BaseDataClass>(
    String key,
    T Function(Map<String, dynamic>) factory,
    Map<String, BaseDataClass> memory,
    String Function(String) pathProvider,
  ) {
    ensureInitialized();

    try {
      if (memory.containsKey(key)) {
        return memory[key] as T;
      }

      final file = File(pathProvider(key));
      if (!file.existsSync()) {
        return null;
      }

      final content = file.readAsStringSync();
      final jsonData = json.decode(content) as Map<String, dynamic>;
      final value = factory(jsonData);

      memory[key] = value;
      return value;
    } catch (e) {
      return null;
    }
  }

  void _del(
    String key,
    Map<String, BaseDataClass> memory,
    String Function(String) pathProvider,
  ) {
    ensureInitialized();

    try {
      final file = File(pathProvider(key));
      if (file.existsSync()) {
        file.deleteSync();
      }

      memory.remove(key);
    } catch (e) {
      if (kDebugMode) print('Failed to remove key $key: $e');
    }
  }

  Future<void> _delAll(
    Directory directory,
    Map<String, BaseDataClass> memory,
  ) async {
    ensureInitialized();

    try {
      if (await directory.exists()) {
        final files = await directory.list().toList();
        for (final file in files) {
          if (file is File) {
            file.deleteSync();
          }
        }
      }

      memory.clear();
    } catch (e) {
      if (kDebugMode) print('Failed to remove all: $e');
    }
  }

  // Implementations

  @override
  bool hasConfigKey(String key) => _has(key, _configMemory, _getConfigFilePath);

  @override
  bool putConfig<T extends BaseDataClass>(String key, T value) =>
      _put(key, value, _configMemory, _getConfigFilePath);

  @override
  T? getConfig<T extends BaseDataClass>(
    String key,
    T Function(Map<String, dynamic>) factory,
  ) => _get(key, factory, _configMemory, _getConfigFilePath);

  @override
  void delConfig(String key) => _del(key, _configMemory, _getConfigFilePath);

  @override
  void delAllConfig() => _delAll(_configDirectory, _configMemory);

  @override
  bool hasPrefKey(String key) => _has(key, _prefMemory, _getPrefFilePath);

  @override
  bool putPref<T extends BaseDataClass>(String key, T value) =>
      _put(key, value, _prefMemory, _getPrefFilePath);

  @override
  T? getPref<T extends BaseDataClass>(
    String key,
    T Function(Map<String, dynamic>) factory,
  ) => _get(key, factory, _prefMemory, _getPrefFilePath);

  @override
  void delPref(String key) => _del(key, _prefMemory, _getPrefFilePath);

  @override
  void delAllPref() {
    _delAll(_prefDirectory, _prefMemory);
  }

  @override
  Map<String, dynamic> getAllConfigs() {
    ensureInitialized();
    final configs = <String, dynamic>{};

    try {
      final files = _configDirectory.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final filename = file.uri.pathSegments.last;
          final key = filename.substring(
            0,
            filename.length - 5,
          ); // remove .json
          try {
            final content = file.readAsStringSync();
            final jsonContent = json.decode(content);
            configs[key] = jsonContent;
          } catch (e) {
            // Ignore bad files
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return configs;
  }

  @override
  void updateConfigs(Map<String, dynamic> configs) {
    ensureInitialized();

    for (final entry in configs.entries) {
      final key = entry.key;
      final value = entry.value;

      try {
        final file = File(_getConfigFilePath(key));
        file.writeAsStringSync(json.encode(value));

        // Invalidate memory cache as we updated the file
        _configMemory.remove(key);
      } catch (e) {
        // Ignore errors
      }
    }
  }
}
