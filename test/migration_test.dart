import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:image/image.dart' as img;
import 'package:compass_flutter/src/api.dart';
import 'package:compass_flutter/src/data.dart';
import 'package:compass_flutter/src/store.dart';
import 'package:compass_flutter/src/planner.dart';
import 'package:compass_flutter/src/photos.dart';
import 'package:compass_flutter/src/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  test('Server and school feed URLs keep credentials on intended hosts', () {
    for (final url in [
      'https://u:p@example.com',
      'http://example.com',
      'https://example.com/?token=x',
    ]) {
      expect(() => CampusApi.validate(url), throwsA(isA<ApiException>()));
    }
    expect(CampusApi.validate('http://127.0.0.1:18764').host, '127.0.0.1');
    for (final url in [
      'https://buckley.myschoolapp.com.evil.test/podium/feed/ical.aspx?z=x',
      'http://buckley.myschoolapp.com/podium/feed/ical.aspx?z=x',
      'https://buckley.myschoolapp.com/podium/feed/ical.aspx',
    ]) {
      expect(() => CalendarParser.validate(url), throwsA(isA<ApiException>()));
    }
  });
  test('Calendar preserves due dates, revisions, cancellations, notes and folded text', () {
    final entries = CalendarParser.parse(
      'BEGIN:VCALENDAR\r\nX-WR-TIMEZONE:America/Los_Angeles\r\nBEGIN:VEVENT\r\nUID:a\r\nSUMMARY:Biology - Quiz\r\nDESCRIPTION:Part one\\nPart two\r\n continued\r\nDTSTART;VALUE=DATE:20261014\r\nDTEND;VALUE=DATE:20261016\r\nRRULE:FREQ=WEEKLY\r\nEND:VEVENT\r\nBEGIN:VTODO\r\nUID:b\r\nSEQUENCE:0\r\nSUMMARY:Old assignment\r\nDUE;TZID=America/Los_Angeles:20261015T153000\r\nEND:VTODO\r\nBEGIN:VTODO\r\nUID:b\r\nSEQUENCE:1\r\nSUMMARY:History - Essay\r\nDUE;TZID=America/Los_Angeles:20261016T153000\r\nEND:VTODO\r\nBEGIN:VEVENT\r\nUID:c\r\nSTATUS:CANCELLED\r\nSUMMARY:Canceled\r\nEND:VEVENT\r\nEND:VCALENDAR',
    );
    expect(entries.length, 2);
    final a = entries.firstWhere((e) => e['id'] == 'a|');
    final b = entries.firstWhere((e) => e['id'] == 'b|');
    expect(DateTime.parse(a['due'] as String).day, 15);
    expect(a['details'], 'Part one\nPart twocontinued');
    expect(text(a, 'note'), contains('Recurring'));
    expect(b['title'], 'History - Essay');
    expect(DateTime.parse(b['due'] as String).toUtc().hour, 22);
    expect(
      () =>
          CalendarParser.parse('BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR'),
      throwsA(isA<ApiException>()),
    );
  });
  test(
    'Photo conversion matches original backend limits and strips PNG encoding',
    () {
      final source = img.Image(width: 2400, height: 1700);
      final jpeg = preparePhoto(Uint8List.fromList(img.encodePng(source)));
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, lessThanOrEqualTo(1600));
      expect(jpeg.length, lessThanOrEqualTo(512 * 1024));
      expect(jpeg.take(2), [255, 216]);
    },
  );
  testWidgets(
    'Demo user can publish, reply, chat and reopen local data at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance(),
          store = CampusStore(await SharedPreferences.getInstance());
      store.restoring = false;
      await tester.pumpWidget(
        CompassApp(store: store, planner: PlannerStore(prefs)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore the demo'));
      await tester.pumpAndSettle();
      expect(find.text('Latest posts'), findsOneWidget);
      await tester.tap(find.byTooltip('Create a post'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Migration test question',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Details'),
        'Does this Flutter port save posts?',
      );
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(store.posts.first['title'], 'Migration test question');
      await store.reply(
        text(store.posts.first, 'id'),
        'A locally saved reply.',
      );
      final chat = await store.startChat(demoAlex);
      await store.send(text(chat, 'id'), 'Demo message');
      final restored = CampusStore(prefs);
      await restored.enterDemo();
      expect(restored.posts.first['replies'], hasLength(1));
      expect(
        messagePreview(rows(restored.chats.first['messages']).last),
        'Demo message',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      restored.dispose();
    },
  );
}
