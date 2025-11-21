import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/auth_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'add_edit_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  final CalendarSyncService _syncService = CalendarSyncService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<CalendarEvent>> _eventsMap = {};
  Map<String, bool> _eventSyncStatus = {}; // eventId -> isSynced
  String _searchQuery = '';
  List<CalendarEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final events = await _calendarService.getEvents();
    setState(() {
      _allEvents = events;
      _eventsMap = _groupEventsByDate(_getFilteredEvents());
    });
    
    // Check sync status for events
    _checkEventSyncStatus(events);
  }

  List<CalendarEvent> _getFilteredEvents() {
    if (_searchQuery.isEmpty) {
      return _allEvents;
    }
    
    final query = _searchQuery.toLowerCase();
    return _allEvents.where((event) {
      final titleMatch = event.title.toLowerCase().contains(query);
      final descMatch = (event.description ?? '').toLowerCase().contains(query);
      return titleMatch || descMatch;
    }).toList();
  }

  Future<void> _checkEventSyncStatus(List<CalendarEvent> events) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.calendarSyncEnabled != true || userModel?.localCalendarId == null) {
        return;
      }

      final syncStatus = <String, bool>{};
      for (var event in events) {
        final exists = await _syncService.eventExistsInDevice(
          userModel!.localCalendarId!,
          event.id,
        );
        syncStatus[event.id] = exists;
      }

      if (mounted) {
        setState(() {
          _eventSyncStatus = syncStatus;
        });
      }
    } catch (e) {
      // Silently fail - sync status check is non-critical
    }
  }

  Map<DateTime, List<CalendarEvent>> _groupEventsByDate(
    List<CalendarEvent> events,
  ) {
    final Map<DateTime, List<CalendarEvent>> map = {};
    for (final event in events) {
      final date = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      map.putIfAbsent(date, () => []).add(event);
    }
    return map;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _eventsMap[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
            tooltip: 'Go to today',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _eventsMap = _groupEventsByDate(_getFilteredEvents());
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _eventsMap = _groupEventsByDate(_getFilteredEvents());
                });
              },
            ),
          ),
          TableCalendar<CalendarEvent>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => app_date_utils.AppDateUtils.isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const Divider(),
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar-fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AddEditEventScreen(selectedDate: _selectedDay),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
          if (result == true) {
            _loadEvents();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventsList() {
    final dayEvents = _getEventsForDay(_selectedDay);
    
    if (dayEvents.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        title: 'No events',
        message: 'No events for ${app_date_utils.AppDateUtils.formatDate(_selectedDay)}',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        final event = dayEvents[index];
        return ModernCard(
          margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 4,
              decoration: BoxDecoration(
                color: _parseColor(event.color),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_eventSyncStatus[event.id] == true) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.green[700],
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${app_date_utils.AppDateUtils.formatTime(event.startTime)} - ${app_date_utils.AppDateUtils.formatTime(event.endTime)}',
                ),
                if (event.location != null && event.location!.isNotEmpty)
                  Text('📍 ${event.location}'),
                if (event.isRecurring) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.repeat, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatRecurrence(event.recurrenceRule ?? ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          AddEditEventScreen(event: event),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                  if (result == true) {
                    _loadEvents();
                  }
                } else if (value == 'delete') {
                  await _calendarService.deleteEvent(event.id);
                  _loadEvents();
                }
              },
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      AddEditEventScreen(event: event),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
              if (result == true) {
                _loadEvents();
              }
            },
          ),
        );
      },
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  String _formatRecurrence(String rule) {
    switch (rule.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return rule;
    }
  }
}
