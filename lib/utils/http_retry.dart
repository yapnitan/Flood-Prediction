import 'package:http/http.dart' as http;

Future<http.Response> getWithRetry(
  Uri uri, {
  Duration timeout = const Duration(seconds: 8),
  int retries = 1,
  Duration retryDelay = const Duration(milliseconds: 500),
}) async {
  Object lastError = 'no attempts made';
  for (var attempt = 0; attempt <= retries; attempt++) {
    try {
      final response = await http.get(uri).timeout(timeout);
      final code = response.statusCode;
      if (code == 200 || (code < 500 && code != 429)) return response;
      lastError = 'HTTP $code';
    } catch (error) {
      lastError = error;
    }
    if (attempt < retries) await Future<void>.delayed(retryDelay);
  }
  throw Exception('Request to ${uri.host} failed after ${retries + 1} '
      'attempt(s): $lastError');
}
