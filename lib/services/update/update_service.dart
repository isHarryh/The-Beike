import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '/services/update/base.dart';
import '/services/update/exceptions.dart';
import '/utils/meta_info.dart';

class UpdateService extends BaseUpdateService {
  late final Dio _dio;

  UpdateService() {
    _dio = Dio(
      BaseOptions(headers: {'User-Agent': MetaInfo.instance.userAgent}),
    );
  }

  @override
  bool get supportsInAppUpdate => Platform.isAndroid || Platform.isWindows;

  @override
  Future<String> getSavePath(String fileName) async {
    final Directory dir;
    if (Platform.isAndroid) {
      dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  @override
  Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      throw UpdateServiceDownloadError('Download failed: $e', e);
    }
  }

  @override
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Deletion failure should never block the update flow.
    }
  }

  @override
  Future<void> install(String filePath) async {
    if (Platform.isAndroid) {
      await _installApk(filePath);
    } else if (Platform.isWindows) {
      await _runWindowsInstaller(filePath);
    } else {
      throw UpdateServiceInstallError(
        'In-app update is not supported on this platform',
      );
    }
  }

  /// Requests the install-unknown-apps permission, then launches the system package installer.
  Future<void> _installApk(String filePath) async {
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      throw const UpdateServicePermissionDenied('未授予"安装未知应用"权限，无法安装更新');
    }

    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw UpdateServiceInstallError('无法调起安装器: ${result.message}');
    }
  }

  /// Launches the Inno Setup installer in silent mode.
  Future<void> _runWindowsInstaller(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw UpdateServiceInstallError('安装包不存在: $filePath');
    }
    try {
      await Process.start(filePath, [
        '/SILENT',
        '/FORCECLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
    } catch (e) {
      throw UpdateServiceInstallError('无法启动安装程序: $e', e);
    }
  }
}
