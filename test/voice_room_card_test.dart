import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katsklub_flutter/models/voice_room.dart';
import 'package:katsklub_flutter/widgets/voice_room_card.dart';

VoiceRoom _fakeRoom({String coverUrl = '', String avatarUrl = ''}) {
  return VoiceRoom(
    id: 1,
    roomCode: 'room-test',
    title: 'Tulog na kayo',
    description: '',
    category: 'Chill',
    theme: 'cosmic_night',
    coverUrl: coverUrl,
    maxSeats: 8,
    occupiedSeatsCount: 2,
    host: VoiceRoomUser(
      id: 10,
      username: 'orion_varyn',
      fullName: 'Orion Varyn',
      avatarUrl: avatarUrl,
    ),
    seats: const [],
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  VoiceRoom room, {
  VoidCallback? onTap,
}) {
  // Match the app design size so ScreenUtil scales 1:1 like on a real phone.
  tester.view.physicalSize = const Size(360, 690);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          // Full-width box: widget-test fonts measure wider than Roboto on
          // device, so a narrow box would overflow for reasons unrelated to
          // the card. The card itself is width-agnostic.
          body: SizedBox(
            width: 360,
            height: 200,
            child: VoiceRoomCard(room: room, onTap: onTap ?? () {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('VoiceRoomCard', () {
    testWidgets('shows room title, host, category and mics badge',
        (tester) async {
      await _pumpCard(tester, _fakeRoom());

      expect(find.text('Tulog na kayo'), findsOneWidget);
      expect(find.text('Orion Varyn'), findsOneWidget);
      expect(find.text('Chill'), findsOneWidget);
      expect(find.text('2/8'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var tapped = 0;
      await _pumpCard(tester, _fakeRoom(), onTap: () => tapped++);

      await tester.tap(find.byType(VoiceRoomCard));
      expect(tapped, 1);
    });

    testWidgets('is isolated in a RepaintBoundary for smooth scrolling',
        (tester) async {
      await _pumpCard(tester, _fakeRoom());

      expect(
        find.descendant(
          of: find.byType(VoiceRoomCard),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses no ClipRRect (no full-card saveLayer while scrolling)',
        (tester) async {
      await _pumpCard(tester, _fakeRoom());

      expect(
        find.descendant(
          of: find.byType(VoiceRoomCard),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });

    testWidgets('downscales cover and avatar on decode', (tester) async {
      // Unreachable URLs fail fast (connection refused) and are handled by
      // the image widget internally; the test only checks decode config.
      await _pumpCard(
        tester,
        _fakeRoom(
          coverUrl: 'https://localhost:1/cover.webp',
          avatarUrl: 'https://localhost:1/avatar.webp',
        ),
      );

      final images = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .toList();
      expect(images.length, 2);
      for (final img in images) {
        expect(img.memCacheWidth, isNotNull,
            reason: 'every lobby image must be downscaled on decode');
      }
    });
  });
}
