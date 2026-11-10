import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'live_calendar_service.dart';
import 'school_calendar_data.dart';

enum CalendarView { month, week, day }

class SchoolCalendarCard extends StatefulWidget {
  const SchoolCalendarCard({
    super.key,
    required this.schoolId,
    required this.calendar,
    required this.onSaveCalendar,
    this.today,
    this.readIcs,
    this.promptOnOpen = false,
    this.onPrompted,
    this.fetchCalendar,
  });
  final String schoolId;
  final ImportedSchoolCalendar? calendar;
  final Future<void> Function(ImportedSchoolCalendar?) onSaveCalendar;
  final DateTime? today;
  final Future<String?> Function()? readIcs;
  final bool promptOnOpen;
  final Future<void> Function()? onPrompted;
  final Future<ImportedSchoolCalendar> Function(String)? fetchCalendar;
  @override
  State<SchoolCalendarCard> createState() => _SchoolCalendarCardState();
}

class _SchoolCalendarCardState extends State<SchoolCalendarCard> {
  late DateTime _selected = DateUtils.dateOnly(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  CalendarView _view = CalendarView.month;
  bool _busy = false, _all = false;
  String? _error;
  Timer? _refreshTimer;
  AppLifecycleListener? _lifecycle;
  Future<ImportedSchoolCalendar> _fetch(String url) =>
      (widget.fetchCalendar ?? const LiveCalendarService().fetch)(url);
  List<SchoolCalendarEvent> get _events =>
      widget.calendar?.events ?? sampleCalendarEvents(widget.schoolId, _month);
  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _refresh(),
    );
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.promptOnOpen && widget.calendar?.subscriptionUrl == null) {
        widget.onPrompted?.call().catchError((_) {});
        _connect();
      } else if (widget.calendar?.subscriptionUrl != null) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SchoolCalendarCard old) {
    super.didUpdateWidget(old);
    if (old.schoolId != widget.schoolId) {
      _selected = DateUtils.dateOnly(widget.today ?? DateTime.now());
      _month = DateTime(_selected.year, _selected.month);
      _error = null;
    }
  }

  Future<void> _refresh() async {
    final url = widget.calendar?.subscriptionUrl;
    if (url == null || _busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = (await _fetch(url)).withSubscription(url);
      await widget.onSaveCalendar(next);
    } on CalendarImportException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not update. Saved events are still available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _readFile() async {
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
    setState(() => _busy = true);
    try {
      final raw = await (widget.readIcs ?? _readFile)();
      if (raw == null || !mounted) return;
      final next = ImportedSchoolCalendar.parse(raw);
      await widget.onSaveCalendar(next);
      if (mounted) setState(() => _error = null);
    } on CalendarImportException catch (e) {
      if (mounted) showAppError(context, e.message);
    } catch (_) {
      if (mounted) {
        showAppError(
          context,
          'Could not save this calendar. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 580),
    builder: (context) => _CalendarConnection(
      initial: widget.calendar?.subscriptionUrl,
      onConnect: (link) async {
        final uri = normalizeCalendarUrl(link);
        final calendar = (await _fetch(uri.toString()))
            .withSubscription(uri.toString());
        await widget.onSaveCalendar(calendar);
        if (mounted) setState(() => _error = null);
      },
      onImport: () {
        Navigator.pop(context);
        _import();
      },
    ),
  );
  void _move(int delta) => setState(() {
    _all = false;
    if (_view == CalendarView.month) {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = _month;
    } else {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day + delta * (_view == CalendarView.week ? 7 : 1),
      );
      _month = DateTime(_selected.year, _selected.month);
    }
  });
  void _details(SchoolCalendarEvent event) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(event.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text(
              event.allDay
                  ? 'All day'
                  : MaterialLocalizations.of(context)
                        .formatTimeOfDay(TimeOfDay.fromDateTime(event.start)),
            ),
            const SizedBox(height: 8),
            Text(MaterialLocalizations.of(context).formatFullDate(event.start)),
            if (event.end.difference(event.start).inDays > 1)
              Text(
                'Until ${MaterialLocalizations.of(context).formatFullDate(event.allDay ? DateTime(event.end.year, event.end.month, event.end.day - 1) : event.end)}',
              ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(event.location),
            ],
          ],
        ),
      ),
    ),
  );
  Widget _monthGrid(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final offset = DateUtils.firstDayOffset(_month.year, _month.month, l10n);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final count = ((offset + days) / 7).ceil() * 7;
    final today = DateUtils.dateOnly(widget.today ?? DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.narrowWeekdays[(l10n.firstDayOfWeekIndex + i) % 7],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: (count / 7) * 44,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: count,
            itemBuilder: (context, i) {
              final day = i - offset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(_month.year, _month.month, day);
              final selected = DateUtils.isSameDay(date, _selected);
              final events = calendarEventsOn(_events, date).length;
              return Semantics(
                label:
                    '${l10n.formatFullDate(date)}, $events ${events == 1 ? 'event' : 'events'}',
                button: true,
                selected: selected,
                excludeSemantics: true,
                child: TextButton(
                  key: ValueKey(
                    'calendar-day-${date.year}-${date.month}-${date.day}',
                  ),
                  onPressed: () => setState(() {
                    _selected = date;
                    _all = false;
                  }),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    foregroundColor: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: DateUtils.isSameDay(date, today) && !selected
                            ? Theme.of(context).colorScheme.outline
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day'),
                      const SizedBox(height: 3),
                      SizedBox.square(
                        dimension: 3,
                        child: events > 0
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _agenda(List<SchoolCalendarEvent> events) {
    final visible = _all ? events : events.take(4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          MaterialLocalizations.of(context).formatFullDate(_selected),
          key: const ValueKey('calendar-selected-day'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 18),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No events on this day.'),
          ),
        for (final e in visible) ...[
          InkWell(
            onTap: () => _details(e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      e.allDay
                          ? 'All day'
                          : MaterialLocalizations.of(
                              context,
                            ).formatTimeOfDay(TimeOfDay.fromDateTime(e.start)),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (e.location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.location,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
        ],
        if (events.length > 4)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(
              _all ? 'Show less' : 'Show all ${events.length} events',
            ),
          ),
      ],
    );
  }

  Widget _timeline(bool week) {
    final start = week
        ? DateTime(
            _selected.year,
            _selected.month,
            _selected.day - (_selected.weekday - 1),
          )
        : _selected;
    final days = List.generate(
      week ? 7 : 1,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
    double clockMinutes(DateTime value, DateTime day) {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      if (value.isBefore(start)) return 0;
      if (!value.isBefore(end)) return 1440;
      return value.hour * 60.0 + value.minute;
    }

    var firstHour = 8, lastHour = 20;
    for (final day in days) {
      for (final event in calendarEventsOn(
        _events,
        day,
      ).where((e) => !e.allDay)) {
        firstHour = math.min(
          firstHour,
          (clockMinutes(event.start, day) / 60).floor(),
        );
        lastHour = math.max(
          lastHour,
          math.min(24, (clockMinutes(event.end, day) / 60).ceil() + 1),
        );
      }
    }
    final l10n = MaterialLocalizations.of(context);
    final allDay = _events
        .where((e) => e.allDay && days.any(e.occursOn))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (week)
          Padding(
            padding: const EdgeInsets.only(left: 43, bottom: 12),
            child: Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _selected = day;
                        _view = CalendarView.day;
                      }),
                      child: Column(
                        children: [
                          Text(
                            l10n.narrowWeekdays[day.weekday % 7],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: DateUtils.isSameDay(day, _selected)
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              l10n.formatFullDate(_selected),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        if (allDay.isNotEmpty) ...[
          Text('All day', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (!week)
            for (final e in allDay.take(_all ? allDay.length : 3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _details(e),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          if (week)
            Padding(
              padding: const EdgeInsets.only(left: 43, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final d in days)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _selected = d;
                          _view = CalendarView.day;
                        }),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${calendarEventsOn(allDay, d).length}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (!week && allDay.length > 3)
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all ? 'Show less' : 'Show ${allDay.length} all-day events',
              ),
            ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: (lastHour - firstHour) * 44.0 + 16,
          child: LayoutBuilder(
            builder: (context, box) {
              final cell = (box.maxWidth - 43) / days.length;
              return Stack(
                children: [
                  for (var hour = firstHour; hour <= lastHour; hour++)
                    Positioned(
                      top: (hour - firstHour) * 44.0,
                      left: 0,
                      right: 0,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 43,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ),
                  for (var i = 0; i < days.length; i++)
                    Positioned(
                      left: 43 + i * cell,
                      top: 0,
                      bottom: 0,
                      child: VerticalDivider(
                        width: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  for (var i = 0; i < days.length; i++)
                    for (final e in calendarEventsOn(
                      _events,
                      days[i],
                    ).where((e) => !e.allDay))
                      Builder(
                        builder: (context) {
                          final lower = DateTime(
                                days[i].year,
                                days[i].month,
                                days[i].day,
                                firstHour,
                              ),
                              upper = DateTime(
                                days[i].year,
                                days[i].month,
                                days[i].day,
                                lastHour,
                              );
                          final from = e.start.isBefore(lower)
                                  ? lower
                                  : e.start,
                              to = e.end.isAfter(upper) ? upper : e.end;
                          return Positioned(
                            left: 43 + i * cell + 3,
                            width: cell - 5,
                            top:
                                (clockMinutes(from, days[i]) / 60 - firstHour) *
                                44,
                            height: math.max(
                              22,
                              (clockMinutes(to, days[i]) -
                                          clockMinutes(from, days[i])) /
                                      60 *
                                      44 -
                                  2,
                            ),
                            child: Semantics(
                              label: e.title,
                              button: true,
                              child: InkWell(
                                onTap: () => _details(e),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border(
                                      left: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    e.title,
                                    maxLines: week ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: week ? 11 : 14),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return Column(
      key: const ValueKey('school-calendar'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => _move(-1),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                l10n.formatMonthYear(_month),
                key: const ValueKey('calendar-month'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => _move(1),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: _busy ? null : _connect,
              child: Text(
                widget.calendar?.subscriptionUrl != null
                    ? 'Connected'
                    : '+ Connect',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CupertinoSlidingSegmentedControl<CalendarView>(
          groupValue: _view,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          thumbColor: Theme.of(context).colorScheme.surface,
          children: {
            for (final v in CalendarView.values)
              v: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                child: Text(
                  '${v.name[0].toUpperCase()}${v.name.substring(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _view == v
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => _view = v);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.calendar == null
                    ? 'Sample events'
                    : widget.calendar!.subscriptionUrl == null
                    ? 'Imported calendar · ${widget.calendar!.events.length} ${widget.calendar!.events.length == 1 ? 'event' : 'events'}'
                    : 'Updated ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(widget.calendar!.importedAt.toLocal()))} · ${widget.calendar!.events.length} events',
                key: const ValueKey('calendar-source'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _selected = DateUtils.dateOnly(widget.today ?? DateTime.now());
                _month = DateTime(_selected.year, _selected.month);
                _all = false;
              }),
              child: const Text('Today'),
            ),
            if (widget.calendar?.subscriptionUrl != null)
              IconButton(
                tooltip: 'Refresh calendar',
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            PopupMenuButton<String>(
              tooltip: 'Calendar options',
              onSelected: (value) async {
                if (value == 'import') _import();
                if (value == 'samples') {
                  try {
                    await widget.onSaveCalendar(null);
                  } catch (_) {
                    if (context.mounted) {
                      showAppError(context, 'Could not reset this calendar.');
                    }
                  }
                }
                if (value == 'disconnect' && widget.calendar != null) {
                  try {
                    await widget.onSaveCalendar(
                      widget.calendar!.withSubscription(null),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      showAppError(
                        context,
                        'Could not disconnect this calendar.',
                      );
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import calendar'),
                ),
                if (widget.calendar != null)
                  const PopupMenuItem(
                    value: 'samples',
                    child: Text('Use sample calendar'),
                  ),
                if (widget.calendar?.subscriptionUrl != null)
                  const PopupMenuItem(
                    value: 'disconnect',
                    child: Text('Disconnect'),
                  ),
              ],
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 18),
        if (_view == CalendarView.month) ...[
          _monthGrid(context),
          const SizedBox(height: 30),
          _agenda(calendarEventsOn(_events, _selected)),
        ] else
          _timeline(_view == CalendarView.week),
      ],
    );
  }
}

class _CalendarConnection extends StatefulWidget {
  const _CalendarConnection({
    required this.onConnect,
    required this.onImport,
    this.initial,
  });
  final String? initial;
  final Future<void> Function(String) onConnect;
  final VoidCallback onImport;
  @override
  State<_CalendarConnection> createState() => _CalendarConnectionState();
}

class _CalendarConnectionState extends State<_CalendarConnection> {
  late final _url = TextEditingController(text: widget.initial);
  String? _error;
  bool _busy = false, _hidden = true;
  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connect calendar',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 28),
          const Text('Private WebCal URL'),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            obscureText: _hidden,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'webcal://…',
              suffixIcon: IconButton(
                tooltip: _hidden ? 'Show link' : 'Hide link',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _error = null;
                    });
                    try {
                      await widget.onConnect(_url.text);
                      if (context.mounted) Navigator.pop(context);
                    } on CalendarImportException catch (e) {
                      if (mounted) setState(() => _error = e.message);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error =
                              'Could not save this calendar. Please try again.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Connecting…' : 'Connect'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : widget.onImport,
            child: const Text('Import an .ics file instead'),
          ),
        ],
      ),
    ),
  );
}
