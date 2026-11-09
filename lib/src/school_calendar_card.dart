import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'school_calendar_data.dart';

class SchoolCalendarCard extends StatefulWidget {
  const SchoolCalendarCard({
    super.key,
    required this.schoolId,
    required this.calendar,
    required this.onSaveCalendar,
    this.today,
    this.readIcs,
  });

  final String schoolId;
  final ImportedSchoolCalendar? calendar;
  final Future<void> Function(ImportedSchoolCalendar?) onSaveCalendar;
  final DateTime? today;
  final Future<String?> Function()? readIcs;

  @override
  State<SchoolCalendarCard> createState() => _SchoolCalendarCardState();
}

class _SchoolCalendarCardState extends State<SchoolCalendarCard> {
  late DateTime _selected = DateUtils.dateOnly(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant SchoolCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) {
      _selected = DateUtils.dateOnly(widget.today ?? DateTime.now());
      _month = DateTime(_selected.year, _selected.month);
    }
  }

  Future<String?> _readFile() async {
    // A user-selected local file works on web and native without sending a
    // private subscription URL to a third-party proxy or embedding an API key.
    // https://pub.dev/packages/file_selector#open-a-single-file
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'iCalendar',
          extensions: ['ics'],
          mimeTypes: ['text/calendar'],
          uniformTypeIdentifiers: [
            'com.apple.ical.ics',
            'public.calendar-event',
          ],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > maxCalendarBytes) {
      throw const CalendarImportException(
        'Choose a calendar smaller than 512 KB.',
      );
    }
    return file.readAsString();
  }

  Future<void> _import() async {
    if (_busy) return;
    final save = widget.onSaveCalendar;
    setState(() => _busy = true);
    try {
      final text = await (widget.readIcs ?? _readFile)();
      if (text == null || !mounted) return;
      final calendar = ImportedSchoolCalendar.parse(text);
      await save(calendar);
      if (!mounted) return;
      final today = DateUtils.dateOnly(widget.today ?? DateTime.now());
      final target = calendarEventsOn(calendar.events, today).isNotEmpty
          ? today
          : calendar.events
                    .where((e) => !e.start.isBefore(today))
                    .firstOrNull
                    ?.start ??
                calendar.events.lastOrNull?.start ??
                today;
      setState(() {
        _selected = DateUtils.dateOnly(target);
        _month = DateTime(target.year, target.month);
      });
    } on CalendarImportException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Could not save this calendar. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useSamples() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSaveCalendar(null);
    } catch (_) {
      if (mounted) {
        _showError('Could not reset this calendar. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  void _moveMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selected = _month;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = MaterialLocalizations.of(context);
    final today = DateUtils.dateOnly(widget.today ?? DateTime.now());
    final events =
        widget.calendar?.events ??
        sampleCalendarEvents(widget.schoolId, _month);
    final selectedEvents = calendarEventsOn(events, _selected);
    final offset = DateUtils.firstDayOffset(_month.year, _month.month, l10n);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);

    return Card(
      key: const ValueKey('school-calendar'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'School calendar',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Import calendar',
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.file_upload_outlined),
                ),
                if (widget.calendar != null)
                  IconButton(
                    tooltip: 'Use sample calendar',
                    onPressed: _busy ? null : _useSamples,
                    icon: const Icon(Icons.restart_alt),
                  ),
              ],
            ),
            Text(
              widget.calendar == null
                  ? 'Sample events'
                  : 'Imported calendar · ${widget.calendar!.events.length} '
                        '${widget.calendar!.events.length == 1 ? 'event' : 'events'}',
              key: const ValueKey('calendar-source'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _moveMonth(-1),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    l10n.formatMonthYear(_month),
                    key: const ValueKey('calendar-month'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _moveMonth(1),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selected = today;
                    _month = DateTime(today.year, today.month);
                  }),
                  child: const Text('Today'),
                ),
              ],
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.narrowWeekdays[(l10n.firstDayOfWeekIndex + i) % 7],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 264,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 44,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final day = index - offset + 1;
                  if (day < 1 || day > days) return const SizedBox.shrink();
                  final date = DateTime(_month.year, _month.month, day);
                  final selected = DateUtils.isSameDay(date, _selected);
                  final isToday = DateUtils.isSameDay(date, today);
                  final count = calendarEventsOn(events, date).length;
                  return Semantics(
                    label:
                        '${l10n.formatFullDate(date)}, $count ${count == 1 ? 'event' : 'events'}',
                    selected: selected,
                    button: true,
                    excludeSemantics: true,
                    child: TextButton(
                      key: ValueKey(
                        'calendar-day-${date.year}-${date.month}-${date.day}',
                      ),
                      onPressed: () => setState(() => _selected = date),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: selected ? colors.primary : null,
                        foregroundColor: selected
                            ? colors.onPrimary
                            : colors.onSurface,
                        shape: CircleBorder(
                          side: BorderSide(
                            color: isToday && !selected
                                ? colors.primary
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day'),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 4,
                            width: 4,
                            child: count == 0
                                ? null
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? colors.onPrimary
                                          : colors.primary,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Semantics(
              header: true,
              child: Text(
                l10n.formatFullDate(_selected),
                key: const ValueKey('calendar-selected-day'),
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 10),
            if (selectedEvents.isEmpty)
              Text(
                'No events on this day.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            for (final event in selectedEvents)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 68,
                      child: Text(
                        event.allDay
                            ? 'All day'
                            : l10n.formatTimeOfDay(
                                TimeOfDay.fromDateTime(event.start),
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (event.location.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
