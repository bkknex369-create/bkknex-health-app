import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bkknex_health_app/domain/repositories/ai_repository.dart';
import 'package:bkknex_health_app/presentation/screens/ai_chat/ai_chat_screen.dart';

import 'support/fake_repositories.dart';

Widget _wrap(AiRepository repo) => MaterialApp(
      home: Provider<AiRepository>.value(
        value: repo,
        child: const AiChatScreen(),
      ),
    );

void main() {
  testWidgets('sending a message shows the reply from the Worker',
      (tester) async {
    final repo = FakeAiRepository()
      ..chatResponse = {
        'reply': 'Try drinking more water today.',
        'conversationId': 'conv-1',
      };

    await tester.pumpWidget(_wrap(repo));
    await tester.enterText(
      find.byKey(const Key('aiChatInputField')),
      'How am I doing today?',
    );
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(find.text('How am I doing today?'), findsOneWidget);
    expect(find.text('Try drinking more water today.'), findsOneWidget);
    expect(repo.chatRequests, hasLength(1));
    expect(repo.chatRequests.single['message'], 'How am I doing today?');
    expect(repo.chatRequests.single.containsKey('healthContext'), isTrue);
  });

  testWidgets('surfaces the professional-care notice when flagged',
      (tester) async {
    final repo = FakeAiRepository()
      ..chatResponse = {
        'reply': 'That sounds serious.',
        'safetyFlag': {'requiresProfessionalCare': true},
      };

    await tester.pumpWidget(_wrap(repo));
    await tester.enterText(
      find.byKey(const Key('aiChatInputField')),
      'I have chest pain',
    );
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Please consider speaking with a healthcare professional.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a retry notice for a retryable AiRepositoryException',
      (tester) async {
    final repo = FakeAiRepository()
      ..chatError = const AiRepositoryException(
        message: 'upstream timeout',
        code: 'upstream_unavailable',
        retryable: true,
      );

    await tester.pumpWidget(_wrap(repo));
    await tester.enterText(
      find.byKey(const Key('aiChatInputField')),
      'Hello',
    );
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('The AI service is temporarily unavailable. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('does not send an empty message', (tester) async {
    final repo = FakeAiRepository();

    await tester.pumpWidget(_wrap(repo));
    await tester.tap(find.byKey(const Key('aiChatSendButton')));
    await tester.pumpAndSettle();

    expect(repo.chatRequests, isEmpty);
    expect(find.byKey(const Key('aiChatMessageList')), findsNothing);
  });
}
