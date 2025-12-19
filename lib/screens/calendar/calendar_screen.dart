import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/auth_service.dart';
import '../../core/services/logger_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';
import '../../widgets/swipeable_list_item.dart';
import '../../widgets/context_menu.dart';
import '../../widgets/toast_notification.dart';
import '../../services/undo_service.dart';
import 'add_edit_event_screen.dart';
import 'event_details_screen.dart';
import 'gantt_chart_screen.dart';
import 'event_templates_screen.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const CalendarScreen({super.key, this.initialDate});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  final CalendarSyncService _syncService = CalendarSyncService();
  final AuthService _authService = AuthService();
  final UndoService _undoService = UndoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<CalendarEvent>> _eventsMap = {};
  Map<String, bool> _eventSyncStatus = {}; // eventId -> isSynced
  String _searchQuery = '';
  List<CalendarEvent> _allEvents = [];
  bool _isSearchVisible = false;

  StreamSubscription<List<CalendarEvent>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _focusedDay = widget.initialDate!;
      _selectedDay = widget.initialDate!;
    }
    _setupEventsListener();
  }

  void _setupEventsListener() {
    // Use Firestore stream for real-time updates
    // This automatically refreshes when events are added/updated/deleted (e.g., after sync)
    _eventsSubscription = _calendarService.getEventsStream().listen(
      (events) {
        if (mounted) {
          setState(() {
            _allEvents = events;
            _eventsMap = _groupEventsByDate(_getFilteredEvents());
          });
          // Check sync status for events
          _checkEventSyncStatus(events);
        }
      },
      onError: (error) {
        Logger.error('Error in events stream', error: error, tag: 'CalendarScreen');
        if (mounted) {
          setState(() {
            _allEvents = [];
            _eventsMap = {};
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Removed _loadEvents() - now using Firestore streams for real-time updates
  // Events automatically refresh when sync completes or events are added/updated/deleted

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
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                  _eventsMap = _groupEventsByDate(_getFilteredEvents());
                }
              });
            },
            tooltip: _isSearchVisible ? 'Close search' : 'Search events',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EventTemplatesScreen(),
                ),
              );
            },
            tooltip: 'Event Templates',
          ),
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
          IconButton(
            icon: const Icon(Icons.timeline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GanttChartScreen(initialDate: _selectedDay),
                ),
              );
            },
            tooltip: 'Day View (Gantt Chart)',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar - shown/hidden based on state
          if (_isSearchVisible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _eventsMap = _groupEventsByDate(_getFilteredEvents());
                              _isSearchVisible = false; // Hide search bar when cleared
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _eventsMap = _groupEventsByDate(_getFilteredEvents());
                    // Hide search bar if text is cleared
                    if (value.isEmpty) {
                      _isSearchVisible = false;
                    }
                  });
                },
              ),
            ),
          // Calendar and events - scrollable together
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Calendar - let it size naturally
                  TableCalendar<CalendarEvent>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => app_date_utils.AppDateUtils.isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
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
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return const SizedBox.shrink();
                        return Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            padding: events.length > 1 
                                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                                : const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: events.length > 1
                                ? Text(
                                    '${events.length}',
                                    style: const TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  // Events list - not expanded, just takes what it needs
                  _buildEventsList(),
                ],
              ),
            ),
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
          // No need to manually reload - Firestore stream will automatically update
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventsList() {
    // When searching, show all matching events; otherwise show events for selected day
    final List<CalendarEvent> eventsToShow;
    if (_searchQuery.isNotEmpty) {
      eventsToShow = _getFilteredEvents();
    } else {
      eventsToShow = _getEventsForDay(_selectedDay);
    }
    
    if (eventsToShow.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        title: _searchQuery.isNotEmpty ? 'No matching events' : 'No events',
        message: _searchQuery.isNotEmpty
            ? 'No events match "$_searchQuery"'
            : 'No events for ${app_date_utils.AppDateUtils.formatDate(_selectedDay)}',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: eventsToShow.length,
      itemBuilder: (context, index) {
        final event = eventsToShow[index];
        final currentUserId = _auth.currentUser?.uid;
        final canEdit = event.eventOwnerId == currentUserId || 
                       event.createdBy == currentUserId;
        final canDelete = canEdit;
        
        // Swipe actions
        final List<SwipeAction> leftActions = [];
        final List<SwipeAction> rightActions = [];
        
        if (canDelete) {
          leftActions.add(
            SwipeAction(
              label: 'Delete',
              icon: Icons.delete,
              color: Colors.red,
              onTap: () => _deleteEventWithUndo(event),
            ),
          );
        }
        
        if (canEdit) {
          rightActions.add(
            SwipeAction(
              label: 'Edit',
              icon: Icons.edit,
              color: Colors.blue,
              onTap: () => _editEvent(event),
            ),
          );
        }
        
        return ContextMenu(
          actions: [
            if (canEdit)
              ContextMenuAction(
                label: 'Edit',
                icon: Icons.edit,
                onTap: () => _editEvent(event),
              ),
            if (canDelete)
              ContextMenuAction(
                label: 'Delete',
                icon: Icons.delete,
                color: Colors.red,
                onTap: () => _deleteEventWithUndo(event),
              ),
            ContextMenuAction(
              label: 'View Details',
              icon: Icons.info,
              onTap: () => _viewEventDetails(event),
            ),
          ],
          child: SwipeableListItem(
            leftActions: leftActions,
            rightActions: rightActions,
            onTap: () => _viewEventDetails(event),
            child: ModernCard(
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
                // Show sync icon if event was synced from external calendar
                if (event.sourceCalendar != null && event.sourceCalendar!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.sync,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                ],
                // Show calendar icon if synced to device calendar
                if (_eventSyncStatus[event.id] == true) ...[
                  const SizedBox(width: 4),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                if (canEdit)
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
                if (canDelete)
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
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 20),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  _editEvent(event);
                } else if (value == 'delete') {
                  _deleteEventWithUndo(event);
                } else if (value == 'details') {
                  _viewEventDetails(event);
                }
              },
            ),
          ),
          ),
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

  Future<void> _editEvent(CalendarEvent event) async {
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
    // No need to manually reload - Firestore stream will automatically update
  }

  Future<void> _viewEventDetails(CalendarEvent event) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventDetailsScreen(event: event),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    // No need to manually reload - Firestore stream will automatically update
  }

  Future<void> _deleteEventWithUndo(CalendarEvent event) async {
    try {
      // Store event data for undo
      final eventData = event;
      
      // Delete the event
      await _calendarService.deleteEvent(event.id);
      
      // Register undo action
      _undoService.registerUndoableAction(
        'delete_event_${event.id}',
        () async {
          try {
            await _calendarService.addEvent(eventData);
            ToastNotification.success(context, 'Event restored');
          } catch (e) {
            ToastNotification.error(context, 'Error restoring event: $e');
          }
        },
      );
      
      // Show undo snackbar
      _undoService.showUndoSnackbar(
        context,
        message: 'Event deleted',
        actionId: 'delete_event_${event.id}',
      );
      
      ToastNotification.success(context, 'Event deleted');
    } catch (e) {
      ToastNotification.error(context, 'Error deleting event: $e');
    }
  }
}
