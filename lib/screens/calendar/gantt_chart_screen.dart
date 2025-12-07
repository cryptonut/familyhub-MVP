import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../models/user_model.dart';
import '../../services/calendar_service.dart';
import '../../services/auth_service.dart';
import '../../core/services/logger_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import 'event_details_screen.dart';

class GanttChartScreen extends StatefulWidget {
  final DateTime? initialDate;
  
  const GanttChartScreen({super.key, this.initialDate});

  @override
  State<GanttChartScreen> createState() => _GanttChartScreenState();
}

class _GanttChartScreenState extends State<GanttChartScreen> {
  final CalendarService _calendarService = CalendarService();
  final AuthService _authService = AuthService();
  
  late DateTime _selectedDate;
  List<CalendarEvent> _events = [];
  List<UserModel> _familyMembers = [];
  Map<String, String> _memberNames = {}; // userId -> displayName
  Map<String, Color> _memberColors = {}; // userId -> color
  bool _isLoading = true;
  
  // Time range for the chart (6 AM to 11 PM)
  static const int _startHour = 6;
  static const int _endHour = 23;
  static const double _rowHeight = 60.0;
  static const double _timeColumnWidth = 80.0;
  static const double _eventLabelWidth = 200.0;
  static const double _hourWidth = 60.0;

  @override
  void initState() {
    super.initState();
    // Don't auto-default to current date - require explicit selection
    _selectedDate = widget.initialDate ?? DateTime.now();
    // If no initial date provided, show date picker immediately
    if (widget.initialDate == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectDate();
      });
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load family members first
      final members = await _authService.getFamilyMembers();
      
      // Generate colors for each member
      final colors = [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.red,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
      ];
      
      final memberNames = <String, String>{};
      final memberColors = <String, Color>{};
      
      for (int i = 0; i < members.length; i++) {
        memberNames[members[i].uid] = members[i].displayName;
        memberColors[members[i].uid] = colors[i % colors.length];
      }
      
      // Load events for selected date
      final events = await _calendarService.getEventsForDate(_selectedDate);
      
