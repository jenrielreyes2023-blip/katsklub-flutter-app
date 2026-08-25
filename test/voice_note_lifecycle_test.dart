import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../lib/services/feed_service.dart';
import '../lib/services/conversation_theme.dart';
import '../lib/screens/messages_screen.dart';

void main() {
  testWidgets('VoiceNotePlayer lifecycle hash test', (WidgetTester tester) async {
    final testAttachment = DirectMessageAttachment(
      url: 'https://media.katsklub.top/messages/message-97f4cc4c-4635-4f56-a18d-b0cc9112ab65.m4a',
      type: 'audio',
      name: 'Voice message (7s).m4a',
      mime: 'audio/mp4',
      size: 121968,
    );

    final theme = ConversationTheme.classic;

    debugPrint('\n=== STARTING FLUTTER WIDGET HARNESS TEST ===');

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                VoiceNotePlayerForTest(
                  key: const ValueKey('https://media.katsklub.top/messages/message-97f4cc4c-4635-4f56-a18d-b0cc9112ab65.m4a'),
                  attachment: testAttachment,
                  sentByMe: true,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    debugPrint('\n=== TAPPING PLAY BUTTON ===');
    final playButton = find.byType(IconButton).first;
    expect(playButton, findsOneWidget);

    await tester.tap(playButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    debugPrint('=== WIDGET HARNESS TEST COMPLETE ===\n');
  });
}
