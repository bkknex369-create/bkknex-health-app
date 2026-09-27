import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_events.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../domain/repositories/ai_repository.dart';

enum _Role { user, assistant, notice }

class _ChatMessage {
  const _ChatMessage(this.role, this.text, {this.requiresProfessionalCare = false});

  final _Role role;
  final String text;
  final bool requiresProfessionalCare;
}

/// Contract 1 integration: the one screen in this app that calls the Worker
/// (`bkknex-worker`) `/api/ai/chat` route end-to-end. No health values are
/// sent as free context yet (Phase 3 keeps the payload minimal — {}); the
/// Worker still enforces the 11-field allow-list independently.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _analytics = AnalyticsService();

  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;
  bool _startedAnalyticsFired = false;
  String? _conversationId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    if (!_startedAnalyticsFired) {
      _startedAnalyticsFired = true;
      unawaited(_analytics.capture(AnalyticsEvent.aiChatStarted));
    }

    setState(() {
      _messages.add(_ChatMessage(_Role.user, text));
      _controller.clear();
      _sending = true;
    });

    try {
      final response = await context.read<AiRepository>().chat({
        if (_conversationId != null) 'conversationId': _conversationId,
        'message': text,
        'healthContext': const <String, dynamic>{},
      });

      if (!mounted) return;

      final reply = response['reply'] as String? ??
          'Sorry, I could not generate a reply. Please try again.';
      final safetyFlag = response['safetyFlag'] as Map<String, dynamic>?;
      final requiresCare = safetyFlag?['requiresProfessionalCare'] == true;
      _conversationId = response['conversationId'] as String? ?? _conversationId;

      setState(() {
        _messages.add(_ChatMessage(
          _Role.assistant,
          reply,
          requiresProfessionalCare: requiresCare,
        ));
      });
    } on AiRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          _Role.notice,
          e.retryable
              ? 'The AI service is temporarily unavailable. Please try again.'
              : 'Something went wrong with that request: ${e.message}',
        ));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const _ChatMessage(
          _Role.notice,
          'Could not reach the AI service. Check your connection and try again.',
        ));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask AI')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ask a question about your wellness, sleep, activity, '
                        'or nutrition. This is not a substitute for '
                        'professional medical advice.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const Key('aiChatMessageList'),
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: _messages[index]),
                  ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                label: 'Waiting for AI reply',
                child: const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('aiChatInputField'),
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        labelText: 'Ask a question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('aiChatSendButton'),
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    final isNotice = message.role == _Role.notice;
    final theme = Theme.of(context);

    final String semanticPrefix = switch (message.role) {
      _Role.user => 'You said',
      _Role.assistant => 'Assistant replied',
      _Role.notice => 'Notice',
    };

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        label: '$semanticPrefix: ${message.text}',
        child: ExcludeSemantics(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: isNotice
                  ? theme.colorScheme.errorContainer
                  : isUser
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text),
                if (message.requiresProfessionalCare) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Please consider speaking with a healthcare professional.',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