      // Sort events by start time
      events.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      if (mounted) {
        setState(() {
          _familyMembers = members;
          _memberNames = memberNames;
          _memberColors = memberColors;
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      Logger.error('Error loading Gantt chart data', error: e, stackTrace: st, tag: 'GanttChartScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      // Add event indicators - we'll need to load events first
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadData();
    } else if (widget.initialDate == null) {
      // If user cancelled and no initial date was provided, go back
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// Get all participants for an event (invited members with "going" RSVP + event owner)
  /// Event owner is always included unless they explicitly declined
  Set<String> _getEventParticipants(CalendarEvent event) {
    final participants = <String>{};
    
    // Add event owner if exists (always include owner unless they explicitly declined)
    // Use eventOwnerId if available, otherwise fall back to createdBy for backward compatibility
    final ownerId = event.eventOwnerId ?? event.createdBy;
    if (ownerId != null) {
      final ownerRsvp = event.rsvpStatus[ownerId];
      if (ownerRsvp != 'declined') {
        participants.add(ownerId);
      }
    }
    
    // Add invited members who RSVP'd "going" or have no RSVP (default to going)
    for (final memberId in event.invitedMemberIds) {
      final rsvp = event.rsvpStatus[memberId];
      if (rsvp == 'going' || rsvp == null) {
        // If no RSVP, assume going (default)
        participants.add(memberId);
      }
    }
    
    return participants;
  }

  /// Check if two events overlap in time
  bool _eventsOverlap(CalendarEvent event1, CalendarEvent event2) {
    return event1.startTime.isBefore(event2.endTime) &&
           event2.startTime.isBefore(event1.endTime);
  }

  /// Find conflicts: people who are in multiple overlapping events
  Map<String, List<CalendarEvent>> _findConflicts() {
    final conflicts = <String, List<CalendarEvent>>{};
    
    for (int i = 0; i < _events.length; i++) {
      for (int j = i + 1; j < _events.length; j++) {
        final event1 = _events[i];
        final event2 = _events[j];
        
        if (_eventsOverlap(event1, event2)) {
          final participants1 = _getEventParticipants(event1);
          final participants2 = _getEventParticipants(event2);
          
          // Find common participants
          final common = participants1.intersection(participants2);
          
          for (final memberId in common) {
            if (!conflicts.containsKey(memberId)) {
              conflicts[memberId] = [];
            }
            if (!conflicts[memberId]!.contains(event1)) {
              conflicts[memberId]!.add(event1);
            }
            if (!conflicts[memberId]!.contains(event2)) {
              conflicts[memberId]!.add(event2);
            }
          }
        }
      }
    }
    
    return conflicts;
  }

  /// Parse hex color string to Color
  Color _parseColor(String colorString) {
    try {
      // Handle hex strings like '#2196F3' or '2196F3'
      String hex = colorString.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
      return Colors.blue;
    } catch (e) {
      return Colors.blue;
    }
  }

  /// Convert time to X position in the chart
  /// Clips times outside the visible range to the edges
  double _timeToX(DateTime time) {
    final hour = time.hour + (time.minute / 60.0);
    if (hour < _startHour) return 0;
    if (hour > _endHour) return (_endHour - _startHour) * _hourWidth;
    return (hour - _startHour) * _hourWidth;
  }

  /// Get event width in pixels
  /// Handles events that start before or end after the visible time range
  double _getEventWidth(CalendarEvent event) {
    // Normalize times to the selected date for proper calculation
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    // Clamp start time to the visible range
    DateTime startTime = event.startTime;
    if (startTime.isBefore(selectedDate.add(Duration(hours: _startHour)))) {
      startTime = selectedDate.add(Duration(hours: _startHour));
    }
    
    // Clamp end time to the visible range
    DateTime endTime = event.endTime;
    if (endTime.isAfter(selectedDate.add(Duration(hours: _endHour)))) {
      endTime = selectedDate.add(Duration(hours: _endHour));
    }
    
    // If event is completely outside the visible range, show a minimal bar
    if (event.endTime.isBefore(selectedDate.add(Duration(hours: _startHour))) ||
        event.startTime.isAfter(selectedDate.add(Duration(hours: _endHour)))) {
      return 20.0;
    }
    
    final startX = _timeToX(startTime);
    final endX = _timeToX(endTime);
    final width = endX - startX;
    
    return width.clamp(20.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _findConflicts();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Day View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conflicts.isNotEmpty)
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _showConflictsDialog(conflicts),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning, size: 16, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${conflicts.length} conflict${conflicts.length > 1 ? 's' : ''}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Family members legend/key
                if (_familyMembers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Family Members',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: _familyMembers.map((member) {
                            final color = _memberColors[member.uid] ?? Colors.grey;
                            final hasEvents = _events.any((event) {
                              final participants = _getEventParticipants(event);
                              return participants.contains(member.uid);
                            });
                            
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      member.displayName
                                          .split(' ')
                                          .where((n) => n.isNotEmpty)
                                          .map((n) => n[0])
                                          .take(2)
                                          .join(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  member.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasEvents
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Colors.grey.shade600,
                                    fontWeight: hasEvents ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                
                // Conflicts warning
                // Conflicts warning - optimized for light/dark mode contrast
                if (conflicts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.orange.shade900.withOpacity(0.3)
                          : Colors.orange.shade50,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade700
                            : Colors.orange.shade300,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Scheduling Conflicts Detected:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange.shade200
                                : Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...conflicts.entries.map((entry) {
                          final memberName = _memberNames[entry.key] ?? 'Unknown';
                          final eventTitles = entry.value.map((e) => e.title).join(', ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $memberName: $eventTitles',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.orange.shade100
                                    : Colors.orange.shade800,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                
                // Gantt chart
                Expanded(
                  child: _events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No events for this day',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fixed left column (Time/Event labels)
                            _buildFixedLeftColumn(conflicts),
                            
                            // Scrollable Gantt chart area
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Time header with visible indicators
                                        _buildTimeHeader(),
                                        
                                        // Events
                                        ..._events.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final event = entry.value;
                                          final eventParticipants = _getEventParticipants(event);
                                          final hasConflict = eventParticipants.any(
                                            (memberId) => conflicts.containsKey(memberId) &&
                                                conflicts[memberId]!.contains(event),
                                          );
                                          
                                          return _buildEventRow(event, index, eventParticipants, hasConflict);
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFixedLeftColumn(Map<String, List<CalendarEvent>> conflicts) {
    return Container(
      width: _eventLabelWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time header - match height with scrollable header
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: const Center(
              child: Text(
                'Time',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Event rows
          ..._events.asMap().entries.map((entry) {
            final event = entry.value;
            final startTimeStr = DateFormat('h:mm a').format(event.startTime);
            final endTimeStr = DateFormat('h:mm a').format(event.endTime);
            
            return Container(
              height: _rowHeight,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startTimeStr - $endTimeStr',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeHeader() {
    final totalWidth = (_endHour - _startHour) * _hourWidth;
    return Container(
      height: 50,
      width: totalWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hour markers with visible labels
          ...List.generate(
            _endHour - _startHour + 1,
            (index) {
              final hour = _startHour + index;
              final x = index * _hourWidth;
              final displayHour = hour % 12 == 0 ? 12 : hour % 12;
              final period = hour < 12 ? 'AM' : 'PM';
              
              return Positioned(
                left: x - 15, // Center the label on the line
                child: SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hour label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayHour',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              period,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Vertical line
                      Container(
                        width: 1,
                        height: 8,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Half-hour markers (lighter, shorter)
          ...List.generate(
            _endHour - _startHour,
            (index) {
              final x = (index + 0.5) * _hourWidth;
              return Positioned(
                left: x,
                top: 42,
                child: Container(
                  width: 0.5,
                  height: 8,
                  color: Colors.grey.shade200,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventRow(
    CalendarEvent event,
    int index,
    Set<String> participants,
    bool hasConflict,
  ) {
    final startX = _timeToX(event.startTime);
    final width = _getEventWidth(event);
    
    final totalWidth = (_endHour - _startHour) * _hourWidth;
    return Container(
      height: _rowHeight,
      width: totalWidth,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Stack(
        children: [
          // Time markers (hour and half-hour lines)
          ...List.generate(
            _endHour - _startHour + 1,
            (index) {
              final x = index * _hourWidth;
              return Positioned(
                left: x,
                child: Container(
                  width: 1,
                  height: _rowHeight,
                  color: Colors.grey.shade300,
                ),
              );
            },
          ),
          // Half-hour markers
          ...List.generate(
            _endHour - _startHour,
            (index) {
              final x = (index + 0.5) * _hourWidth;
              return Positioned(
                left: x,
                child: Container(
                  width: 0.5,
                  height: _rowHeight,
                  color: Colors.grey.shade200,
                ),
              );
            },
          ),
          // Event bar
          Positioned(
            left: startX,
            top: 8,
            child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailsScreen(event: event),
                        ),
                      );
                    },
                    child: Container(
                      width: width,
                      height: _rowHeight - 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: hasConflict
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: participants.isNotEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final availableHeight = constraints.maxHeight;
                                final participantCount = participants.length;
                                final chipHeight = (availableHeight / participantCount).clamp(14.0, double.infinity);
                                
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: participants.toList().asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final memberId = entry.value;
                                    final name = _memberNames[memberId] ?? 'Unknown';
                                    final color = _memberColors[memberId] ?? Colors.grey;
                                    
                                    return SizedBox(
                                      height: chipHeight,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.85),
                                          border: index < participants.length - 1
                                              ? Border(
                                                  bottom: BorderSide(
                                                    color: Colors.white.withOpacity(0.4),
                                                    width: 1,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Center(
                                            child: Text(
                                              name.split(' ').first, // Show first name
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: chipHeight > 20 ? 11 : (chipHeight > 16 ? 9 : 8),
                                                fontWeight: FontWeight.bold,
                                                height: 1.0,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: hasConflict
                                    ? Colors.red.shade300
                                    : _parseColor(event.color).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _showConflictsDialog(Map<String, List<CalendarEvent>> conflicts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduling Conflicts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following family members have overlapping events:',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              ...conflicts.entries.map((entry) {
                final memberName = _memberNames[entry.key] ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...entry.value.map((event) {
                        final startTime = DateFormat('h:mm a').format(event.startTime);
                        final endTime = DateFormat('h:mm a').format(event.endTime);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _parseColor(event.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${event.title} ($startTime - $endTime)',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

