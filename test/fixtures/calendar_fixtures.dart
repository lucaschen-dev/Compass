String calendarFixture(String events) =>
    '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Compass//Calendar tests//EN
$events
END:VCALENDAR''';

String allDayEventFixture(
  String title, {
  String date = '20261108',
  String end = '20261109',
  String uid = 'demo-event',
  String extra = '',
}) =>
    '''BEGIN:VEVENT
UID:$uid
DTSTAMP:20260101T000000Z
DTSTART;VALUE=DATE:$date
DTEND;VALUE=DATE:$end
SUMMARY:$title
$extra
END:VEVENT''';

String dayStamp(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
