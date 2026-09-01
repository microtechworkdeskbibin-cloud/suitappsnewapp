import 'package:http/http.dart' as http;

/// Shared HTTP client for feature data sources.
///
/// It is intentionally small so existing data sources can migrate to it
/// incrementally without changing their public APIs.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _client.get(url, headers: headers);

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _client.post(url, headers: headers, body: body);

  void close() => _client.close();
}
