import 'package:http/http.dart' as http;

/// `http.get` with a bounded timeout and one automatic retry on a network
/// error, a timeout, an HTTP 429, or a 5xx. The keyless Open-Meteo endpoints
/// occasionally drop a request or rate-limit a burst of them; a single quick
/// retry clears most of that, which is why the Home badge would otherwise
/// intermittently show "Unavailable" for rainfall/weather.
///
/// Throws (rather than returning null) when every attempt fails — callers
/// keep their existing `try`/`catch` that maps a failure to a null result.
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
      // Success, or a client error that a retry can't fix (except 429).
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
