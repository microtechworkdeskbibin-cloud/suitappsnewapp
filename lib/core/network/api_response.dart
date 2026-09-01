/// Standard result wrapper for network and repository operations.
class ApiResponse<T> {
  const ApiResponse.success(this.data)
      : error = null,
        statusCode = null;

  const ApiResponse.failure(this.error, {this.statusCode}) : data = null;

  final T? data;
  final String? error;
  final int? statusCode;

  bool get isSuccess => error == null;
}
