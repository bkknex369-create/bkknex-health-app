import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../domain/repositories/ai_repository.dart';

/// Calls only the documented Worker routes (contract 1). No vendor name,
/// API key, or provider branching lives here — that is Worker B's
/// responsibility inside `bkknex-worker`. Every call is authenticated with
/// the caller's own Supabase session token; the Worker verifies it
/// cryptographically before touching a provider.
class HttpAiRepository implements AiRepository {
  HttpAiRepository(this._supabase, {http.Client? client})
      : _client = client ?? http.Client();

  final SupabaseClient _supabase;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>> chat(Map<String, dynamic> requestBody) =>
      _post('/api/ai/chat', requestBody);

  @override
  Future<Map<String, dynamic>> insight(Map<String, dynamic> requestBody) =>
      _post('/api/ai/insight', requestBody);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    final response = await _client.post(
      Uri.parse('${Env.workerBaseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AiRepositoryException(
        message: 'Unexpected response from the AI service.',
        code: 'invalid_response',
        retryable: false,
      );
    }

    if (response.statusCode >= 400) {
      throw AiRepositoryException(
        message: decoded['error'] as String? ?? 'AI request failed.',
        code: decoded['code'] as String? ?? 'unknown_error',
        retryable: decoded['retryable'] as bool? ?? false,
      );
    }

    return decoded;
  }
}
