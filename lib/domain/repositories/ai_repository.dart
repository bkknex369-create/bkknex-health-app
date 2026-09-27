/// Contract 1 (AI provider abstraction): the Flutter client only ever calls
/// these routes on the Worker (`bkknex-worker`, owned by Worker B). No
/// vendor name, provider branching, or voice-vendor logic belongs here or
/// anywhere else in this app — that all lives server-side on the Worker.
abstract class AiRepository {
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody);
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody);
}

/// Mirrors the Worker's `ApiError` shape (`error`, `code`, `retryable`) so
/// the UI can distinguish "try again" from "something is broken" without
/// parsing response bodies itself.
class AiRepositoryException implements Exception {
  const AiRepositoryException({
    required this.message,
    required this.code,
    required this.retryable,
  });

  final String message;
  final String code;
  final bool retryable;

  @override
  String toString() => 'AiRepositoryException($code, retryable: $retryable): $message';
}
