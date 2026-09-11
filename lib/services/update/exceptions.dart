class UpdateServiceException implements Exception {
  final String message;

  const UpdateServiceException(this.message);

  @override
  String toString() => 'UpdateServiceException: $message';
}

class UpdateServiceDownloadError extends UpdateServiceException {
  final Object? cause;

  UpdateServiceDownloadError(super.message, [this.cause]);

  @override
  String toString() =>
      'UpdateServiceDownloadError: $message\nCaused by: $cause';
}

class UpdateServiceInstallError extends UpdateServiceException {
  final Object? cause;

  UpdateServiceInstallError(super.message, [this.cause]);

  @override
  String toString() => 'UpdateServiceInstallError: $message\nCaused by: $cause';
}

class UpdateServicePermissionDenied extends UpdateServiceException {
  const UpdateServicePermissionDenied(super.message);
}
