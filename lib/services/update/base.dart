import 'package:dio/dio.dart';

/// Contract for downloading update packages and running the install flow.
abstract class BaseUpdateService {
  /// Whether the current platform supports in-app download and install.
  bool get supportsInAppUpdate;

  /// Resolves the absolute local save path for an update package file.
  Future<String> getSavePath(String fileName);

  /// Downloads the update package from [url] to [savePath].
  ///
  /// Reports progress through [onProgress] and can be aborted via [cancelToken].
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });

  /// Deletes the local update package file at [filePath] if it exists.
  Future<void> deleteFile(String filePath);

  /// Runs the installation flow for the downloaded package at [filePath].
  Future<void> install(String filePath);
}
